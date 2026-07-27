-- Silver 1: Chunk parsed document elements by Repair Order boundary
-- Each RO starts with a text element containing "RO XXXXXX"
-- This groups elements so each row contains all content for a single RO
-- Critical for ai_extract: each RO is 1-2 pages (within token limits)

CREATE OR REFRESH MATERIALIZED VIEW ro_elements_chunked
COMMENT 'Parsed document elements chunked by individual repair order'
AS
WITH elements_exploded AS (
  -- Explode the document elements array from the parsed VARIANT
  SELECT
    path,
    elem.id AS element_id,
    elem.type AS element_type,
    elem.content AS element_content,
    elem.bbox[0].page_id AS page_id
  FROM ro_documents_parsed
  LATERAL VIEW explode(
    from_json(
      parsed:document.elements::STRING,
      'ARRAY<STRUCT<id: BIGINT, type: STRING, content: STRING, confidence: DOUBLE, bbox: ARRAY<STRUCT<page_id: BIGINT, coord: ARRAY<BIGINT>>>>>'
    )
  ) t AS elem
),
ro_boundaries AS (
  -- Identify RO number markers and assign each element to its parent RO
  SELECT
    *,
    CASE
      WHEN element_type = 'text' AND element_content RLIKE '^RO [0-9]+'
      THEN regexp_extract(element_content, 'RO ([0-9]+)', 1)
      ELSE NULL
    END AS ro_marker
  FROM elements_exploded
),
ro_assigned AS (
  -- Forward-fill: assign each element to the most recent RO marker above it
  SELECT
    path,
    element_id,
    element_type,
    element_content,
    page_id,
    LAST_VALUE(ro_marker, true) OVER (
      PARTITION BY path
      ORDER BY element_id
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS ro_number
  FROM ro_boundaries
)
-- Concatenate all element content per RO into a single text blob for extraction
SELECT
  path,
  ro_number,
  concat_ws('\n', collect_list(element_content)) AS ro_content
FROM ro_assigned
WHERE ro_number IS NOT NULL
  AND element_type != 'page_footer'
GROUP BY path, ro_number;
