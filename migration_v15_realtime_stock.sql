-- Migration V15: Get Equipment with Real-time Availability & Sorting
-- Purpose: Return equipment list with calculated 'available_stock' (Total - Active Loans)

-- Drop function if exists to allow modifying return type
DROP FUNCTION IF EXISTS get_equipment_availability();

CREATE OR REPLACE FUNCTION get_equipment_availability()
RETURNS TABLE (
  id UUID,
  name TEXT,
  custom_id TEXT,
  category TEXT,
  total_stock INTEGER,
  available_stock BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    i.id,
    i.name,
    i.custom_id,
    i.category,
    i.total_stock,
    GREATEST(0, (i.total_stock - COALESCE(loan_sum.active_qty, 0)))::BIGINT as available_stock
  FROM items i
  LEFT JOIN (
    SELECT oi.item_id, SUM(oi.quantity) as active_qty
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.id
    WHERE o.status IN ('APPROVED', 'DUE_SOON', 'OVERDUE')
    GROUP BY oi.item_id
  ) loan_sum ON i.id = loan_sum.item_id
  WHERE i.is_active = true
    AND i.type = 'EQUIPMENT'
    AND i.category != '空間'
  ORDER BY i.created_at DESC; -- Default sorting
END;
$$;
