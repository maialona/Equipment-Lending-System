-- Migration V5: Seed Meeting Room Data

-- Insert Meeting Rooms into items table
-- We use 'Space' as category to distinguish from equipment
insert into public.items (name, category, total_stock, is_active) values
('會議室 A (大)', '空間', 1, true),
('會議室 B (中)', '空間', 1, true),
('開放討論區', '空間', 1, true);
