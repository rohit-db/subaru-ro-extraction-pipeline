-- Silver 2: Extract structured data from each RO chunk using ai_extract
-- Each row is one RO (1-2 pages), well within ai_extract token limits
-- This solves the carry-over totals problem: ai_extract sees the full RO context

CREATE OR REFRESH MATERIALIZED VIEW ro_extracted
COMMENT 'Structured repair order data extracted via ai_extract per-RO chunk'
AS
SELECT
  path,
  ro_number,
  ai_extract(
    ro_content,
    '{
      "ro_number": {"type": "string", "description": "Repair Order number"},
      "vin": {"type": "string", "description": "Vehicle Identification Number"},
      "year": {"type": "integer", "description": "Vehicle model year"},
      "make": {"type": "string"},
      "model": {"type": "string"},
      "color": {"type": "string"},
      "license_plate": {"type": "string"},
      "miles_in": {"type": "integer"},
      "miles_out": {"type": "integer"},
      "service_advisor": {"type": "string"},
      "service_lines": {
        "type": "array",
        "description": "Each numbered service operation on this RO",
        "items": {
          "type": "object",
          "properties": {
            "line_number": {"type": "integer", "description": "Service line number (1, 2, 3...)"},
            "pay_type": {"type": "string", "description": "Pay type: CUST (customer), INTR (internal), or WARR (warranty)"},
            "op_code": {"type": "string", "description": "Operation code e.g. 01SUZXS01"},
            "operation_description": {"type": "string"},
            "complaint": {"type": "string"},
            "cause": {"type": "string"},
            "correction": {"type": "string"},
            "technician": {"type": "string"},
            "labor_hours": {"type": "number"},
            "labor_subtotal": {"type": "number"},
            "labor_cost": {"type": "number"},
            "parts": {
              "type": "array",
              "description": "Parts used in this service line",
              "items": {
                "type": "object",
                "properties": {
                  "part_number": {"type": "string"},
                  "description": {"type": "string"},
                  "quantity": {"type": "integer"},
                  "part_cost": {"type": "number"},
                  "part_sale": {"type": "number"}
                }
              }
            },
            "parts_total": {"type": "number"},
            "labor_discount": {"type": "number"},
            "misc_charges": {"type": "number"},
            "line_subtotal": {"type": "number"}
          }
        }
      },
      "total_labor": {"type": "number", "description": "RO total labor amount"},
      "total_parts": {"type": "number", "description": "RO total parts amount"},
      "total_misc": {"type": "number"},
      "total_charges": {"type": "number"},
      "total_discounts": {"type": "number"},
      "sales_tax": {"type": "number"},
      "total_due": {"type": "number", "description": "Final total due amount"}
    }',
    map('instructions', 'This is a single automotive repair order from Concordville Subaru. Extract all numbered service lines (#1, #2, etc.) with their parts, labor, and costs. The totals section has Labor Amount, Parts Amount, Misc Charges, Total Charges, Less discounts, Sales Tax, and Total Due. Tables may carry over from the previous page - include all data.')
  ) AS extracted
FROM ro_elements_chunked;
