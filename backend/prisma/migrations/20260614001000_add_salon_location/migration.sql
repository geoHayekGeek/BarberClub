-- Add display location used by the app UI and seed data.
ALTER TABLE "salons" ADD COLUMN "location" TEXT;

-- Backfill the known salon locations so existing records display correctly.
UPDATE "salons"
SET "location" = 'Centre Ville'
WHERE "location" IS NULL
  AND (
    LOWER("city") = 'grenoble'
    OR LOWER("name") LIKE '%grenoble%'
  );

UPDATE "salons"
SET "location" = 'Près de corenc'
WHERE "location" IS NULL
  AND (
    LOWER("city") = 'meylan'
    OR LOWER("name") LIKE '%meylan%'
  );
