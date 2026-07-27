-- Sample queries against the gold layer.
-- Replace `main.subaru_ro` with your catalog.schema if you changed the defaults.

-- 1. All repair orders with vehicle info and totals
SELECT ro_number, vehicle_year, make, model, service_advisor, total_charges, total_due
FROM main.subaru_ro.repair_orders
ORDER BY ro_number;

-- 2. Revenue by service advisor (customer-pay work only)
SELECT r.service_advisor,
       COUNT(DISTINCT r.ro_number) AS num_ros,
       ROUND(SUM(s.line_subtotal), 2) AS customer_revenue
FROM main.subaru_ro.repair_orders r
JOIN main.subaru_ro.service_lines s USING (ro_number)
WHERE s.pay_type = 'CUST'
GROUP BY r.service_advisor
ORDER BY customer_revenue DESC;

-- 3. Most-used parts across all repair orders
SELECT part_number, part_description,
       SUM(quantity) AS total_qty,
       ROUND(SUM(part_sale), 2) AS total_sale
FROM main.subaru_ro.parts_detail
WHERE part_number IS NOT NULL
GROUP BY part_number, part_description
ORDER BY total_qty DESC
LIMIT 20;

-- 4. Work mix by pay type (customer vs internal vs warranty)
SELECT pay_type,
       COUNT(*) AS num_lines,
       COUNT(DISTINCT ro_number) AS num_ros,
       ROUND(SUM(line_subtotal), 2) AS total_value
FROM main.subaru_ro.service_lines
GROUP BY pay_type
ORDER BY total_value DESC;

-- 5. Data-quality check: reconcile header totals vs summed service lines
--    (large gaps flag ROs worth a manual review)
SELECT r.ro_number,
       r.total_charges AS header_charges,
       ROUND(SUM(s.line_subtotal), 2) AS sum_line_subtotal,
       ROUND(r.total_charges - SUM(s.line_subtotal), 2) AS delta
FROM main.subaru_ro.repair_orders r
JOIN main.subaru_ro.service_lines s USING (ro_number)
GROUP BY r.ro_number, r.total_charges
HAVING ABS(COALESCE(r.total_charges, 0) - SUM(s.line_subtotal)) > 1
ORDER BY ABS(delta) DESC;

-- 6. Technician productivity: labor hours booked
SELECT technician,
       COUNT(*) AS num_operations,
       ROUND(SUM(labor_hours), 1) AS total_hours
FROM main.subaru_ro.service_lines
WHERE technician IS NOT NULL
GROUP BY technician
ORDER BY total_hours DESC;
