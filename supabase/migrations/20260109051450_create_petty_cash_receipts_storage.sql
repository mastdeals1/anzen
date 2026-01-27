/*
  # Create Petty Cash Receipts Storage Bucket

  1. Problem
    - petty-cash-receipts bucket doesn't exist
    - Uploads fail silently when users try to attach documents
    
  2. Solution
    - Create petty-cash-receipts storage bucket
    - Set it to public for easy access
    - Add RLS policies for authenticated users

  3. Changes
    - Create storage bucket
    - Add upload policy for authenticated users
    - Add read policy for authenticated users
    - Add delete policy for authenticated users
*/

-- Create the petty-cash-receipts storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'petty-cash-receipts',
  'petty-cash-receipts',
  true,
  10485760, -- 10MB limit
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']
)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload petty cash receipts
CREATE POLICY "Authenticated users can upload petty cash receipts"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'petty-cash-receipts');

-- Allow authenticated users to read petty cash receipts
CREATE POLICY "Authenticated users can read petty cash receipts"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (bucket_id = 'petty-cash-receipts');

-- Allow authenticated users to delete petty cash receipts
CREATE POLICY "Authenticated users can delete petty cash receipts"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (bucket_id = 'petty-cash-receipts');
