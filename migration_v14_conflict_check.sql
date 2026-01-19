-- Migration V14: Add Inventory Conflict Check Function
-- Purpose: Prevent overbooking by calculating reserved quantity for a specific date range.

CREATE OR REPLACE FUNCTION check_stock_availability(
  p_item_id UUID,
  p_start_date DATE,
  p_end_date DATE
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  reserved_qty INTEGER;
BEGIN
  -- Sum quantity from active orders (PENDING, APPROVED) that overlap with the requested period
  SELECT COALESCE(SUM(oi.quantity), 0)
  INTO reserved_qty
  FROM order_items oi
  JOIN orders o ON oi.order_id = o.id
  WHERE oi.item_id = p_item_id
    AND o.status IN ('PENDING', 'APPROVED', 'DUE_SOON', 'OVERDUE') -- Active statuses
    AND (
      -- Overlap logic: (StartA <= EndB) and (EndA >= StartB)
      (o.start_date <= p_end_date) AND (o.end_date >= p_start_date)
    );

  RETURN reserved_qty;
END;
$$;
