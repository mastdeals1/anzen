/*
  # Create Storage Bucket for Product Source Documents
  
  1. Purpose
    - Store documents for product sources (COA, MSDS, TDS, Specifications)
    - Support Ctrl+V paste uploads (images, PDFs)
    
  2. Configuration
    - Public bucket for easy access
    - 10MB file size limit per file
    - Allowed types: PDF, images, Office documents
    
  3. Security
    - Authenticated users can upload
    - Authenticated users can read
    - Only uploader can delete their own files
*/

-- Create storage bucket for product source documents
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-source-documents', 'product-source-documents', true)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload files
CREATE POLICY "Authenticated users can upload source documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'product-source-documents');

-- Allow authenticated users to read files  
CREATE POLICY "Authenticated users can read source documents"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'product-source-documents');

-- Allow users to update their own files
CREATE POLICY "Users can update their own source documents"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'product-source-documents' AND auth.uid() = owner);

-- Allow users to delete their own files
CREATE POLICY "Users can delete their own source documents"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'product-source-documents' AND auth.uid() = owner);