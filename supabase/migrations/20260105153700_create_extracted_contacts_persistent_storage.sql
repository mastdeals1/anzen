/*
  # Create Extracted Contacts Persistent Storage

  1. New Tables
    - `extracted_contacts`
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key to auth.users)
      - `company_name` (text)
      - `customer_name` (text)
      - `email_ids` (text) - semicolon-separated email addresses
      - `phone` (text)
      - `mobile` (text)
      - `website` (text)
      - `address` (text)
      - `source` (text) - 'Gmail', etc.
      - `confidence` (numeric) - AI confidence score
      - `extracted_at` (timestamptz) - when it was extracted
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on `extracted_contacts` table
    - Add policies for authenticated users to manage their own extracted contacts

  3. Indexes
    - Add index on user_id for fast lookups
    - Add index on email_ids for duplicate detection
*/

-- Create extracted_contacts table
CREATE TABLE IF NOT EXISTS extracted_contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  company_name text DEFAULT '',
  customer_name text DEFAULT '',
  email_ids text NOT NULL,
  phone text DEFAULT '',
  mobile text DEFAULT '',
  website text DEFAULT '',
  address text DEFAULT '',
  source text DEFAULT 'Gmail',
  confidence numeric(3,2) DEFAULT 0.5,
  extracted_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE extracted_contacts ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own extracted contacts"
  ON extracted_contacts
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own extracted contacts"
  ON extracted_contacts
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own extracted contacts"
  ON extracted_contacts
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_extracted_contacts_user_id ON extracted_contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_extracted_contacts_email_ids ON extracted_contacts USING gin(to_tsvector('simple', email_ids));
CREATE INDEX IF NOT EXISTS idx_extracted_contacts_created_at ON extracted_contacts(created_at DESC);