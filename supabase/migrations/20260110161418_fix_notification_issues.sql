/*
  # Fix Notification Issues
  
  1. Remove Duplicate Triggers
    - Drop old duplicate appointment notification triggers
    - Keep only the latest one
    - This fixes duplicate notifications
    
  2. Clean Up Duplicate Notifications
    - Remove all duplicate notifications
    - Keep only one per user per appointment
*/

-- Drop all old duplicate triggers
DROP TRIGGER IF EXISTS notify_appointment_participants_on_insert ON crm_activities;
DROP TRIGGER IF EXISTS notify_appointment_participants_on_update ON crm_activities;

-- Keep only the main trigger (trigger_notify_appointment_participants)
-- This trigger already exists from migration 20260106163452

-- Clean up ALL duplicate notifications more aggressively
WITH duplicates AS (
  SELECT 
    id,
    ROW_NUMBER() OVER (
      PARTITION BY user_id, reference_id, type 
      ORDER BY created_at ASC
    ) as rn
  FROM notifications
  WHERE reference_type = 'crm_activity'
    AND type = 'appointment'
)
DELETE FROM notifications
WHERE id IN (
  SELECT id FROM duplicates WHERE rn > 1
);

-- Add unique constraint to prevent future duplicates
CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_unique_appointment 
ON notifications(user_id, reference_id, type)
WHERE reference_type = 'crm_activity' AND type = 'appointment';
