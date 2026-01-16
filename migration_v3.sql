-- Migration V3: Add DELETE policies for orders and order_items

-- Allow deleting orders
create policy "Allow public delete orders" on public.orders for delete using (true);

-- Allow deleting order_items (needed if RLS checks cascade deletions, though usually handled by parent delete permission + cascade, being explicit is safer for this MVP setup)
create policy "Allow public delete order_items" on public.order_items for delete using (true);
