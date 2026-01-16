-- Migration Script v2: Rename Email to Username
-- 請將此腳本複製到 Supabase SQL Editor 執行

-- 1. 將 users 資料表的 email 欄位重新命名為 username
alter table public.users rename column email to username;

-- 2. 修改欄位限制 (如果在之前建立時有特定 email 格式檢查，這裡可以移除，不過我們之前是用 text 所以不需要)
-- 確保 username 依然是唯一的
-- (Unique constraint should automatically carry over)

-- 3. 如果需要，可以更新現有 admin 的 username (如果之前是用 'admin' 作為 email，這步其實不用動，因為值還是 'admin')
-- update public.users set username = 'admin' where username = 'admin'; -- Example
