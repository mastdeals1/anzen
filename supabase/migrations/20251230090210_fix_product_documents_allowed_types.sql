/*
  # Fix Product Documents Allowed Types

  1. Changes
    - Expand allowed document_type values to match the UI
    - Allow: coa, msds, tds, specification, regulatory, test_certificate,
      stability_study, gmp_certificate, dmf, other

  2. Notes
    - This fixes the issue where document uploads were failing silently
    - The UI was trying to insert types not in the original constraint
*/

-- Drop the old constraint
ALTER TABLE product_documents 
DROP CONSTRAINT IF EXISTS product_documents_document_type_check;

-- Add new constraint with all types
ALTER TABLE product_documents
ADD CONSTRAINT product_documents_document_type_check 
CHECK (document_type IN (
  'coa',
  'msds', 
  'tds',
  'specification',
  'regulatory',
  'test_certificate',
  'stability_study',
  'gmp_certificate',
  'dmf',
  'other'
));