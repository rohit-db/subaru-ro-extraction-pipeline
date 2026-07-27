-- Gold: Normalized repair orders - one row per RO with vehicle info and totals

CREATE OR REFRESH MATERIALIZED VIEW repair_orders
COMMENT 'One row per repair order with vehicle information and financial totals'
AS
SELECT
  ro_number,
  extracted:response.vin.value::STRING AS vin,
  extracted:response.year.value::INT AS vehicle_year,
  extracted:response.make.value::STRING AS make,
  extracted:response.model.value::STRING AS model,
  extracted:response.color.value::STRING AS color,
  extracted:response.license_plate.value::STRING AS license_plate,
  extracted:response.miles_in.value::INT AS miles_in,
  extracted:response.miles_out.value::INT AS miles_out,
  extracted:response.service_advisor.value::STRING AS service_advisor,
  extracted:response.total_labor.value::DOUBLE AS total_labor,
  extracted:response.total_parts.value::DOUBLE AS total_parts,
  extracted:response.total_misc.value::DOUBLE AS total_misc,
  extracted:response.total_charges.value::DOUBLE AS total_charges,
  extracted:response.total_discounts.value::DOUBLE AS total_discounts,
  extracted:response.sales_tax.value::DOUBLE AS sales_tax,
  extracted:response.total_due.value::DOUBLE AS total_due,
  path AS source_file
FROM ro_extracted
WHERE extracted:error_message::STRING IS NULL;
