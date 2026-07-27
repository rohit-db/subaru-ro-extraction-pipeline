-- Gold: Normalized service lines - one row per service operation
-- Explodes VARIANT array as JSON strings and uses get_json_object for field access

CREATE OR REFRESH MATERIALIZED VIEW service_lines
COMMENT 'One row per service line operation with labor and cost details'
AS
SELECT
  ro_number,
  get_json_object(sl_json, '$.line_number.value')::INT AS line_number,
  get_json_object(sl_json, '$.pay_type.value')::STRING AS pay_type,
  get_json_object(sl_json, '$.op_code.value')::STRING AS op_code,
  get_json_object(sl_json, '$.operation_description.value')::STRING AS operation_description,
  get_json_object(sl_json, '$.complaint.value')::STRING AS complaint,
  get_json_object(sl_json, '$.cause.value')::STRING AS cause,
  get_json_object(sl_json, '$.correction.value')::STRING AS correction,
  get_json_object(sl_json, '$.technician.value')::STRING AS technician,
  get_json_object(sl_json, '$.labor_hours.value')::DOUBLE AS labor_hours,
  get_json_object(sl_json, '$.labor_subtotal.value')::DOUBLE AS labor_subtotal,
  get_json_object(sl_json, '$.labor_cost.value')::DOUBLE AS labor_cost,
  get_json_object(sl_json, '$.parts_total.value')::DOUBLE AS parts_total,
  get_json_object(sl_json, '$.labor_discount.value')::DOUBLE AS labor_discount,
  get_json_object(sl_json, '$.misc_charges.value')::DOUBLE AS misc_charges,
  get_json_object(sl_json, '$.line_subtotal.value')::DOUBLE AS line_subtotal
FROM ro_extracted
LATERAL VIEW explode(
  from_json(extracted:response.service_lines::STRING, 'ARRAY<STRING>')
) t AS sl_json
WHERE extracted:error_message::STRING IS NULL;
