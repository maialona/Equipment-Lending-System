-- Migration V6: Add time columns to orders table

alter table public.orders 
add column start_time text,
add column end_time text;
