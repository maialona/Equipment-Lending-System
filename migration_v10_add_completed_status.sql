-- Migration V10: Add COMPLETED status to orders table
-- Drop old constraint
ALTER TABLE public.orders DROP CONSTRAINT orders_status_check;

-- Add new constraint including COMPLETED
ALTER TABLE public.orders ADD CONSTRAINT orders_status_check 
CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'RETURNED', 'CANCELLED', 'COMPLETED'));
