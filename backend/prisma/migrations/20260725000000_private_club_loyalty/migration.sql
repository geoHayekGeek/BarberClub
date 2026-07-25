-- Private Club loyalty: split rank progress from points and stabilize reward milestones.

ALTER TABLE "loyalty_accounts"
ADD COLUMN "lifetime_appointments" INTEGER NOT NULL DEFAULT 0;

ALTER TABLE "loyalty_transactions"
ADD COLUMN "appointment_count" INTEGER NOT NULL DEFAULT 0;

ALTER TABLE "website_booking_loyalty_grants"
ADD COLUMN "appointments_awarded" INTEGER NOT NULL DEFAULT 1;

ALTER TABLE "loyalty_rewards"
ADD COLUMN "slug" TEXT,
ADD COLUMN "sort_order" INTEGER NOT NULL DEFAULT 0;

UPDATE "loyalty_transactions"
SET "appointment_count" = 1
WHERE "type" = 'EARN'
  AND "appointment_count" = 0;

UPDATE "loyalty_accounts" AS account
SET "lifetime_appointments" = COALESCE(earned.total_appointments, 0)
FROM (
  SELECT
    "account_id",
    SUM("appointment_count")::INTEGER AS total_appointments
  FROM "loyalty_transactions"
  GROUP BY "account_id"
) AS earned
WHERE account."id" = earned."account_id";

-- Keep historical redemptions intact, but remove legacy catalog rows from future reward lists.
UPDATE "loyalty_rewards"
SET "is_active" = FALSE
WHERE "is_active" = TRUE
  AND "slug" IS NULL;

INSERT INTO "loyalty_rewards" (
  "id",
  "slug",
  "name",
  "cost_points",
  "description",
  "image_url",
  "is_active",
  "sort_order",
  "created_at"
) VALUES
  (
    '75f6d7a2-42bf-4b2a-9b31-0f7496c00075',
    'product_30_percent',
    '30% off a product',
    75,
    'Redeem for 30% off one product.',
    NULL,
    TRUE,
    10,
    CURRENT_TIMESTAMP
  ),
  (
    '150d3a8e-3a1f-4c2f-b4f4-0f7496c00150',
    'free_product',
    'Free product',
    150,
    'Redeem for one free product.',
    NULL,
    TRUE,
    20,
    CURRENT_TIMESTAMP
  ),
  (
    '250f827d-4fb0-4a9d-b271-0f7496c00250',
    'fragrance_20_percent',
    '20% off a fragrance',
    250,
    'Redeem for 20% off one fragrance.',
    NULL,
    TRUE,
    30,
    CURRENT_TIMESTAMP
  ),
  (
    '300a450a-2d9a-41fe-a9ec-0f7496c00300',
    'facial_or_beard_free',
    'Free facial treatment OR free beard trim',
    300,
    'Redeem for one free facial treatment or one free beard trim.',
    NULL,
    TRUE,
    40,
    CURRENT_TIMESTAMP
  );

CREATE UNIQUE INDEX "loyalty_rewards_slug_key"
ON "loyalty_rewards"("slug");

CREATE INDEX "loyalty_rewards_is_active_sort_order_cost_points_idx"
ON "loyalty_rewards"("is_active", "sort_order", "cost_points");
