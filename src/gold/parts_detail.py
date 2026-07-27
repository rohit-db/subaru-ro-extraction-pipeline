# Gold: Normalized parts detail - one row per part used in a service operation
# Uses Python + get_json_object for nested JSON array explosion

from pyspark import pipelines as dp
from pyspark.sql.functions import col, explode, expr, from_json, get_json_object
from pyspark.sql.types import ArrayType, StringType


@dp.materialized_view(
    comment="One row per part used across all service lines and repair orders"
)
def parts_detail():
    return spark.sql("""
        SELECT
          ro_number,
          get_json_object(sl_json, '$.line_number.value')::INT AS line_number,
          get_json_object(sl_json, '$.op_code.value')::STRING AS op_code,
          get_json_object(sl_json, '$.technician.value')::STRING AS technician,
          get_json_object(p_json, '$.part_number.value')::STRING AS part_number,
          get_json_object(p_json, '$.description.value')::STRING AS part_description,
          get_json_object(p_json, '$.quantity.value')::INT AS quantity,
          get_json_object(p_json, '$.part_cost.value')::DOUBLE AS part_cost,
          get_json_object(p_json, '$.part_sale.value')::DOUBLE AS part_sale
        FROM ro_extracted
        LATERAL VIEW explode(
          from_json(extracted:response.service_lines::STRING, 'ARRAY<STRING>')
        ) t AS sl_json
        LATERAL VIEW explode(
          from_json(get_json_object(sl_json, '$.parts')::STRING, 'ARRAY<STRING>')
        ) t2 AS p_json
        WHERE extracted:error_message::STRING IS NULL
    """)
