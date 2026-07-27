# Data Dictionary

All tables are published to `<catalog>.<schema>` (default `main.subaru_ro`).

## Bronze

### `ro_documents_parsed` (Streaming Table)
Raw parsed PDFs. One row per source file.

| Column | Type | Notes |
|--------|------|-------|
| `path`   | STRING  | Source file path in the UC Volume |
| `parsed` | VARIANT | Full `ai_parse_document` output (layout, elements, text) |

## Silver

### `ro_elements_chunked` (Materialized View)
One row per repair order, with all its document text concatenated.

| Column | Type | Notes |
|--------|------|-------|
| `path`       | STRING | Source file |
| `ro_number`  | STRING | Repair order number (from the `RO <number>` header) |
| `ro_content` | STRING | All element text for this RO, newline-joined |

### `ro_extracted` (Materialized View)
One row per RO with the raw `ai_extract` result as VARIANT.

| Column | Type | Notes |
|--------|------|-------|
| `path`      | STRING  | Source file |
| `ro_number` | STRING  | Repair order number |
| `extracted` | VARIANT | Nested extraction: vehicle, service_lines[], parts[], totals |

## Gold

### `repair_orders` (Materialized View) — one row per RO
| Column | Type | Notes |
|--------|------|-------|
| `ro_number` | STRING | Repair order number |
| `vin` | STRING | Vehicle Identification Number (blank in redacted samples) |
| `vehicle_year` | INT | Model year |
| `make` | STRING | Manufacturer |
| `model` | STRING | Model |
| `color` | STRING | |
| `license_plate` | STRING | |
| `miles_in` | INT | Odometer in |
| `miles_out` | INT | Odometer out |
| `service_advisor` | STRING | |
| `total_labor` | DOUBLE | Header labor total |
| `total_parts` | DOUBLE | Header parts total |
| `total_misc` | DOUBLE | |
| `total_charges` | DOUBLE | Header total charges |
| `total_discounts` | DOUBLE | |
| `sales_tax` | DOUBLE | |
| `total_due` | DOUBLE | Final amount due (may be $0 for warranty/internal ROs) |
| `source_file` | STRING | Source PDF path |

### `service_lines` (Materialized View) — one row per service operation
| Column | Type | Notes |
|--------|------|-------|
| `ro_number` | STRING | Parent repair order |
| `line_number` | INT | Service line number on the RO |
| `pay_type` | STRING | `CUST` (customer), `INTR` (internal), `WARR` (warranty) |
| `op_code` | STRING | Operation code |
| `operation_description` | STRING | |
| `complaint` / `cause` / `correction` | STRING | The classic "3 C's" |
| `technician` | STRING | |
| `labor_hours` | DOUBLE | |
| `labor_subtotal` | DOUBLE | |
| `labor_cost` | DOUBLE | |
| `parts_total` | DOUBLE | |
| `labor_discount` | DOUBLE | |
| `misc_charges` | DOUBLE | |
| `line_subtotal` | DOUBLE | |

### `parts_detail` (Materialized View) — one row per part
| Column | Type | Notes |
|--------|------|-------|
| `ro_number` | STRING | Parent repair order |
| `line_number` | INT | Parent service line |
| `op_code` | STRING | |
| `technician` | STRING | |
| `part_number` | STRING | |
| `part_description` | STRING | |
| `quantity` | INT | |
| `part_cost` | DOUBLE | Dealer cost |
| `part_sale` | DOUBLE | Sale price |

## Relationships

```
repair_orders (ro_number)  1 ─── * service_lines (ro_number, line_number)  1 ─── * parts_detail
```
