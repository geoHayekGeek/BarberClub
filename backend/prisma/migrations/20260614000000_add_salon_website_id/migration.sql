-- Add public website slug used by the reservation backend.
ALTER TABLE "salons" ADD COLUMN "website_id" TEXT;

-- Backfill the two known salons so existing data can be resolved immediately.
UPDATE "salons"
SET "website_id" = 'grenoble'
WHERE "website_id" IS NULL
  AND (
    LOWER("city") = 'grenoble'
    OR LOWER("name") LIKE '%grenoble%'
  );

UPDATE "salons"
SET "website_id" = 'meylan'
WHERE "website_id" IS NULL
  AND (
    LOWER("city") = 'meylan'
    OR LOWER("name") LIKE '%meylan%'
  );

CREATE UNIQUE INDEX "salons_website_id_key" ON "salons"("website_id");
