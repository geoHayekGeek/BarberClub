-- Add nullable profile avatar URL for users
ALTER TABLE "users"
ADD COLUMN "avatar_url" TEXT;
