/*
  # Unify CRM Appointments with CRM Contacts - Fixed Order

  ## Problem
  1. CRM Appointments (crm_activities) use customers table (sales module)
  2. CRM Customers tab uses crm_contacts table (CRM module)
  3. This creates confusion - appointments show different customers than CRM
  4. Some customers exist in both tables with different IDs

  ## Solution
  1. Drop old FK constraint first
  2. Copy missing customer to crm_contacts
  3. Update appointment references to use crm_contacts IDs
  4. Add new FK constraint to crm_contacts

  ## Changes
  - Drop FK constraint first (allows updates)
  - Insert missing customer into crm_contacts
  - Update crm_activities to reference crm_contacts IDs
  - Add new FK to crm_contacts
*/

-- Step 1: Drop old FK constraint FIRST
ALTER TABLE crm_activities 
  DROP CONSTRAINT IF EXISTS crm_activities_customer_id_fkey;

-- Step 2: Insert missing customer (PT. Anugrah Visi Bersama) into crm_contacts
INSERT INTO crm_contacts (
  id,
  company_name,
  address,
  city,
  country,
  contact_person,
  email,
  phone,
  company_type,
  customer_type,
  is_active,
  created_by,
  created_at
)
SELECT 
  c.id,
  c.company_name,
  c.address,
  c.city,
  c.country,
  c.contact_person,
  c.email,
  c.phone,
  'trader',
  'active',
  c.is_active,
  c.created_by,
  c.created_at
FROM customers c
WHERE c.id = '07129eb5-9381-43b9-9417-5e224cd04684'
  AND NOT EXISTS (SELECT 1 FROM crm_contacts WHERE id = c.id);

-- Step 3: Update appointment references to use crm_contacts IDs
-- PT Prima Cita Persada: 47410ca0 -> c3ccdcf5
UPDATE crm_activities 
SET customer_id = 'c3ccdcf5-57c2-48a6-a9b6-bfaeda3e9938'
WHERE customer_id = '47410ca0-44b7-423a-8d85-09bdc3aa2c78';

-- PT Genero: 2ef0910d -> 2dbff7c7
UPDATE crm_activities 
SET customer_id = '2dbff7c7-0d02-4386-ab7f-5615894a8363'
WHERE customer_id = '2ef0910d-f6da-49a5-a5c9-d2ebe00a45b1';

-- PT. Anugrah Visi Bersama keeps same ID (07129eb5) - already added to crm_contacts above

-- Step 4: Add new FK constraint pointing to crm_contacts
ALTER TABLE crm_activities
  ADD CONSTRAINT crm_activities_customer_id_fkey 
  FOREIGN KEY (customer_id) 
  REFERENCES crm_contacts(id) 
  ON DELETE SET NULL;

COMMENT ON CONSTRAINT crm_activities_customer_id_fkey ON crm_activities IS
'Links appointments to CRM contacts (not sales customers). Allows tracking appointments within CRM module.';