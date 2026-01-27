/*
  # Fix Appointment Activity Types and Constraints

  1. Problem
    - crm_activities CHECK constraint only allows: call, email, meeting, note, follow_up
    - AppointmentScheduler tries to use: meeting, video_call, phone_call
    - This causes 409 Conflict errors when creating appointments

  2. Solution
    - Update CHECK constraint to include video_call and phone_call types
    - These types are used by the appointment scheduling system

  3. Changes
    - Modify activity_type constraint to add video_call and phone_call
*/

-- Drop the old constraint
ALTER TABLE crm_activities DROP CONSTRAINT IF EXISTS crm_activities_activity_type_check;

-- Add new constraint with video_call and phone_call included
ALTER TABLE crm_activities ADD CONSTRAINT crm_activities_activity_type_check 
  CHECK (activity_type IN ('call', 'email', 'meeting', 'note', 'follow_up', 'video_call', 'phone_call'));
