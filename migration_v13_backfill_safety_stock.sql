-- Backfill safety_stock with random values for existing items
-- Criteria:
-- 1. Exclude '空間' (Space) category (keep as NULL)
-- 2. Set random safety_stock between 2 and 5 for others

UPDATE items
SET safety_stock = floor(random() * 4 + 2)::int
WHERE category != '空間';

-- Verify the update
-- SELECT name, category, total_stock, safety_stock FROM items;
