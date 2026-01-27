/*
  # Add Appointment Participant Notifications

  1. Purpose
    - Automatically notify users when they are tagged as participants in appointments
    - Send notifications when appointments are created or updated with participants

  2. Changes
    - Create function to notify appointment participants
    - Create trigger to execute notification function on insert/update

  3. Notification Details
    - Notifies all participants when they're added to an appointment
    - Includes meeting subject, date/time, and organizer information
*/

-- Function to notify participants when they're added to an appointment
CREATE OR REPLACE FUNCTION notify_appointment_participants()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  participant_id uuid;
  organizer_name text;
  meeting_time text;
BEGIN
  -- Get organizer name
  SELECT full_name INTO organizer_name
  FROM user_profiles
  WHERE id = NEW.created_by;

  -- Format meeting time
  meeting_time := to_char(NEW.follow_up_date, 'FMDay, FMDD FMMonth YYYY at HH24:MI');

  -- Only process if participants array has items
  IF NEW.participants IS NOT NULL AND array_length(NEW.participants, 1) > 0 THEN
    -- Loop through all participants
    FOREACH participant_id IN ARRAY NEW.participants
    LOOP
      -- Don't notify the organizer
      IF participant_id != NEW.created_by THEN
        -- Create notification for each participant
        INSERT INTO notifications (
          user_id,
          type,
          title,
          message,
          reference_id,
          reference_type,
          is_read
        ) VALUES (
          participant_id,
          'appointment',
          'New Meeting: ' || NEW.subject,
          organizer_name || ' has invited you to a ' || 
          CASE 
            WHEN NEW.activity_type = 'meeting' THEN 'meeting'
            WHEN NEW.activity_type = 'video_call' THEN 'video call'
            WHEN NEW.activity_type = 'phone_call' THEN 'phone call'
            ELSE 'appointment'
          END ||
          ' on ' || meeting_time,
          NEW.id,
          'appointment',
          false
        );
      END IF;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger for new appointments
DROP TRIGGER IF EXISTS notify_appointment_participants_on_insert ON crm_activities;
CREATE TRIGGER notify_appointment_participants_on_insert
  AFTER INSERT ON crm_activities
  FOR EACH ROW
  WHEN (NEW.participants IS NOT NULL AND array_length(NEW.participants, 1) > 0)
  EXECUTE FUNCTION notify_appointment_participants();

-- Create trigger for updated appointments
DROP TRIGGER IF EXISTS notify_appointment_participants_on_update ON crm_activities;
CREATE TRIGGER notify_appointment_participants_on_update
  AFTER UPDATE ON crm_activities
  FOR EACH ROW
  WHEN (
    NEW.participants IS NOT NULL AND 
    array_length(NEW.participants, 1) > 0 AND
    (OLD.participants IS NULL OR OLD.participants != NEW.participants)
  )
  EXECUTE FUNCTION notify_appointment_participants();
