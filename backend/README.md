# Barber Club Backend

Production backend API for the Barber Club mobile app.

## Tech Stack

- Node.js 20+ (LTS)
- Express.js
- TypeScript
- PostgreSQL
- Prisma ORM
- Zod for validation
- Jest + Supertest for testing
- Helmet, CORS, express-rate-limit for security

## Prerequisites

- Node.js 20 or higher
- PostgreSQL (local installation, no Docker)
- pgAdmin (for database management)

## Installation

1. Clone the repository and navigate to the backend directory:
```bash
cd backend
```

2. Install dependencies:
```bash
npm install
```

3. Copy the environment file:
```bash
cp .env.example .env
```
On Windows (cmd), use `copy .env.example .env` instead.

4. Edit `.env` and configure all required variables (see Environment Setup below).

5. Generate Prisma client:
```bash
npm run prisma:generate
```

## Build the database (Prisma)

To create the same database schema as this project using Prisma:

1. **Create a PostgreSQL database** (e.g. `barber_club`) and set `DATABASE_URL` in `.env` (see [Environment Setup](#environment-setup) and [Local PostgreSQL Setup](#local-postgresql-setup-using-pgadmin)).

2. **Run migrations:**
```bash
cd backend
npm install
cp .env.example .env
# Edit .env: set DATABASE_URL, JWT_SECRET, CORS_ORIGINS. On Windows (cmd): use copy instead of cp.
npm run prisma:generate
npm run prisma:migrate
```

`npm run prisma:migrate` runs `prisma migrate dev`, which applies all migrations in `prisma/migrations/` and creates the tables. For production or CI (apply only, no new migrations), use:

```bash
npx prisma migrate deploy
```

## Environment Setup

Create a `.env` file in the backend root directory with the following variables:

```
NODE_ENV=development
PORT=3000

DATABASE_URL=postgresql://username:password@localhost:5432/barber_club?schema=public

JWT_SECRET=your-super-secret-jwt-key-change-this-in-production-min-32-chars
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=30d

CORS_ORIGINS=http://localhost:3000,http://localhost:5173

RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

LOG_LEVEL=info

FRONTEND_URL=http://localhost:5173

SMTP_HOST=
SMTP_PORT=
SMTP_USER=
SMTP_PASSWORD=
SMTP_FROM=

TIMIFY_BASE_URL=https://api.timify.com/v1
TIMIFY_REGION=EUROPE
TIMIFY_COMPANY_IDS=
TIMIFY_TIMEOUT_MS=10000
TIMIFY_MAX_RETRIES=2

LOYALTY_TARGET=10
LOYALTY_QR_TTL_SECONDS=120

ENABLE_LOCAL_CANCEL=false
BOOKING_CANCEL_CUTOFF_MINUTES=60

ADMIN_SECRET=change-me-in-production
```

### Required Variables

- `DATABASE_URL`: PostgreSQL connection string in format: `postgresql://username:password@localhost:5432/database_name?schema=public`
- `JWT_SECRET`: Secret key for JWT signing (minimum 32 characters, use a strong random string in production)
- `CORS_ORIGINS`: Comma-separated list of allowed origins for CORS

### Optional Variables

- `NODE_ENV`: Environment mode (`development`, `production`, or `test`, default: `development`)
- `PORT`: Server port (default: `3000`)
- `JWT_ACCESS_EXPIRES_IN`: Access token expiration (default: `15m`)
- `JWT_REFRESH_EXPIRES_IN`: Refresh token expiration (default: `30d`)
- `RATE_LIMIT_WINDOW_MS`: Rate limit window in milliseconds (default: `900000` = 15 minutes)
- `RATE_LIMIT_MAX_REQUESTS`: Maximum requests per window (default: `100`)
- `LOG_LEVEL`: Logging level (`error`, `warn`, `info`, `debug`, optional)
- `FRONTEND_URL`: Frontend URL for CORS and email links (default: `http://localhost:5173`)
- `TIMIFY_BASE_URL`: TIMIFY API base URL (default: `https://api.timify.com/v1`)
- `TIMIFY_REGION`: TIMIFY region (`EUROPE`, `US`, or `ASIA`, default: `EUROPE`)
- `TIMIFY_COMPANY_IDS`: Optional comma-separated list of allowed branch company IDs
- `TIMIFY_TIMEOUT_MS`: TIMIFY request timeout in milliseconds (default: `10000`)
- `TIMIFY_MAX_RETRIES`: Maximum retries for TIMIFY requests (default: `2`)
- `LOYALTY_TARGET`: Number of stamps required for a reward (default: `10`)
- `LOYALTY_QR_TTL_SECONDS`: QR code expiration in seconds (default: `120`)
- `ENABLE_LOCAL_CANCEL`: Allow users to cancel bookings via API (`true`/`false`, default: `false`)
- `BOOKING_CANCEL_CUTOFF_MINUTES`: Minutes before start time within which cancellation is disallowed (default: `60`)
- `ADMIN_SECRET`: Secret for admin endpoints (required in production; see [ADMIN.md](./ADMIN.md)). Must be changed from default in production.
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM`: Optional. When all set, password-reset emails are sent via SMTP. Otherwise, in development a dev provider stores emails in-memory (see [Email / Password Reset](#email--password-reset)).

### Email / Password Reset (OTP flow)

The **forgot-password** and **reset-password** flows use a 6-digit OTP code sent by email (no deep links).

- **forgot-password**: Sends a 6-digit code to the user's email. Code expires in 10 minutes. Resend cooldown: 60 seconds per email.
- **reset-password**: Accepts `email`, `code` (6 digits), and `newPassword`. Max 5 failed attempts per code before lockout.
- **Development without SMTP**: If `SMTP_*` are not set, the app uses an in-memory dev provider. Emails are not sent; you can view them at `GET /api/v1/dev/emails` (see [Development](#development) endpoints).
- **Development or production with SMTP**: Set all of `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, and `SMTP_FROM`. Password-reset emails are sent via SMTP.
- **Production without SMTP**: Forgot-password will fail when sending the email. Configure SMTP for production if you use password reset.

## Local PostgreSQL Setup (using pgAdmin)

### Step 1: Create Database

1. Open pgAdmin
2. Connect to your local PostgreSQL server
3. Right-click on "Databases" → "Create" → "Database"
4. Name: `barber_club`
5. Owner: Select your PostgreSQL user (or leave default)
6. Click "Save"

### Step 2: Create User (Optional)

If you want to use a dedicated user:

1. In pgAdmin, expand "Login/Group Roles"
2. Right-click → "Create" → "Login/Group Role"
3. General tab:
   - Name: `barber_user` (or your preferred name)
4. Definition tab:
   - Password: Set a secure password
5. Privileges tab:
   - Can login: Yes
6. Click "Save"

### Step 3: Grant Permissions

1. Right-click on the `barber_club` database → "Properties"
2. Go to "Security" tab
3. Add the user and grant all privileges
4. Or use SQL:
```sql
GRANT ALL PRIVILEGES ON DATABASE barber_club TO barber_user;
```

### Step 4: Update DATABASE_URL

Update your `.env` file with the correct connection string:

```
DATABASE_URL=postgresql://barber_user:your_password@localhost:5432/barber_club?schema=public
```

Or if using default postgres user:

```
DATABASE_URL=postgresql://postgres:your_password@localhost:5432/barber_club?schema=public
```

## Database Migrations

After setting up the database:

1. Run migrations to create tables:
```bash
npm run prisma:migrate
```

This will apply all migrations in `prisma/migrations/` to your database and ensure the Prisma client is generated. (Use `npx prisma migrate deploy` in production or CI to apply migrations without creating new ones.)

**Note:** If you encounter database lock timeout errors:
- Close Prisma Studio and any other database connections
- Wait 10-15 seconds and try again
- As a last resort, run the SQL from the relevant migration files in `prisma/migrations/` manually

**Important:** When you add new migrations (e.g. after schema changes), run `npm run prisma:migrate` again to apply them.

2. (Optional) Open Prisma Studio to view your database:
```bash
npm run prisma:studio
```

## Running the Application

### Development Mode

```bash
npm run dev
```

The server will start on `http://localhost:3000` (or the port specified in `.env`).

### Production Mode

1. Build the TypeScript code:
```bash
npm run build
```

2. Start the server:
```bash
npm start
```

## API Documentation

Once the server is running, access the Swagger/OpenAPI documentation at:

```
http://localhost:3000/api-docs
```

## Testing

Run tests:
```bash
npm test
```

Run tests in watch mode:
```bash
npm test:watch
```

Run tests with coverage:
```bash
npm test:coverage
```

Lint:
```bash
npm run lint
npm run lint:fix
```

## Project Structure

```
backend/
├── src/
│   ├── app.ts                 # Express app setup
│   ├── server.ts              # Server entry point
│   ├── config/                # Configuration
│   │   └── index.ts
│   ├── routes/                # API routes
│   │   ├── index.ts
│   │   ├── auth.ts
│   │   ├── booking.ts
│   │   ├── bookings.ts
│   │   ├── loyalty.ts
│   │   ├── offers.ts
│   │   ├── salons.ts
│   │   ├── barbers.ts
│   │   ├── dev.ts
│   │   └── admin.ts
│   ├── middleware/            # Express middleware
│   │   ├── auth.ts
│   │   ├── adminAuth.ts
│   │   ├── rateLimit.ts
│   │   ├── errorHandler.ts
│   │   ├── notFoundHandler.ts
│   │   └── validate.ts
│   ├── modules/               # Business logic modules
│   │   ├── auth/
│   │   │   ├── service.ts
│   │   │   ├── passwordResetService.ts
│   │   │   ├── validation.ts
│   │   │   └── utils/
│   │   ├── booking/
│   │   │   ├── service.ts
│   │   │   └── validation.ts
│   │   ├── loyalty/
│   │   │   └── service.ts
│   │   ├── offers/
│   │   │   ├── service.ts
│   │   │   └── validation.ts
│   │   ├── salons/
│   │   │   ├── service.ts
│   │   │   └── validation.ts
│   │   ├── barbers/
│   │   │   ├── service.ts
│   │   │   └── validation.ts
│   │   ├── timify/
│   │   │   ├── timifyClient.ts
│   │   │   ├── schemas.ts
│   │   │   ├── types.ts
│   │   │   └── index.ts
│   │   └── notifications/
│   │       ├── emailProvider.ts
│   │       ├── devEmailProvider.ts
│   │       ├── smtpEmailProvider.ts
│   │       └── index.ts
│   ├── db/                    # Database client
│   │   └── client.ts
│   └── utils/                 # Utility functions
│       ├── errors.ts
│       └── logger.ts
├── prisma/
│   ├── schema.prisma          # Database schema
│   └── migrations/            # Database migrations
├── tests/                     # Test files
│   ├── setup.ts
│   ├── auth.test.ts
│   ├── admin.test.ts
│   ├── booking.test.ts
│   ├── bookings.test.ts
│   ├── loyalty.test.ts
│   ├── offers.test.ts
│   ├── salons.test.ts
│   └── barbers.test.ts
├── dist/                      # Compiled JavaScript (generated)
├── .env.example               # Environment variables template
├── README.md                  # This file
├── TESTING.md                 # Complete testing guide
├── ADMIN.md                   # Admin endpoints documentation
└── package.json
```

## User Model

The User model enforces uniqueness constraints on both `email` and `phoneNumber`:

- **Email**: Must be unique across all users (case-insensitive)
- **Phone Number**: Must be unique across all users (stored in E.164 format)

Both fields serve as unique identifiers and can be used for login. Attempting to register with an existing email or phone number will result in a `409 Conflict` error with code `USER_ALREADY_EXISTS`.

## API Endpoints

### Authentication

- `POST /api/v1/auth/register` - Register a new user (requires unique email and phoneNumber)
- `POST /api/v1/auth/login` - Login with email or phone
- `POST /api/v1/auth/refresh` - Refresh access token
- `POST /api/v1/auth/logout` - Logout and revoke token
- `GET /api/v1/auth/me` - Get current user profile (requires authentication)
- `POST /api/v1/auth/forgot-password` - Request password reset (sends 6-digit OTP to email)
- `POST /api/v1/auth/reset-password` - Reset password with OTP code (email + code + newPassword)

### Booking

- `GET /api/v1/booking/branches` - Get list of bookable branches
- `GET /api/v1/booking/branches/:branchId/services` - Get services for a branch
- `GET /api/v1/booking/availability` - Get availability for a service
- `POST /api/v1/booking/reserve` - Reserve a booking slot (requires authentication)
- `POST /api/v1/booking/confirm` - Confirm a reservation (requires authentication)

### Bookings Management (Mes RDVs)

- `GET /api/v1/bookings/me` - Get current user's bookings (requires authentication)
- `GET /api/v1/bookings/:id` - Get booking details (requires authentication)
- `POST /api/v1/bookings/:id/cancel` - Cancel a booking (requires authentication)

### Offers (Nos Offres)

- `GET /api/v1/offers` - Get list of offers (public)
- `GET /api/v1/offers/:id` - Get offer details (public)

### Salons (Nos Salons)

- `GET /api/v1/salons` - Get list of active salons (public)
- `GET /api/v1/salons/:id` - Get salon details with associated barbers (public)

### Barbers (Nos Coiffeurs)

- `GET /api/v1/barbers` - Get list of active barbers (public)
- `GET /api/v1/barbers/:id` - Get barber details with associated salons (public)

### Loyalty

- `GET /api/v1/loyalty/me` - Get current user's loyalty state (requires authentication)
- `GET /api/v1/loyalty/qr` - Generate QR code for redemption (requires authentication, must be eligible)
- `POST /api/v1/loyalty/scan` - Scan and redeem QR code (salon side, no authentication required)
- `POST /api/v1/loyalty/redeem` - Redeem loyalty reward (legacy endpoint, requires authentication)

### Development

- `GET /api/v1/dev/emails` - View sent emails (development/test only)
- `DELETE /api/v1/dev/emails` - Clear sent emails (development/test only)

### Admin (Manual Administration Only)

**Note:** Admin endpoints are NOT for mobile app usage. They exist only for manual administration via Postman, curl, or scripts. See [ADMIN.md](./ADMIN.md) for detailed documentation.

- `POST /api/v1/admin/salons` - Create a new salon (admin only)
- `POST /api/v1/admin/barbers` - Create a new barber (admin only)
- `POST /api/v1/admin/offers` - Create a new offer (admin only)

### Health Check

- `GET /health` - Server health check

## Error Response Format

All errors follow this consistent format:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "fields": {
      "fieldName": "Field-specific error message"
    }
  }
}
```

## Security Features

### Rate Limiting

The API implements multiple rate limiters based on endpoint sensitivity:

- **General Limiter**: Applied to all routes (100 requests per 15 minutes by default)
- **Auth Limiter**: Login, register endpoints (5 requests per 15 minutes in production, 50 in development)
- **Password Reset Limiter**: Forgot/reset password (3 requests per 15 minutes in production, 10 in development)
- **Booking Limiter**: Reserve and confirm endpoints (10 requests per 15 minutes in production, 30 in development)
- **QR Scan Limiter**: Loyalty QR scan endpoint (10 requests per minute)
- **Public Read Limiter**: Offers, salons, barbers endpoints (60 requests per minute in production, 100 in development)
- **Admin Limiter**: Admin endpoints (5 requests per 15 minutes in production, 20 in development)

Rate limit headers are included in responses (`X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`).

### Security Measures

- **Helmet.js**: HTTP security headers (XSS protection, content security policy, etc.)
- **CORS**: Configurable allowed origins from environment variables
- **JWT Authentication**: Access tokens (15min expiry) and refresh tokens (30d expiry) with rotation
- **Password Security**: Argon2id hashing with secure defaults
- **Input Validation**: All inputs validated with Zod schemas (body, query, params)
- **Error Handling**: No stack traces exposed in production, consistent error format
- **Token Revocation**: Refresh tokens revoked on password reset and logout
- **Booking Security**: User ownership validated on all booking operations
- **QR Code Security**: Single-use tokens with expiration, no user data leakage

## Logging

The application uses a structured logger that outputs JSON. Log levels:
- `ERROR`: Error messages
- `WARN`: Warning messages
- `INFO`: Informational messages
- `DEBUG`: Debug messages

Set `LOG_LEVEL` in `.env` to control logging. Defaults to silent in production.

## TIMIFY Integration

The backend integrates with TIMIFY for booking management. All TIMIFY communication is server-to-server only - the mobile app never calls TIMIFY directly.

### Configuration

- `TIMIFY_BASE_URL`: TIMIFY API base URL (default: `https://api.timify.com/v1`)
- `TIMIFY_REGION`: TIMIFY region (`EUROPE`, `US`, or `ASIA`, default: `EUROPE`)
- `TIMIFY_COMPANY_IDS`: Optional comma-separated list of allowed branch company IDs. If not set, all companies from TIMIFY are returned.
- `TIMIFY_TIMEOUT_MS`: Request timeout in milliseconds (default: `10000`)
- `TIMIFY_MAX_RETRIES`: Maximum number of retries for transient failures (default: `2`)

### TIMIFY Authentication

**Important:** The backend uses TIMIFY Booker Services endpoints, which are **PUBLIC** and **DO NOT require authentication**.

The following endpoints are used:
- `/booker-services/companies` - Get available branches/companies
- `/booker-services/availabilities` - Get available time slots
- `/booker-services/reservations` - Create temporary reservations
- `/booker-services/appointments/confirm` - Confirm appointments

These endpoints are intentionally public and do **NOT** require:
- API keys
- Bearer tokens
- Query parameter authentication
- Any authentication headers

**Warning for developers:** Do NOT add authentication headers (Authorization, X-API-Key, etc.) to TIMIFY requests. Adding authentication to public Booker Services endpoints will cause requests to fail. Authentication is only required if switching to TIMIFY private/admin APIs, which is not used in this application.

### Booking Flow

1. **Get Branches**: Fetch available branches/companies
2. **Get Services**: Fetch services for a specific branch
3. **Check Availability**: Get available time slots
4. **Reserve**: Create a temporary reservation (expires in 10 minutes)
5. **Confirm**: Confirm the reservation and create a permanent booking

### Booking API Examples

#### Get Branches
```bash
curl http://localhost:3000/api/v1/booking/branches
```

Response:
```json
{
  "data": [
    {
      "id": "company-123",
      "name": "Downtown Branch",
      "address": "123 Main St",
      "city": "New York",
      "country": "USA",
      "timezone": "America/New_York"
    }
  ]
}
```

#### Get Services for a Branch
```bash
curl http://localhost:3000/api/v1/booking/branches/company-123/services
```

Response:
```json
{
  "data": [
    {
      "id": "service-456",
      "name": "Haircut",
      "durationMinutes": 30,
      "price": 25.00
    }
  ]
}
```

#### Get Availability
```bash
curl "http://localhost:3000/api/v1/booking/availability?branchId=company-123&serviceId=service-456&startDate=2026-02-01&endDate=2026-02-07"
```

With optional resourceId:
```bash
curl "http://localhost:3000/api/v1/booking/availability?branchId=company-123&serviceId=service-456&startDate=2026-02-01&endDate=2026-02-07&resourceId=resource-789"
```

Response:
```json
{
  "data": {
    "calendarBegin": "2026-02-01",
    "calendarEnd": "2026-02-07",
    "onDays": ["2026-02-01", "2026-02-02", "2026-02-03"],
    "offDays": ["2026-02-04"],
    "timesByDay": {
      "2026-02-01": ["09:00", "10:00", "11:00"],
      "2026-02-02": ["14:00", "15:00", "16:00"]
    }
  }
}
```

#### Reserve a Booking Slot (requires authentication)
```bash
curl -X POST http://localhost:3000/api/v1/booking/reserve \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "branchId": "company-123",
    "serviceId": "service-456",
    "date": "2026-02-01",
    "time": "10:00",
    "resourceId": "resource-789"
  }'
```

Note: `resourceId` is optional.

Response:
```json
{
  "data": {
    "reservationId": "uuid",
    "expiresAt": "2026-02-01T10:10:00Z"
  }
}
```

#### Confirm a Reservation (requires authentication)
```bash
curl -X POST http://localhost:3000/api/v1/booking/confirm \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "reservationId": "uuid-from-reserve-response"
  }'
```

Response:
```json
{
  "data": {
    "id": "uuid",
    "userId": "uuid",
    "branchId": "company-123",
    "serviceId": "service-456",
    "resourceId": "resource-789",
    "startDateTime": "2026-02-01T10:00:00Z",
    "timifyAppointmentId": "timify-appt-123",
    "status": "CONFIRMED",
    "createdAt": "2026-01-26T..."
  }
}
```

#### Get My Bookings (requires authentication)
```bash
curl http://localhost:3000/api/v1/bookings/me \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

With query parameters:
```bash
curl "http://localhost:3000/api/v1/bookings/me?status=upcoming&limit=20&cursor=2026-02-01T10:00:00Z|uuid" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Query parameters:
- `status`: Filter by status (`upcoming`, `past`, or `all`, default: `upcoming`)
- `limit`: Number of results (1-50, default: 20)
- `cursor`: Pagination cursor (format: `ISO_DATE|UUID`)

Response:
```json
{
  "data": {
    "items": [
      {
        "id": "uuid",
        "startDateTime": "2026-02-01T10:00:00Z",
        "status": "CONFIRMED",
        "branch": {
          "id": "company-123",
          "name": "Downtown Branch",
          "city": "New York"
        },
        "service": {
          "id": "service-456",
          "name": "Haircut"
        }
      }
    ],
    "nextCursor": "2026-02-01T10:00:00Z|uuid"
  }
}
```

#### Get Booking Details (requires authentication)
```bash
curl http://localhost:3000/api/v1/bookings/uuid \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Response:
```json
{
  "data": {
    "id": "uuid",
    "startDateTime": "2026-02-01T10:00:00Z",
    "status": "CONFIRMED",
    "branch": {
      "id": "company-123",
      "name": "Downtown Branch",
      "address": "123 Main St",
      "city": "New York",
      "timezone": "America/New_York"
    },
    "service": {
      "id": "service-456",
      "name": "Haircut",
      "durationMinutes": 30
    },
    "timifyAppointmentId": "timify-appt-123"
  }
}
```

#### Cancel a Booking (requires authentication)
```bash
curl -X POST http://localhost:3000/api/v1/bookings/uuid/cancel \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Response:
```json
{
  "data": {
    "status": "CANCELED"
  }
}
```

Note: Cancellation requires `ENABLE_LOCAL_CANCEL=true` and the booking must be at least `BOOKING_CANCEL_CUTOFF_MINUTES` minutes before the start time.

#### Get Offers (public)
```bash
curl http://localhost:3000/api/v1/offers
```

With query parameters:
```bash
curl "http://localhost:3000/api/v1/offers?status=active&limit=20&cursor=2026-01-26T20:00:00Z|uuid"
```

Query parameters:
- `status`: Filter by status (`active` or `all`, default: `active`)
- `limit`: Number of results (1-50, default: 20)
- `cursor`: Pagination cursor (format: `ISO_DATE|UUID`)

Response:
```json
{
  "data": {
    "items": [
      {
        "id": "uuid",
        "title": "Special Offer",
        "description": "Get 20% off on all services",
        "imageUrl": "https://example.com/offer.jpg",
        "validFrom": "2026-01-01T00:00:00Z",
        "validTo": "2026-12-31T23:59:59Z"
      }
    ],
    "nextCursor": "2026-01-26T20:00:00Z|uuid"
  }
}
```

#### Get Offer Details (public)
```bash
curl http://localhost:3000/api/v1/offers/uuid
```

Response:
```json
{
  "data": {
    "id": "uuid",
    "title": "Special Offer",
    "description": "Get 20% off on all services",
    "imageUrl": "https://example.com/offer.jpg",
    "validFrom": "2026-01-01T00:00:00Z",
    "validTo": "2026-12-31T23:59:59Z"
  }
}
```

#### Get Salons (public)
```bash
curl http://localhost:3000/api/v1/salons
```

Response:
```json
{
  "data": [
    {
      "id": "uuid",
      "name": "Salon Paris Centre",
      "city": "Paris",
      "address": "123 Rue de la Paix",
      "description": "Modern salon in the heart of Paris",
      "openingHours": "Mon-Fri 9:00-19:00, Sat 10:00-18:00",
      "images": ["https://example.com/salon1.jpg", "https://example.com/salon2.jpg"]
    }
  ]
}
```

Salons are sorted by city (ASC), then name (ASC). Only active salons are returned.

#### Get Salon Details (public)
```bash
curl http://localhost:3000/api/v1/salons/uuid
```

Response:
```json
{
  "data": {
    "id": "uuid",
    "name": "Salon Paris Centre",
    "city": "Paris",
    "address": "123 Rue de la Paix",
    "description": "Modern salon in the heart of Paris",
    "openingHours": "Mon-Fri 9:00-19:00, Sat 10:00-18:00",
    "images": ["https://example.com/salon1.jpg"],
    "barbers": [
      {
        "id": "uuid",
        "firstName": "John",
        "lastName": "Doe"
      }
    ]
  }
}
```

#### Get Barbers (public)
```bash
curl http://localhost:3000/api/v1/barbers
```

Response:
```json
{
  "data": [
    {
      "id": "uuid",
      "firstName": "John",
      "lastName": "Doe",
      "bio": "Experienced barber with 10 years in the industry",
      "experienceYears": 10,
      "images": ["https://example.com/barber1.jpg"],
      "salons": [
        {
          "id": "uuid",
          "name": "Salon Paris Centre",
          "city": "Paris"
        }
      ]
    }
  ]
}
```

Barbers are sorted by firstName (ASC). Only active barbers are returned. Only active salons are included in the salons array.

#### Get Barber Details (public)
```bash
curl http://localhost:3000/api/v1/barbers/uuid
```

Response:
```json
{
  "data": {
    "id": "uuid",
    "firstName": "John",
    "lastName": "Doe",
    "bio": "Experienced barber with 10 years in the industry",
    "experienceYears": 10,
    "interests": ["Haircuts", "Beards", "Styling"],
    "images": ["https://example.com/barber1.jpg"],
    "salons": [
      {
        "id": "uuid",
        "name": "Salon Paris Centre",
        "city": "Paris"
      }
    ]
  }
}
```

## Managing Data

Salons, barbers, and offers can be managed either via the **Admin API** (see [ADMIN.md](./ADMIN.md)) or directly in the database via pgAdmin.

### Managing Salons and Barbers

The relationship between salons and barbers is many-to-many, managed through the `barber_salons` join table. Use the Admin API (see [ADMIN.md](./ADMIN.md)) or pgAdmin as below.

#### Inserting a Salon via pgAdmin

1. Open pgAdmin and connect to your database
2. Navigate to: `Databases` → `barber_club` (or your DB name) → `Schemas` → `public` → `Tables` → `salons`
3. Right-click on `salons` → `View/Edit Data` → `All Rows`
4. Click the `+` button to add a new row
5. Fill in the fields:
   - `id`: Leave empty (auto-generated UUID)
   - `name`: Salon name (e.g., "Salon Paris Centre")
   - `city`: City name (e.g., "Paris")
   - `address`: Full address (e.g., "123 Rue de la Paix, 75001 Paris")
   - `description`: Full description text
   - `opening_hours`: Human-readable opening hours (e.g., "Mon-Fri 9:00-19:00, Sat 10:00-18:00")
   - `images`: Array of image URLs (e.g., `{"https://example.com/salon1.jpg","https://example.com/salon2.jpg"}`)
   - `is_active`: `true` to show the salon, `false` to hide it
   - `created_at`: Leave empty (auto-generated)
   - `updated_at`: Leave empty (auto-updated)
6. Click `Save` to insert the salon

#### Inserting a Barber via pgAdmin

1. Navigate to: `Databases` → `barber_club` (or your DB name) → `Schemas` → `public` → `Tables` → `barbers`
2. Right-click on `barbers` → `View/Edit Data` → `All Rows`
3. Click the `+` button to add a new row
4. Fill in the fields:
   - `id`: Leave empty (auto-generated UUID)
   - `first_name`: Barber's first name (e.g., "John")
   - `last_name`: Barber's last name (e.g., "Doe")
   - `bio`: Full biography text
   - `experience_years`: Number of years of experience (integer, nullable)
   - `interests`: Array of interests (e.g., `{"Haircuts","Beards","Styling"}`)
   - `images`: Array of image URLs (e.g., `{"https://example.com/barber1.jpg"}`)
   - `is_active`: `true` to show the barber, `false` to hide it
   - `created_at`: Leave empty (auto-generated)
   - `updated_at`: Leave empty (auto-updated)
5. Click `Save` to insert the barber

#### Linking a Barber to a Salon

1. Navigate to: `Databases` → `barber_club` (or your DB name) → `Schemas` → `public` → `Tables` → `barber_salons`
2. Right-click on `barber_salons` → `View/Edit Data` → `All Rows`
3. Click the `+` button to add a new row
4. Fill in the fields:
   - `barber_id`: UUID of the barber
   - `salon_id`: UUID of the salon
5. Click `Save` to create the association

#### Example SQL Inserts

```sql
-- Insert a salon
INSERT INTO salons (name, city, address, description, opening_hours, images, is_active)
VALUES (
  'Salon Paris Centre',
  'Paris',
  '123 Rue de la Paix, 75001 Paris',
  'Modern salon in the heart of Paris',
  'Mon-Fri 9:00-19:00, Sat 10:00-18:00',
  ARRAY['https://example.com/salon1.jpg', 'https://example.com/salon2.jpg'],
  true
);

-- Insert a barber
INSERT INTO barbers (first_name, last_name, bio, experience_years, interests, images, is_active)
VALUES (
  'John',
  'Doe',
  'Experienced barber with 10 years in the industry',
  10,
  ARRAY['Haircuts', 'Beards', 'Styling'],
  ARRAY['https://example.com/barber1.jpg'],
  true
);

-- Link barber to salon
INSERT INTO barber_salons (barber_id, salon_id)
VALUES (
  'barber-uuid-here',
  'salon-uuid-here'
);
```

### Managing Offers

Use the Admin API (see [ADMIN.md](./ADMIN.md)) or pgAdmin as below.

#### Inserting an Offer via pgAdmin

1. Open pgAdmin and connect to your database
2. Navigate to: `Databases` → `barber_club` (or your DB name) → `Schemas` → `public` → `Tables` → `offers`
3. Right-click on `offers` → `View/Edit Data` → `All Rows`
4. Click the `+` button to add a new row
5. Fill in the fields:
   - `id`: Leave empty (auto-generated UUID)
   - `title`: Offer title (e.g., "Summer Special")
   - `description`: Full description text
   - `image_url`: Optional image URL (e.g., "https://cdn.example.com/offer.jpg") or NULL
   - `valid_from`: Start date (e.g., "2026-06-01 00:00:00") or NULL for immediate activation
   - `valid_to`: End date (e.g., "2026-08-31 23:59:59") or NULL for no expiration
   - `is_active`: `true` to show the offer, `false` to hide it
   - `created_at`: Leave empty (auto-generated)
   - `updated_at`: Leave empty (auto-updated)
6. Click `Save` to insert the offer

#### Example SQL Insert

```sql
INSERT INTO offers (title, description, image_url, valid_from, valid_to, is_active)
VALUES (
  'Summer Special',
  'Get 20% off on all haircuts during summer months',
  'https://cdn.example.com/summer-offer.jpg',
  '2026-06-01 00:00:00',
  '2026-08-31 23:59:59',
  true
);
```

#### Active Offers Logic

An offer is considered "active" when:
- `is_active = true`
- AND (`valid_from` is NULL OR `valid_from <= now`)
- AND (`valid_to` is NULL OR `valid_to >= now`)

## API Examples

### Authentication

#### Register
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "phoneNumber": "+1234567890",
    "password": "password123",
    "fullName": "John Doe"
  }'
```

#### Login
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }'
```

Save the `accessToken` from the response for authenticated requests.

### Booking

#### Get Branches
```bash
curl http://localhost:3000/api/v1/booking/branches
```

Response:
```json
{
  "data": [
    {
      "id": "company-123",
      "name": "Downtown Branch",
      "address": "123 Main St",
      "city": "New York",
      "country": "USA",
      "timezone": "America/New_York"
    }
  ]
}
```

#### Get Services for a Branch
```bash
curl http://localhost:3000/api/v1/booking/branches/company-123/services
```

Response:
```json
{
  "data": [
    {
      "id": "service-456",
      "name": "Haircut",
      "durationMinutes": 30,
      "price": 25.00
    }
  ]
}
```

#### Get Availability
```bash
curl "http://localhost:3000/api/v1/booking/availability?branchId=company-123&serviceId=service-456&startDate=2026-02-01&endDate=2026-02-07"
```

With optional resourceId:
```bash
curl "http://localhost:3000/api/v1/booking/availability?branchId=company-123&serviceId=service-456&startDate=2026-02-01&endDate=2026-02-07&resourceId=resource-789"
```

Response:
```json
{
  "data": {
    "calendarBegin": "2026-02-01",
    "calendarEnd": "2026-02-07",
    "onDays": ["2026-02-01", "2026-02-02", "2026-02-03"],
    "offDays": ["2026-02-04"],
    "timesByDay": {
      "2026-02-01": ["09:00", "10:00", "11:00"],
      "2026-02-02": ["14:00", "15:00", "16:00"]
    }
  }
}
```

#### Reserve a Booking Slot (requires authentication)
```bash
curl -X POST http://localhost:3000/api/v1/booking/reserve \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "branchId": "company-123",
    "serviceId": "service-456",
    "date": "2026-02-01",
    "time": "10:00",
    "resourceId": "resource-789"
  }'
```

Note: `resourceId` is optional.

Response:
```json
{
  "data": {
    "reservationId": "uuid",
    "expiresAt": "2026-02-01T10:10:00Z"
  }
}
```

Save the `reservationId` from the response for confirmation.

#### Confirm a Reservation (requires authentication)
```bash
curl -X POST http://localhost:3000/api/v1/booking/confirm \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "reservationId": "uuid-from-reserve-response"
  }'
```

Response:
```json
{
  "data": {
    "id": "uuid",
    "userId": "uuid",
    "branchId": "company-123",
    "serviceId": "service-456",
    "resourceId": "resource-789",
    "startDateTime": "2026-02-01T10:00:00Z",
    "timifyAppointmentId": "timify-appt-123",
    "status": "CONFIRMED",
    "createdAt": "2026-01-26T..."
  }
}
```

## Testing

### Running Tests

```bash
npm test
```

### Test Coverage

The test suite includes comprehensive coverage:

**Authentication Tests (24 tests):**
- User registration with validation (email, phone, password)
- Login with email and phone number
- Token refresh and rotation
- Logout and token revocation
- Password reset flow (forgot password, reset password)
- Protected endpoint access (`/me`)
- Error handling for all scenarios (invalid credentials, duplicate users, etc.)

**Booking Tests (17 tests):**
- Branch listing and filtering by TIMIFY_COMPANY_IDS
- Service retrieval for branches
- Availability transformation (onDays, offDays, timesByDay)
- Reservation creation with expiration tracking
- Booking confirmation with database updates
- Error handling (expired reservations, used reservations, unavailable slots)
- TIMIFY API mocking with nock (no external API calls needed)

**Bookings Management Tests (24 tests):**
- List user's bookings with filtering (upcoming, past, all)
- Pagination with cursor-based navigation
- Get booking details with branch and service information
- Cancel bookings with validation (cutoff time, status checks)
- Access control (users can only see/cancel their own bookings)
- Branch and service name caching
- Error handling (not found, forbidden, not cancelable)

**Offers Tests (16 tests):**
- List active offers with filtering
- Exclude expired and future offers
- Pagination with cursor
- Get offer details
- Error handling (not found, validation errors)

**Salons Tests (8 tests):**
- List returns only active salons; empty list when none exist
- Salons sorted by city ASC, name ASC
- Salon details returns associated barbers (or none)
- Invalid id returns VALIDATION_ERROR; missing salon returns SALON_NOT_FOUND

**Barbers Tests (11 tests):**
- List returns only active barbers; empty list when none exist
- Barbers sorted by firstName ASC
- Barber details returns associated salons and interests; null experienceYears, empty interests
- Invalid id returns VALIDATION_ERROR; missing barber returns BARBER_NOT_FOUND

**Admin Tests (13 tests):**
- Create salon, barber, offer with `adminSecret`; 403 when missing or incorrect
- Validation errors (invalid payload, non-existent salonIds, validFrom > validTo)

**Loyalty Tests (21 tests):**
- Loyalty state retrieval for new and existing users (with eligibleForReward field)
- Stamp accumulation on booking confirmation
- QR code generation (success and failure cases)
- QR code invalidation when new QR is generated
- QR code scanning and redemption
- QR code expiration handling
- QR code reuse prevention
- Race condition protection (concurrent scans)
- Legacy reward redemption endpoint
- Target achievement detection
- Integration with booking confirmation flow
- Error handling (insufficient stamps, invalid QR, authentication)

**Total: 130+ tests, all passing**

### Testing Booking Endpoints

The booking tests mock all TIMIFY API calls using `nock`. This ensures:
- Tests run without actual TIMIFY API access
- Tests are fast and reliable
- Error scenarios can be tested safely
- No external dependencies required

Key test scenarios:
- Successful reservation creation
- Reservation expiration handling (10-minute window)
- Used reservation prevention (double-confirmation blocked)
- TIMIFY API error handling (5xx, 4xx, network errors)
- Availability transformation correctness
- Booking confirmation with proper database updates
- Loyalty stamp integration on booking confirmation

### Testing Loyalty Endpoints

Loyalty tests verify:
- Stamp accumulation when bookings are confirmed
- QR code generation when eligible
- QR code generation failure when not eligible
- QR code invalidation when new QR is generated
- QR code scanning and redemption
- QR code expiration handling
- QR code reuse prevention
- Race condition protection (concurrent scans)
- Legacy reward redemption endpoint
- Integration with booking confirmation flow
- Error handling for insufficient stamps, invalid QR codes, authentication

## Loyalty Program

The backend includes a QR-code-based loyalty redemption system that rewards users with stamps for confirmed bookings.

### Security Features

- QR codes are single-use only (cannot be reused)
- QR codes expire after 2 minutes (configurable via `LOYALTY_QR_TTL_SECONDS`)
- QR scan endpoint does not leak user information
- Rate limited to prevent abuse (10 requests per minute)
- Previous QR codes are invalidated when a new one is generated

### How It Works

1. **Stamp Accumulation**: Each confirmed booking adds 1 stamp to the user's loyalty state
2. **Target**: Default target is 10 stamps (configurable via `LOYALTY_TARGET` env var)
3. **Eligibility**: When a user reaches the target, `eligibleForReward` becomes `true`
4. **QR Code Generation**: Eligible users can generate a QR code that expires in 2 minutes (configurable via `LOYALTY_QR_TTL_SECONDS`)
5. **Redemption**: QR codes are scanned at the salon to redeem the reward and reset stamps to 0
6. **Security**: QR codes are single-use, short-lived, and cryptographically secure

### Loyalty API Examples

#### Get Loyalty State
```bash
curl -X GET http://localhost:3000/api/v1/loyalty/me \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Response:
```json
{
  "data": {
    "stamps": 5,
    "target": 10,
    "eligibleForReward": false,
    "remaining": 5
  }
}
```

#### Generate QR Code (when eligible)
```bash
curl -X GET http://localhost:3000/api/v1/loyalty/qr \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Response (success):
```json
{
  "data": {
    "qrPayload": "LOYALTY:abc123def456...",
    "expiresAt": "2026-01-26T19:33:13.822Z"
  }
}
```

Response (error - not eligible):
```json
{
  "error": {
    "code": "LOYALTY_NOT_READY",
    "message": "Loyalty target not reached"
  }
}
```

**Note**: The mobile app converts `qrPayload` into a QR code image. The backend does not generate images.

#### Scan QR Code (Salon Side)
```bash
curl -X POST http://localhost:3000/api/v1/loyalty/scan \
  -H "Content-Type: application/json" \
  -d '{
    "qrPayload": "LOYALTY:abc123def456..."
  }'
```

Response (success):
```json
{
  "data": {
    "status": "redeemed",
    "resetStamps": true
  }
}
```

Response (error - invalid/expired):
```json
{
  "error": {
    "code": "INVALID_OR_EXPIRED_QR",
    "message": "QR code is invalid or expired"
  }
}
```

#### Redeem Reward (Legacy Endpoint)
```bash
curl -X POST http://localhost:3000/api/v1/loyalty/redeem \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Response (success):
```json
{
  "stamps": 0,
  "target": 10,
  "eligibleForReward": false,
  "remaining": 10
}
```

### Configuration

- `LOYALTY_TARGET`: Number of stamps required for a reward (default: `10`)
- `LOYALTY_QR_TTL_SECONDS`: QR code expiration time in seconds (default: `120` = 2 minutes)

### Security Features

- **QR Code Security**:
  - Tokens are 32-byte cryptographically secure random values
  - Only hashed tokens are stored in the database
  - QR codes expire after 2 minutes (configurable)
  - QR codes are single-use only
  - Previous QR codes are invalidated when a new one is generated

- **Rate Limiting**: The `/scan` endpoint is rate-limited to 10 requests per minute per IP

- **No User Data Leakage**: Scan endpoint does not reveal whether a token belonged to a real user

## Error Codes

All endpoints return consistent error codes:

### Authentication Errors
- `VALIDATION_ERROR`: Input validation failed
- `UNAUTHORIZED`: Missing or invalid authentication token
- `INVALID_CREDENTIALS`: Wrong email/phone or password
- `TOKEN_EXPIRED`: Access token has expired
- `TOKEN_INVALID`: Access token is invalid
- `REFRESH_TOKEN_INVALID`: Refresh token is invalid
- `REFRESH_TOKEN_EXPIRED`: Refresh token has expired
- `USER_ALREADY_EXISTS`: Email or phone number already registered

### Resource Errors
- `NOT_FOUND`: Resource not found
- `CONFLICT`: Resource conflict (e.g., duplicate user)
- `FORBIDDEN`: Access forbidden

### Admin Errors
- `ADMIN_FORBIDDEN`: Invalid or missing admin secret (admin endpoints)

### Booking Errors
- `BOOKING_SLOT_UNAVAILABLE`: Booking slot not available or already taken
- `BOOKING_PROVIDER_ERROR`: TIMIFY service temporarily unavailable
- `BOOKING_VALIDATION_ERROR`: Invalid booking request, reservation expired, or reservation already used
- `BOOKING_NOT_FOUND`: Booking not found
- `BOOKING_NOT_CANCELABLE`: Booking cannot be canceled (already canceled, past booking, or within cutoff time)
- `CANCEL_NOT_AVAILABLE`: Cancellation is not available (ENABLE_LOCAL_CANCEL=false)

### Offer Errors
- `OFFER_NOT_FOUND`: Offer not found

### Salon Errors
- `SALON_NOT_FOUND`: Salon not found

### Barber Errors
- `BARBER_NOT_FOUND`: Barber not found

### Loyalty Errors
- `LOYALTY_NOT_READY`: User has not reached the loyalty target yet
- `INVALID_OR_EXPIRED_QR`: QR code is invalid, expired, or already used

### Server Errors
- `INTERNAL_ERROR`: Internal server error
- `DATABASE_ERROR`: Database operation failed

## Complete API Reference

See `TESTING.md` for complete API reference with all endpoints, request/response examples, and error scenarios.

## Next Steps

The next backend feature to implement is **User Profile Management**, which will include:
- Update user profile (name, phone, email)
- Upload profile picture
- View booking history
- Manage user preferences

## License

ISC
