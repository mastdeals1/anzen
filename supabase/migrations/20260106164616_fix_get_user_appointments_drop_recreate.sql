/*
  # Fix Get User Appointments - Drop and Recreate
  
  Drop and recreate with correct timestamp type
*/

DROP FUNCTION IF EXISTS get_user_appointments(uuid, timestamptz, timestamptz);

CREATE OR REPLACE FUNCTION get_user_appointments(
  p_user_id uuid,
  p_start_date timestamptz DEFAULT NULL,
  p_end_date timestamptz DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  activity_type text,
  subject text,
  description text,
  follow_up_date timestamp,
  is_completed boolean,
  participants uuid[],
  customer_id uuid,
  created_by uuid,
  customers jsonb,
  user_profiles jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ca.id,
    ca.activity_type,
    ca.subject,
    ca.description,
    ca.follow_up_date,
    ca.is_completed,
    ca.participants,
    ca.customer_id,
    ca.created_by,
    CASE 
      WHEN c.id IS NOT NULL THEN 
        jsonb_build_object('company_name', c.company_name)
      ELSE NULL 
    END as customers,
    CASE 
      WHEN up.id IS NOT NULL THEN 
        jsonb_build_object('full_name', up.full_name)
      ELSE NULL 
    END as user_profiles
  FROM crm_activities ca
  LEFT JOIN customers c ON c.id = ca.customer_id
  LEFT JOIN user_profiles up ON up.id = ca.created_by
  WHERE ca.activity_type IN ('meeting', 'video_call', 'phone_call')
    AND ca.follow_up_date IS NOT NULL
    AND (
      ca.created_by = p_user_id 
      OR p_user_id = ANY(ca.participants)
    )
    AND (p_start_date IS NULL OR ca.follow_up_date >= p_start_date::timestamp)
    AND (p_end_date IS NULL OR ca.follow_up_date <= p_end_date::timestamp)
  ORDER BY ca.follow_up_date ASC;
END;
$$;
