-- Migration V4: Add DELETE policy for items

-- Allow deleting items
create policy "Allow public delete items" on public.items for delete using (true);
