-- Migration V9: Add type column to items table
ALTER TABLE public.items ADD COLUMN type text DEFAULT 'EQUIPMENT' CHECK (type IN ('EQUIPMENT', 'CONSUMABLE'));
