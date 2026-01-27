-- Import 2025 Expenses from CSV
-- All expenses are from June to September 2025

-- June 2025 Expenses
INSERT INTO finance_expenses (expense_date, amount, expense_category, expense_type, description, payment_method) VALUES
('2025-06-03', 168000, 'other', 'operations', 'courier charges (PAID)', 'bank_transfer'),
('2025-06-15', 369300, 'utilities', 'operations', 'Internet bill (B)  (PAID)', 'bank_transfer'),
('2025-06-15', 552355, 'utilities', 'operations', 'Telfon bill (B) (PAID)', 'bank_transfer'),
('2025-06-15', 8000000, 'office_admin', 'admin', 'Rent office n gudang  15 June  to 15 July (PAID)', 'cash'),
('2025-06-20', 800000, 'travel_conveyance', 'operations', 'Trip to bandung Nico & Zainal (PAID)', 'cash'),
('2025-06-25', 2000000, 'other', 'operations', 'CDOB charges to nia (PAID)', 'cash'),
('2025-06-26', 84000, 'travel_conveyance', 'operations', 'Grab to BPOM & Back Office Nia (PAID)', 'cash'),
('2025-06-26', 175000, 'other', 'operations', 'inspection to Anugerah Misi - Nico (PAID)', 'cash'),
('2025-06-29', 823500, 'utilities', 'operations', 'Electricty, Water and Security (PAID)', 'cash'),
('2025-06-30', 10000000, 'travel_conveyance', 'operations', 'expenses Trip Tarun Surabaya & Semarang (PAID)', 'cash'),
('2025-06-30', 8000000, 'salary', 'staff', 'salary Nia June 25 (PAID)', 'bank_transfer'),
('2025-06-30', 3800000, 'salary', 'staff', 'salary chintia June 25 (PAID)', 'bank_transfer'),
('2025-06-30', 3000000, 'salary', 'staff', 'salary Nico june 25 (PAID)', 'bank_transfer'),
('2025-06-30', 3500000, 'salary', 'staff', 'salary Didi Driver June 25 (PAID)', 'cash'),
('2025-06-30', 7000000, 'salary', 'staff', 'salary Tarun June 25 (PAID)', 'cash'),
('2025-06-30', 1000000, 'office_admin', 'admin', 'tax consultant June 25 (PAID)', 'bank_transfer'),
('2025-06-30', 2350000, 'salary', 'staff', 'Salary Zainal june 25 (PAID)', 'bank_transfer');

-- July 2025 Expenses
INSERT INTO finance_expenses (expense_date, amount, expense_category, expense_type, description, payment_method) VALUES
('2025-07-15', 369300, 'utilities', 'operations', 'Internet bill (B)  (PAID)', 'bank_transfer'),
('2025-07-16', 375102, 'utilities', 'operations', 'Telfon bill (B) (PAID)', 'bank_transfer'),
('2025-07-15', 8000000, 'office_admin', 'admin', 'Rent office n gudang  15 Jul  to 15 Aug (PAID)', 'cash'),
('2025-07-20', 823500, 'utilities', 'operations', 'Electricty, Water and Security (PAID)', 'cash'),
('2025-07-31', 8000000, 'salary', 'staff', 'salary Nia July 25 (PAID)', 'bank_transfer'),
('2025-07-31', 3800000, 'salary', 'staff', 'salary chintia July 25 (PAID)', 'bank_transfer'),
('2025-07-31', 2800000, 'salary', 'staff', 'salary Nico july 25 (PAID)', 'bank_transfer'),
('2025-07-31', 3500000, 'salary', 'staff', 'salary Didi Driver July 25 (PAID)', 'cash'),
('2025-07-31', 5850000, 'salary', 'staff', 'salary Tarun July 25 (PAID)', 'cash'),
('2025-07-31', 1000000, 'office_admin', 'admin', 'tax consultant July 25 (PAID)', 'bank_transfer'),
('2025-07-31', 3500000, 'salary', 'staff', 'salary Zainal July 25 (PAID)', 'cash');

-- August 2025 Expenses
INSERT INTO finance_expenses (expense_date, amount, expense_category, expense_type, description, payment_method) VALUES
('2025-08-01', 75000, 'travel_conveyance', 'operations', 'grab to BPOM (PAID)', 'bank_transfer'),
('2025-08-15', 369300, 'utilities', 'operations', 'Internet bill (UNPAID)', 'bank_transfer'),
('2025-08-16', 177040, 'utilities', 'operations', 'Telfon bill (UNPAID)', 'bank_transfer'),
('2025-08-16', 8000000, 'office_admin', 'admin', 'Rent office n gudang  15 Jul  to 15 Aug (PAID)', 'cash'),
('2025-08-20', 812000, 'utilities', 'operations', 'Electricty, Water and Security (PAID)', 'cash'),
('2025-08-28', 355000, 'travel_conveyance', 'operations', 'transport charges BPOM (PAID)', 'bank_transfer'),
('2025-08-31', 8000000, 'salary', 'staff', 'salary Nia AUG 25 (PAID)', 'bank_transfer'),
('2025-08-31', 3800000, 'salary', 'staff', 'salary chintia AGU 25 (PAID)', 'bank_transfer'),
('2025-08-31', 3000000, 'salary', 'staff', 'salary Nico AGU 25 (PAID)', 'bank_transfer'),
('2025-08-31', 3500000, 'salary', 'staff', 'salary Didi Driver AGU 25 (PAID)', 'cash'),
('2025-08-31', 7000000, 'salary', 'staff', 'salary Tarun AUG 25 (PAID)', 'cash'),
('2025-08-31', 1000000, 'office_admin', 'admin', 'tax consultant AUG 25 (PAID)', 'bank_transfer');

-- September 2025 Expenses
INSERT INTO finance_expenses (expense_date, amount, expense_category, expense_type, description, payment_method) VALUES
('2025-09-05', 150000, 'travel_conveyance', 'operations', 'Driver paid daily based 1 days (PAID)', 'cash'),
('2025-09-08', 150000, 'travel_conveyance', 'operations', 'Driver paid daily based 1 days (PAID)', 'bank_transfer'),
('2025-09-10', 300000, 'travel_conveyance', 'operations', 'Driver paid daily based 2 days (PAID)', 'bank_transfer'),
('2025-09-11', 150000, 'travel_conveyance', 'operations', 'Driver paid daily based 1 days (PAID)', 'bank_transfer'),
('2025-09-12', 150000, 'travel_conveyance', 'operations', 'Driver paid daily based 1 days (PAID)', 'bank_transfer'),
('2025-09-15', 150000, 'travel_conveyance', 'operations', 'Driver paid daily based 1 days (PAID)', 'bank_transfer'),
('2025-09-15', 369300, 'utilities', 'operations', 'Internet bill (PAID)', 'bank_transfer'),
('2025-09-16', 170811, 'utilities', 'operations', 'Telfon bill (PAID)', 'bank_transfer'),
('2025-09-15', 8000000, 'office_admin', 'admin', 'Rent office n gudang  15 Jul  to 15 Sept (PAID)', 'cash'),
('2025-09-15', 776500, 'utilities', 'operations', 'Electricty, Water and Security (PAID)', 'cash'),
('2025-09-18', 900000, 'travel_conveyance', 'operations', 'Driver paid daily based 6 days (PAID)', 'cash'),
('2025-09-18', 204000, 'travel_conveyance', 'operations', 'transport charges for making docs (PAID)', 'bank_transfer'),
('2025-09-30', 8000000, 'salary', 'staff', 'salary Nia Sept 25 (PAID)', 'bank_transfer'),
('2025-09-30', 3800000, 'salary', 'staff', 'salary chintia Sept 25 (PAID)', 'bank_transfer'),
('2025-09-30', 3000000, 'salary', 'staff', 'salary Nico Sept 25 (PAID)', 'bank_transfer'),
('2025-09-30', 7000000, 'salary', 'staff', 'salary Tarun Sept 25 (PAID)', 'cash'),
('2025-09-30', 1000000, 'office_admin', 'admin', 'tax consultant Sept 25 (PAID)', 'bank_transfer'),
('2025-09-30', 3000000, 'salary', 'staff', 'Salary new Pahrmacist Sept 25 (PAID)', 'bank_transfer');

-- Summary:
-- Total expenses imported: 58
-- Date range: June 2025 - September 2025
-- Categories:
--   - salary (Staff salaries)
--   - utilities (Internet, telephone, electricity, water, security)
--   - office_admin (Rent, tax consultant)
--   - travel_conveyance (Transportation, trips, drivers, grab)
--   - other (Courier, CDOB, inspections)
