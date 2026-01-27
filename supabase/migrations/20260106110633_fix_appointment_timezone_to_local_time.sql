/*
  # Fix Appointment Timezone to Use Local Time

  1. Problem
    - Appointments are stored as timestamptz (timestamp WITH timezone)
    - When user enters 10:00 AM, it saves as UTC 10:00
    - When displayed, converts to local: 10:00 UTC = 17:00 Jakarta (UTC+7)
    - User sees 5:00 PM instead of 10:00 AM
    
  2. Solution
    - Change follow_up_date from timestamptz to timestamp (WITHOUT timezone)
    - Appointments will store literal time values (10:00 AM stays 10:00 AM)
    - No timezone conversion - what you see is what you get
    
  3. Notes
    - This is appropriate for appointments because they're in the user's local context
    - Other timestamps (created_at, updated_at) can remain timestamptz for audit trails
*/

-- Change follow_up_date from timestamptz to timestamp (without timezone)
ALTER TABLE crm_activities 
ALTER COLUMN follow_up_date TYPE timestamp WITHOUT TIME ZONE;

-- Update the index to still work
DROP INDEX IF EXISTS idx_crm_activities_follow_up;
CREATE INDEX idx_crm_activities_follow_up 
ON crm_activities(follow_up_date) 
WHERE is_completed = false;