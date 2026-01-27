/*
  # Add BPOM/SKI Fees to Import Containers

  1. Changes
    - Add `bpom_ski_fees` column to `import_containers` table
    - This will track regulatory fees (BPOM/SKI) for pharmaceutical imports
    - Will be included in total import cost capitalization
  
  2. Notes
    - BPOM = Badan Pengawas Obat dan Makanan (Food and Drug Supervisory Agency)
    - SKI = Surat Keterangan Impor (Import Permit)
    - These are regulatory compliance fees that should be capitalized to inventory
*/

-- Add BPOM/SKI fees column to import containers
ALTER TABLE import_containers 
ADD COLUMN IF NOT EXISTS bpom_ski_fees numeric(15,2) DEFAULT 0;