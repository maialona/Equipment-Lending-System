-- Migration Script: Add Authentication & User Management
-- 請將此腳本複製到 Supabase SQL Editor 執行，以更新現有資料庫。

-- 1. 建立 users 資料表 (如果不存在)
create table if not exists public.users (
  id uuid default gen_random_uuid() primary key,
  email text not null unique,
  password text not null,
  name text not null,
  role text not null check (role in ('ADMIN', 'USER')),
  department text,
  created_at timestamptz default now()
);

-- 2. 啟用 Users 的 RLS (Row Level Security)
alter table public.users enable row level security;

-- 3. 建立 Users 的存取策略 (Policies)
-- 先刪除舊策略避免重複錯誤
drop policy if exists "Allow public read users" on public.users;
drop policy if exists "Allow public insert users" on public.users;
drop policy if exists "Allow public update users" on public.users;
drop policy if exists "Allow public delete users" on public.users;

create policy "Allow public read users" on public.users for select using (true);
create policy "Allow public insert users" on public.users for insert with check (true);
create policy "Allow public update users" on public.users for update using (true);
create policy "Allow public delete users" on public.users for delete using (true);

-- 4. 新增欄位到 Orders 資料表
-- 如果 user_id 欄位已存在，這行會被略過 (使用 if not exists 避免錯誤，但在 postgres add column 不支援 if not exists 標準語法，所以用 do block)
do $$ 
begin 
  if not exists (select 1 from information_schema.columns where table_name='orders' and column_name='user_id') then
    alter table public.orders add column user_id uuid references public.users(id);
  end if;
end $$;

-- 5. 插入預設管理員帳號
insert into public.users (email, password, name, role, department)
values ('admin', 'admin', '系統管理員', 'ADMIN', 'IT')
on conflict (email) do nothing;
