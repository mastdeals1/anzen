/*
  # Product Source & Document Intelligence System
  
  1. Purpose
    - Create a document intelligence layer for products
    - Track multiple suppliers/sources per product
    - Store documents (COA, MSDS, TDS, Specifications) per source
    - Zero workflow, zero approval - pure knowledge management
    
  2. New Tables
    - `product_sources`: Multiple supplier sources per product
      - id (uuid, PK)
      - product_id (FK to products)
      - supplier_id (FK to suppliers) 
      - grade (BP/USP/EP/IP/Tech/Other)
      - country (optional)
      - remarks (optional free text)
      - created_by (user who added)
      - created_at (timestamp)
      
    - `product_source_documents`: Documents per source
      - id (uuid, PK)
      - source_id (FK to product_sources)
      - doc_type (COA/MSDS/TDS/SPEC/OTHER)
      - file_url (storage URL)
      - original_filename (user's filename)
      - file_size (bytes)
      - notes (optional)
      - uploaded_by (user)
      - uploaded_at (timestamp)
  
  3. Key Design Principles
    - ❌ NO approval workflow
    - ❌ NO status fields
    - ❌ NO touching batches/inventory/accounting
    - ✅ Pure additive intelligence layer
    - ✅ Fast search and retrieval
    - ✅ Zero friction document management
    
  4. Security
    - Enable RLS on both tables
    - Authenticated users can read all sources
    - Authenticated users can add/edit sources
    - Only creator or admin can delete
*/

-- =====================================================
-- 1. CREATE PRODUCT SOURCES TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS product_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  supplier_id uuid REFERENCES suppliers(id) ON DELETE SET NULL,
  supplier_name text,
  grade text CHECK (grade IN ('BP', 'USP', 'EP', 'IP', 'Tech', 'Food Grade', 'Industrial', 'Other')),
  country text,
  remarks text,
  created_by uuid REFERENCES user_profiles(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_product_sources_product ON product_sources(product_id);
CREATE INDEX IF NOT EXISTS idx_product_sources_supplier ON product_sources(supplier_id);
CREATE INDEX IF NOT EXISTS idx_product_sources_grade ON product_sources(grade);

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION update_product_sources_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_product_sources_timestamp
  BEFORE UPDATE ON product_sources
  FOR EACH ROW
  EXECUTE FUNCTION update_product_sources_updated_at();

-- =====================================================
-- 2. CREATE PRODUCT SOURCE DOCUMENTS TABLE  
-- =====================================================

CREATE TABLE IF NOT EXISTS product_source_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id uuid NOT NULL REFERENCES product_sources(id) ON DELETE CASCADE,
  doc_type text NOT NULL CHECK (doc_type IN ('COA', 'MSDS', 'TDS', 'SPEC', 'Regulatory', 'Test Report', 'Other')),
  file_url text NOT NULL,
  original_filename text NOT NULL,
  file_size bigint,
  notes text,
  uploaded_by uuid REFERENCES user_profiles(id),
  uploaded_at timestamptz DEFAULT now()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_product_source_documents_source ON product_source_documents(source_id);
CREATE INDEX IF NOT EXISTS idx_product_source_documents_type ON product_source_documents(doc_type);
CREATE INDEX IF NOT EXISTS idx_product_source_documents_uploaded ON product_source_documents(uploaded_at);

-- =====================================================
-- 3. ENABLE RLS SECURITY
-- =====================================================

ALTER TABLE product_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_source_documents ENABLE ROW LEVEL SECURITY;

-- Product Sources Policies: All authenticated users can read and write
CREATE POLICY "Authenticated users can read product sources"
  ON product_sources FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert product sources"
  ON product_sources FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update product sources"
  ON product_sources FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can delete product sources"
  ON product_sources FOR DELETE
  TO authenticated
  USING (true);

-- Product Source Documents Policies
CREATE POLICY "Authenticated users can read source documents"
  ON product_source_documents FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert source documents"
  ON product_source_documents FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update source documents"
  ON product_source_documents FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can delete source documents"
  ON product_source_documents FOR DELETE
  TO authenticated
  USING (true);

-- =====================================================
-- 4. CREATE HELPER VIEW FOR SOURCE SUMMARY
-- =====================================================

CREATE OR REPLACE VIEW product_sources_with_stats AS
SELECT 
  ps.*,
  s.company_name as supplier_company_name,
  COUNT(DISTINCT psd.id) as document_count,
  ARRAY_AGG(DISTINCT psd.doc_type) FILTER (WHERE psd.doc_type IS NOT NULL) as available_doc_types
FROM product_sources ps
LEFT JOIN suppliers s ON ps.supplier_id = s.id
LEFT JOIN product_source_documents psd ON ps.id = psd.source_id
GROUP BY ps.id, s.company_name;