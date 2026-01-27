/*
  # Add Appointment Participants and Auto Follow-up

  1. Enhancements to crm_activities
    - Add `participants` array field to track tagged users in appointments
    - Add `auto_create_followup_task` boolean to auto-create follow-up tasks after meetings

  2. New Trigger
    - Auto-create notifications for all participants when appointment is created/updated
    - Auto-create follow-up task after meeting date passes (if enabled)

  3. Security
    - Participants can view appointments they're tagged in
    - Update RLS policies to allow participants to see appointments
*/

-- Add participants and auto follow-up field to crm_activities
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'crm_activities' AND column_name = 'participants'
  ) THEN
    ALTER TABLE crm_activities ADD COLUMN participants uuid[] DEFAULT '{}';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'crm_activities' AND column_name = 'auto_create_followup_task'
  ) THEN
    ALTER TABLE crm_activities ADD COLUMN auto_create_followup_task boolean DEFAULT false;
  END IF;
END $$;

-- Create index for participants for faster lookups
CREATE INDEX IF NOT EXISTS idx_crm_activities_participants ON crm_activities USING GIN(participants);

-- Function to notify participants when added to appointment
CREATE OR REPLACE FUNCTION notify_appointment_participants()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  participant_id uuid;
  customer_name text;
BEGIN
  -- Only process appointments (meeting, video_call, phone_call)
  IF NEW.activity_type NOT IN ('meeting', 'video_call', 'phone_call') THEN
    RETURN NEW;
  END IF;

  -- Get customer name for notification
  IF NEW.customer_id IS NOT NULL THEN
    SELECT company_name INTO customer_name FROM customers WHERE id = NEW.customer_id;
  ELSIF NEW.lead_id IS NOT NULL THEN
    SELECT company_name INTO customer_name FROM crm_leads WHERE id = NEW.lead_id;
  END IF;

  -- Create notifications for each participant (excluding creator)
  FOREACH participant_id IN ARRAY NEW.participants
  LOOP
    IF participant_id != NEW.created_by THEN
      INSERT INTO notifications (
        user_id,
        type,
        title,
        message,
        reference_type,
        reference_id,
        created_at
      ) VALUES (
        participant_id,
        'appointment_assigned',
        'New Appointment',
        'You have been added to: ' || NEW.subject ||
        CASE
          WHEN customer_name IS NOT NULL THEN ' with ' || customer_name
          ELSE ''
        END,
        'appointment',
        NEW.id,
        now()
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for participant notifications
DROP TRIGGER IF EXISTS trigger_notify_appointment_participants ON crm_activities;
CREATE TRIGGER trigger_notify_appointment_participants
  AFTER INSERT OR UPDATE OF participants
  ON crm_activities
  FOR EACH ROW
  EXECUTE FUNCTION notify_appointment_participants();

-- Function to auto-create follow-up tasks after meeting
CREATE OR REPLACE FUNCTION auto_create_appointment_followup()
RETURNS void
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  appointment record;
  customer_name text;
  task_title text;
  task_description text;
BEGIN
  -- Find completed/past appointments that need follow-up tasks
  FOR appointment IN
    SELECT a.*
    FROM crm_activities a
    WHERE a.activity_type IN ('meeting', 'video_call', 'phone_call')
      AND a.auto_create_followup_task = true
      AND a.follow_up_date < now()
      AND a.is_completed = true
      AND NOT EXISTS (
        SELECT 1 FROM tasks t
        WHERE t.title LIKE '%Follow up after meeting%'
          AND t.created_at > a.follow_up_date
          AND t.created_by = a.created_by
          AND (
            (a.customer_id IS NOT NULL AND t.customer_id = a.customer_id) OR
            (a.lead_id IS NOT NULL AND t.inquiry_id IN (
              SELECT id FROM crm_inquiries WHERE customer_id IN (
                SELECT id FROM crm_contacts WHERE id = a.lead_id
              )
            ))
          )
      )
  LOOP
    -- Get customer/lead name
    IF appointment.customer_id IS NOT NULL THEN
      SELECT company_name INTO customer_name FROM customers WHERE id = appointment.customer_id;
    ELSIF appointment.lead_id IS NOT NULL THEN
      SELECT company_name INTO customer_name FROM crm_leads WHERE id = appointment.lead_id;
    END IF;

    -- Build task title and description
    task_title := 'Follow up after meeting: ' || COALESCE(customer_name, 'Customer');
    task_description := 'Follow up on meeting: ' || appointment.subject || E'\n' ||
                       'Meeting date: ' || to_char(appointment.follow_up_date, 'YYYY-MM-DD HH24:MI');

    -- Create follow-up task
    INSERT INTO tasks (
      title,
      description,
      deadline,
      priority,
      status,
      created_by,
      assigned_users,
      customer_id,
      tags,
      created_at
    ) VALUES (
      task_title,
      task_description,
      appointment.follow_up_date + interval '2 days', -- Due 2 days after meeting
      'medium',
      'to_do',
      appointment.created_by,
      ARRAY[appointment.created_by], -- Assign to meeting owner
      appointment.customer_id,
      ARRAY['follow-up', 'meeting'],
      now()
    );

    -- Mark appointment as processed (we'll add a flag later if needed)
    -- For now, the EXISTS check prevents duplicates
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Update RLS policy to allow participants to view appointments
DROP POLICY IF EXISTS "Users can view appointments they're involved in" ON crm_activities;
CREATE POLICY "Users can view appointments they're involved in"
  ON crm_activities
  FOR SELECT
  TO authenticated
  USING (
    created_by = (SELECT auth.uid()) OR
    (SELECT auth.uid()) = ANY(participants)
  );

-- Note: To run the auto follow-up function, you can:
-- 1. Set up a cron job (requires pg_cron extension)
-- 2. Call it manually: SELECT auto_create_appointment_followup();
-- 3. Add it to your application logic to run periodically

-- Create a comment to document this
COMMENT ON FUNCTION auto_create_appointment_followup IS
  'Auto-creates follow-up tasks for completed meetings. Run periodically (e.g., daily via cron or app scheduler).';
