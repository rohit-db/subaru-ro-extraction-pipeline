# Subaru Repair Order (RO) Document Extraction Pipeline

A reference **Lakeflow Spark Declarative Pipeline** on Databricks that turns
scanned/PDF automotive repair orders into clean, queryable tables — no manual
data entry, no brittle regex parsing. It uses Databricks' built-in AI SQL
functions (`ai_parse_document`, `ai_extract`) so the entire pipeline is just
SQL + a little Python, running on **serverless** compute.

Built by the Databricks team for **Charlie @ Subaru** as a worked example of
"how do I build a document-extraction pipeline?" Clone it, deploy it, and
adapt it to your own documents.

---

## What it does

```
   PDF repair orders (UC Volume)
              │
              ▼
┌───────────────────────────────────────────────────────────────┐
│ BRONZE   ro_documents_parsed        (Streaming Table)           │
│   Auto Loader ingests each PDF, ai_parse_document() extracts    │
│   layout-aware text + structural elements as a VARIANT.         │
└───────────────────────────────────────────────────────────────┘
              │
              ▼
┌───────────────────────────────────────────────────────────────┐
│ SILVER 1  ro_elements_chunked       (Materialized View)         │
│   Explodes document elements and groups them by RO number so    │
│   each row = one complete repair order (1–2 pages). This keeps  │
│   every RO comfortably within ai_extract's context window.      │
├───────────────────────────────────────────────────────────────┤
│ SILVER 2  ro_extracted              (Materialized View)         │
│   ai_extract() pulls a rich, nested schema from each RO chunk:  │
│   vehicle info, service lines, parts, labor, and financial      │
│   totals — all in one call per RO.                              │
└───────────────────────────────────────────────────────────────┘
              │
              ▼
┌───────────────────────────────────────────────────────────────┐
│ GOLD    Three normalized, BI-ready Materialized Views:          │
│   • repair_orders   — one row per RO (vehicle + totals)         │
│   • service_lines   — one row per service operation             │
│   • parts_detail    — one row per part used                     │
└───────────────────────────────────────────────────────────────┘
```

### Why the "chunk by RO" step matters

A single PDF here holds ~13 repair orders across many pages. Feeding a whole
multi-page document to `ai_extract` in one shot causes two problems: you blow
past the token window, and totals "carry over" between orders get mixed up.
The **Silver 1** step solves this by detecting each `RO <number>` header and
forward-filling every element to its parent RO, so `ai_extract` always sees
exactly one order at a time with full context. This is the single most
important design decision in the pipeline — reuse the pattern for any
multi-record document.

---

## Repository layout

```
├── databricks.yml                     # Asset Bundle definition (deploy config)
├── resources/                         # (reserved for extra bundle resources)
├── src/
│   ├── bronze/ro_documents_parsed.sql # ingest + ai_parse_document
│   ├── silver/ro_elements_chunked.sql # chunk elements by RO boundary
│   ├── silver/ro_extracted.sql        # ai_extract structured schema per RO
│   └── gold/
│       ├── repair_orders.sql          # one row per RO
│       ├── service_lines.sql          # one row per service line
│       └── parts_detail.py            # one row per part (Python MV)
├── setup/create_volume_and_upload.sh  # create UC volume + upload your PDFs
├── sample_data/                       # drop your source PDFs here (not committed)
└── docs/                              # data dictionary + sample queries
```

---

## Prerequisites

- A Databricks workspace with **Unity Catalog** and **serverless** compute enabled.
- The AI functions `ai_parse_document` and `ai_extract` available in your region
  (they run on Databricks-hosted foundation models — no endpoint setup needed).
- [Databricks CLI](https://docs.databricks.com/dev-tools/cli/install.html) **v0.230+**.
- Privileges to create (or reuse) a catalog, schema, and volume.

---

## Quick start

```bash
# 1. Authenticate to your workspace
databricks auth login --host https://<your-workspace>.cloud.databricks.com

# 2. Add your source PDFs to sample_data/, then create the volume and upload
#    (adjust CATALOG/SCHEMA to something you have rights to)
CATALOG=main SCHEMA=subaru_ro ./setup/create_volume_and_upload.sh

# 3. Point the bundle at your workspace + volume
#    Edit databricks.yml:
#      - targets.dev.workspace.host  -> your workspace URL
#      - variables.catalog / schema / source_volume_path defaults
#    (or override on the CLI, see below)

# 4. Deploy and run
databricks bundle deploy -t dev
databricks bundle run subaru_ro_extraction -t dev
```

Override variables without editing the file:

```bash
databricks bundle deploy -t dev \
  --var="catalog=main,schema=subaru_ro,source_volume_path=/Volumes/main/subaru_ro/ro_documents/source_files"
```

When the run finishes, query the gold tables:

```sql
SELECT * FROM main.subaru_ro.repair_orders  ORDER BY ro_number;
SELECT * FROM main.subaru_ro.service_lines  WHERE pay_type = 'CUST';
SELECT * FROM main.subaru_ro.parts_detail   WHERE part_number IS NOT NULL;
```

See [`docs/sample_queries.sql`](docs/sample_queries.sql) for more, and
[`docs/data_dictionary.md`](docs/data_dictionary.md) for the full schema.

---

## Adapting this to your own documents

1. **Swap the source PDFs** — drop your files into the volume `source_files/`
   folder. Auto Loader picks them up incrementally on the next run.
2. **Change the record boundary** — in `src/silver/ro_elements_chunked.sql`,
   the marker regex `^RO [0-9]+` defines where one record ends and the next
   begins. Replace it with whatever header your documents use (invoice number,
   claim ID, etc.).
3. **Change the extraction schema** — edit the JSON schema in
   `src/silver/ro_extracted.sql` to match the fields you care about, and update
   the `instructions` hint. The gold views read from that schema, so adjust
   them to match.

---

## Known caveats (on the sample data)

These reflect the **redacted sample PDFs**, not pipeline defects — worth knowing
when you eyeball the output:

- **VIN and other PII are blank** — the sample PDFs are PII-redacted, so
  `ai_extract` correctly returns empty values for those fields.
- **A few warranty / internal-pay ROs show `$0` header totals** while their
  service lines still carry real labor/parts values. On those documents the
  customer-due total genuinely is `$0`; use `service_lines` for the underlying
  work value. See `docs/data_dictionary.md`.
- **`ai_parse_document` / `ai_extract` are probabilistic.** Field-level accuracy
  is high on these forms but not guaranteed. For production, add data-quality
  expectations (Lakeflow `EXPECT` constraints) and reconcile header totals
  against summed service lines.

---

## Data & privacy

Source PDFs are intentionally **not** committed to this public repository.
Add your own repair-order documents to `sample_data/` locally — they are
ignored by git so customer documents never land in version control. Do not
commit un-redacted (or any) customer documents to a public repository.

---

*Questions? Reach out to your Databricks account team.*
