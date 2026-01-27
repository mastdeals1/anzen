/*
  # Add Appointment Notifications - Simple Fix
  
  1. Trigger Function
    - When appointment (crm_activity with meeting/video_call/phone_call) is created/updated
    - Send notification to ALL participants
    - Simple and straightforward
    
  2. Notification Details
    - Type: appointment
    - Title: New/Updated Appointment
    - Message: Contains subject, date/time, and type
*/

-- Function to notify participants about appointments
CREATE OR REPLACE FUNCTION notify_appointment_participants()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  participant_id uuid;
  appointment_time text;
  notification_title text;
  notification_message text;
BEGIN
  -- Only process meeting-related activities
  IF NEW.activity_type NOT IN ('meeting', 'video_call', 'phone_call') THEN
    RETURN NEW;
  END IF;
  
  -- Only process if there's a follow_up_date (appointment date)
  IF NEW.follow_up_date IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- Format appointment time
  appointment_time := to_char(NEW.follow_up_date, 'Mon DD, YYYY at HH24:MI');
  
  -- Set notification title based on operation
  IF TG_OP = 'INSERT' THEN
    notification_title := 'New Appointment';
  ELSE
    notification_title := 'Appointment Updated';
  END IF;
  
  -- Build notification message
  notification_message := NEW.subject || ' - ' || appointment_time;
  
  -- Send notification to each participant
  IF NEW.participants IS NOT NULL AND array_length(NEW.participants, 1) > 0 THEN
    FOREACH participant_id IN ARRAY NEW.participants
    LOOP
      INSERT INTO notifications (
        user_id,
        type,
        title,
        message,
        reference_id,
        reference_type,
        is_read,
        created_at
      ) VALUES (
        participant_id,
        'appointment',
        notification_title,
        notification_message,
        NEW.id,
        'crm_activity',
        false,
        now()
      )
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_notify_appointment_participants ON crm_activities;
CREATE TRIGGER trigger_notify_appointment_participants
  AFTER INSERT OR UPDATE ON crm_activities
  FOR EACH ROW
  EXECUTE FUNCTION notify_appointment_participants();

-- Create notifications for EXISTING appointments (one-time backfill)
DO $$
DECLARE
  activity_rec RECORD;
  participant_id uuid;
BEGIN
  FOR activity_rec IN 
    SELECT id, subject, follow_up_date, participants, created_by
    FROM crm_activities
    WHERE activity_type IN ('meeting', 'video_call', 'phone_call')
      AND follow_up_date IS NOT NULL
      AND follow_up_date > now()
      AND participants IS NOT NULL
      AND array_length(participants, 1) > 0
  LOOP
    FOREACH participant_id IN ARRAY activity_rec.participants
    LOOP
      INSERT INTO notifications (
        user_id,
        type,
        title,
        message,
        reference_id,
        reference_type,
        is_read,
        created_at
      ) VALUES (
        participant_id,
        'appointment',
        'Scheduled Appointment',
        activity_rec.subject || ' - ' || to_char(activity_rec.follow_up_date, 'Mon DD, YYYY at HH24:MI'),
        activity_rec.id,
        'crm_activity',
        false,
        now()
      )
      ON CONFLICT DO NOTHING;
    END LOOP;
  END LOOP;
END $$;
