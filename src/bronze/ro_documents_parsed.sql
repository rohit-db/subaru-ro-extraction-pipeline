-- Bronze: Ingest and parse PDF repair order documents
-- Uses Auto Loader (read_files) for incremental file ingestion
-- and ai_parse_document to extract structured content from each PDF.
--
-- The source volume path is supplied by the pipeline configuration key
-- `source_volume_path` (see resources/subaru_ro_extraction.pipeline.yml).
-- Set it to the UC Volume folder where you uploaded the sample PDFs, e.g.
--   /Volumes/<catalog>/<schema>/ro_documents/source_files/

CREATE OR REFRESH STREAMING TABLE ro_documents_parsed
COMMENT 'Raw parsed repair order documents from Concordville Subaru PDFs'
AS
SELECT
  path,
  ai_parse_document(
    content,
    map('version', '2.0', 'descriptionElementTypes', '*')
  ) AS parsed
FROM STREAM read_files(
  '${source_volume_path}',
  format => 'binaryFile'
);
