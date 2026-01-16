-- Add safety_stock column to items table
-- This column is optional (nullable). 
-- If NULL, the item is ignored by 'Low Stock' alerts (useful for fixed assets).
-- If SET (e.g., 5), the item is flagged as 'Low Stock' when quantity <= safety_stock.

ALTER TABLE items ADD COLUMN safety_stock INTEGER DEFAULT NULL;

-- Optional: Comment on column
COMMENT ON COLUMN items.safety_stock IS 'Threshold for low stock alert. If NULL, no alert is triggered.';
