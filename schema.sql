-- Equipment Lending System Schema

-- 1. Users Table (Custom Auth)
create table public.users (
  id uuid default gen_random_uuid() primary key,
  username text not null unique,
  password text not null, -- Stores plain text for MVP/Internal use as requested
  name text not null,
  role text not null check (role in ('ADMIN', 'USER')),
  department text,
  created_at timestamptz default now()
);

-- 2. Items Table (Inventory)
create table public.items (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  category text not null,
  total_stock int not null default 0,
  is_active boolean default true,
  created_at timestamptz default now()
);

-- 3. Orders Table
create table public.orders (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.users(id), -- Link to user
  applicant_name text not null,
  department text,
  purpose text,
  start_date date not null,
  end_date date not null,
  start_time text, -- Added in V6
  end_time text,   -- Added in V6
  status text not null default 'PENDING' check (status in ('PENDING', 'APPROVED', 'REJECTED', 'RETURNED', 'CANCELLED')),
  admin_note text,
  created_at timestamptz default now()
);

-- 4. Order Items Table (Many-to-Many)
create table public.order_items (
  id uuid default gen_random_uuid() primary key,
  order_id uuid references public.orders(id) on delete cascade,
  item_id uuid references public.items(id),
  item_name_snapshot text, -- In case item name changes
  quantity int not null default 1,
  created_at timestamptz default now()
);

-- Enable RLS (Row Level Security)
alter table public.users enable row level security;
alter table public.items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Policies

-- USERS
-- Allow anyone to read users (for login check on frontend - insecure but simple for MVP without backend)
-- Ideally, this should be restricted, but since we are simulating auth with direct DB access:
create policy "Allow public read users" on public.users for select using (true);
create policy "Allow public insert users" on public.users for insert with check (true);
create policy "Allow public update users" on public.users for update using (true);
create policy "Allow public delete users" on public.users for delete using (true);


-- ITEMS
create policy "Allow public read items" on public.items for select using (true);
create policy "Allow public insert items" on public.items for insert with check (true);
create policy "Allow public update items" on public.items for update using (true);
create policy "Allow public delete items" on public.items for delete using (true);

-- ORDERS
create policy "Allow public insert orders" on public.orders for insert with check (true);
create policy "Allow public read orders" on public.orders for select using (true);
create policy "Allow update orders" on public.orders for update using (true);
create policy "Allow public delete orders" on public.orders for delete using (true);

-- ORDER ITEMS
create policy "Allow public insert order_items" on public.order_items for insert with check (true);
create policy "Allow public read order_items" on public.order_items for select using (true);
create policy "Allow public delete order_items" on public.order_items for delete using (true);

-- Indexes
create index idx_orders_dates on public.orders (start_date, end_date);
create index idx_order_items_order_id on public.order_items (order_id);
create index idx_order_items_item_id on public.order_items (item_id);

-- Default Admin User
insert into public.users (username, password, name, role, department) values
('admin', 'admin', '系統管理員', 'ADMIN', 'IT');
