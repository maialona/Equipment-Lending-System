-- Migration V8: Add custom_id column to items table
ALTER TABLE public.items ADD COLUMN custom_id text;
