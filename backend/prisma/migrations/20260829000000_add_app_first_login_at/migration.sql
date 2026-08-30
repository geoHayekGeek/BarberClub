-- Track when a user first authenticated in the mobile app.
-- Website users imported before opening the app remain NULL until that moment.
ALTER TABLE "users"
ADD COLUMN "app_first_login_at" TIMESTAMP(3);

-- Existing app users must not receive historical website-booking rewards after
-- this migration. Website-imported users who have never logged into the app
-- remain NULL and will be enrolled by the first-login code.
UPDATE "users" AS u
SET "app_first_login_at" = COALESCE(u."last_login_at", CURRENT_TIMESTAMP)
WHERE u."app_first_login_at" IS NULL
  AND (
    u."last_login_at" IS NOT NULL
    OR NOT EXISTS (
      SELECT 1
      FROM "user_sync_links" AS link
      WHERE link."app_user_id" = u."id"
        AND link."last_synced_from" = 'WEBSITE'
    )
  );
