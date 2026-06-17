-- Add a website-compatible password hash so app users can be mirrored into the reservation backend.
ALTER TABLE "users" ADD COLUMN "website_password_hash" TEXT;

-- Track app/website pairings and the last known snapshot for conflict resolution.
CREATE TYPE "UserSyncSource" AS ENUM ('APP', 'WEBSITE');

CREATE TABLE "user_sync_links" (
    "id" TEXT NOT NULL,
    "app_user_id" TEXT NOT NULL,
    "website_client_id" TEXT,
    "app_snapshot" TEXT,
    "website_snapshot" TEXT,
    "last_synced_from" "UserSyncSource",
    "last_synced_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_sync_links_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "user_sync_links_app_user_id_key" ON "user_sync_links"("app_user_id");
CREATE UNIQUE INDEX "user_sync_links_website_client_id_key" ON "user_sync_links"("website_client_id");
CREATE INDEX "user_sync_links_website_client_id_idx" ON "user_sync_links"("website_client_id");

ALTER TABLE "user_sync_links"
ADD CONSTRAINT "user_sync_links_app_user_id_fkey"
FOREIGN KEY ("app_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
