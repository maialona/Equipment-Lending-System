-- Migration V16: Decrement Stock Function
-- Purpose: Atomically reduce item stock when a consumable is claimed.

CREATE OR REPLACE FUNCTION decrement_stock(item_id UUID, amount INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE items
  SET total_stock = GREATEST(0, total_stock - amount) -- Prevent negative stock
  WHERE id = item_id;
END;
$$;
