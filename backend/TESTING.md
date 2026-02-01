# Testing Guide

## Setup

Before running tests, ensure:
1. Database is set up and migrations are run: `npm run prisma:migrate`
2. `.env` file is configured (or use `TEST_DATABASE_URL` for test database)
3. Dependencies are installed: `npm install`
4. Prisma client is generated: `npm run prisma:generate`

## Test Results Summary

When you run `npm test`, you should see:

```
Test Suites: 7 passed, 7 total
Tests:       119 passed, 119 total
```

### Test Breakdown

- **Authentication Tests**: 24 tests covering registration, login, token management, password reset, token revocation
- **Booking Tests**: 17 tests covering branches, services, availability, reservations, confirmations, user ownership validation
- **Bookings Management Tests**: 24 tests covering listing, details, cancellation, pagination, access control
- **Loyalty Tests**: 21 tests covering loyalty state, stamp accumulation, QR generation, QR scanning, reward redemption, QR security
- **Offers Tests**: 16 tests covering listing, filtering, pagination, details, error handling
- **Salons Tests**: 8 tests covering listing, sorting, details with barbers, error handling
- **Barbers Tests**: 11 tests covering listing, sorting, details with salons, error handling

All tests use `nock` to mock external API calls (TIMIFY), so no external dependencies are required. Tests run in isolation with database cleanup between runs.

**Note:** TIMIFY requests do not require authentication headers. The mocked TIMIFY requests in tests should not include Authorization headers or API keys, as the Booker Services endpoints are public.

## Running Tests

```bash
# Run all tests
npm test

# Run tests in watch mode
npm test:watch

# Run tests with coverage
npm test:coverage
```

## Manual API Testing

### Rate Limiting

**Note:** The API has rate limiting enabled on all endpoints with different limits based on sensitivity:

- **General endpoints**: 100 requests per 15 minutes
- **Auth endpoints** (login, register): 
  - Development: 50 requests per 15 minutes
  - Production: 5 requests per 15 minutes
- **Password reset**: 
  - Development: 10 requests per 15 minutes
  - Production: 3 requests per 15 minutes
- **Booking endpoints** (reserve, confirm):
  - Development: 30 requests per 15 minutes
  - Production: 10 requests per 15 minutes
- **QR scan endpoint**: 10 requests per minute
- **Public read endpoints** (offers, salons, barbers):
  - Development: 100 requests per minute
  - Production: 60 requests per minute

If you receive a `429 Too Many Requests` error, check the `X-RateLimit-Reset` header to see when the limit resets. In development, you can restart the server to reset counters.

### Using Postman or API Clients

**Important:** All POST requests require data to be sent in the **request body as JSON**, not as query parameters.

#### Setup for Postman/API Clients:

1. Set the request method to `POST` (or `GET` for `/me`)
2. Set the URL to: `http://localhost:3000/api/v1/auth/register` (or the appropriate endpoint)
3. Go to the **Headers** tab and add:
   - Key: `Content-Type`
   - Value: `application/json`
4. Go to the **Body** tab:
   - Select **raw**
   - Select **JSON** from the dropdown
   - Paste the JSON payload (see examples below)
5. **Do NOT** use the **Params** (Query Params) tab for POST requests

#### Common Mistake:
- **Wrong:** Sending data in Query Params tab
- **Correct:** Sending data in Body tab as raw JSON

### Using cURL

### 1. Register a new user

**Postman/API Client:**
- Method: `POST`
- URL: `http://localhost:3000/api/v1/auth/register`
- Headers: `Content-Type: application/json`
- Body (raw JSON):
```json
{
  "email": "test@example.com",
  "phoneNumber": "+1234567890",
  "password": "password123",
  "fullName": "Test User"
}
```

**cURL:**
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "phoneNumber": "+1234567890",
    "password": "password123",
    "fullName": "Test User"
  }'
```

Expected response (201):
```json
{
  "user": {
    "id": "uuid",
    "email": "test@example.com",
    "phoneNumber": "+1234567890",
    "fullName": "Test User",
    "createdAt": "2026-01-25T..."
  },
  "accessToken": "eyJhbGc...",
  "refreshToken": "eyJhbGc..."
}
```

### 2. Login with email

**Postman/API Client:**
- Method: `POST`
- URL: `http://localhost:3000/api/v1/auth/login`
- Headers: `Content-Type: application/json`
- Body (raw JSON):
```json
{
  "email": "test@example.com",
  "password": "password123"
}
```

**cURL:**
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

### 3. Login with phone number

**Postman/API Client:**
- Method: `POST`
- URL: `http://localhost:3000/api/v1/auth/login`
- Headers: `Content-Type: application/json`
- Body (raw JSON):
```json
{
  "phoneNumber": "+1234567890",
  "password": "password123"
}
```

**cURL:**
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "phoneNumber": "+1234567890",
    "password": "password123"
  }'
```

### 4. Get current user profile (requires access token)

Replace `YOUR_ACCESS_TOKEN` with the token from register/login:

**Postman/API Client:**
- Method: `GET`
- URL: `http://localhost:3000/api/v1/auth/me`
- Headers:
  - `Authorization: Bearer YOUR_ACCESS_TOKEN`

**cURL:**
```bash
curl -X GET http://localhost:3000/api/v1/auth/me \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Expected response (200):
```json
{
  "user": {
    "id": "uuid",
    "email": "test@example.com",
    "phoneNumber": "+1234567890",
    "fullName": "Test User",
    "isActive": true,
    "createdAt": "2026-01-25T...",
    "updatedAt": "2026-01-25T...",
    "lastLoginAt": "2026-01-25T..."
  }
}
```

### 5. Refresh access token

Replace `YOUR_REFRESH_TOKEN` with the refresh token from register/login:

**Postman/API Client:**
- Method: `POST`
- URL: `http://localhost:3000/api/v1/auth/refresh`
- Headers: `Content-Type: application/json`
- Body (raw JSON):
```json
{
  "refreshToken": "YOUR_REFRESH_TOKEN"
}
```

**cURL:**
```bash
curl -X POST http://localhost:3000/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{
    "refreshToken": "YOUR_REFRESH_TOKEN"
  }'
```

Expected response (200):
```json
{
  "accessToken": "eyJhbGc...",
  "refreshToken": "eyJhbGc..."
}
```

### 6. Forgot password

**Postman/API Client:**
- Method: `POST`
- URL: `http://localhost:3000/api/v1/auth/forgot-password`
- Headers: `Content-Type: application/json`
- Body (raw JSON):
```json
{
  "email": "test@example.com"
}
```

**cURL:**
```bash
curl -X POST http://localhost:3000/api/v1/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com"
  }'
```

Expected response (200):
```json
{
  "message": "Si l'adresse existe, un code a été envoyé."
}
```

**Note:** In development mode, check sent emails at `GET /api/v1/dev/emails`. The email contains a 6-digit code (e.g. "Voici votre code : 482193").

### 7. Reset password

Replace `CODE` with the 6-digit code from the reset email:

**Postman/API Client:**
- Method: `POST`
- URL: `http://localhost:3000/api/v1/auth/reset-password`
- Headers: `Content-Type: application/json`
- Body (raw JSON):
```json
{
  "email": "test@example.com",
  "code": "482193",
  "newPassword": "newpassword123"
}
```

**cURL:**
```bash
curl -X POST http://localhost:3000/api/v1/auth/reset-password \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "code": "482193",
    "newPassword": "newpassword123"
  }'
```

Expected response (200):
```json
{
  "message": "Password reset successfully"
}
```

**Note:** Code expires in 10 minutes. Max 5 failed attempts per code.

### 8. Logout

Replace `YOUR_REFRESH_TOKEN` with the refresh token:

**Postman/API Client:**
- Method: `POST`
- URL: `http://localhost:3000/api/v1/auth/logout`
- Headers: `Content-Type: application/json`
- Body (raw JSON):
```json
{
  "refreshToken": "YOUR_REFRESH_TOKEN"
}
```

**cURL:**
```bash
curl -X POST http://localhost:3000/api/v1/auth/logout \
  -H "Content-Type: application/json" \
  -d '{
    "refreshToken": "YOUR_REFRESH_TOKEN"
  }'
```

Expected response (200):
```json
{
  "message": "Logged out successfully"
}
```

## Booking Endpoints

### 9. Get list of branches

**Postman/API Client:**
- Method: `GET`
- URL: `http://localhost:3000/api/v1/booking/branches`

**cURL:**
```bash
curl http://localhost:3000/api/v1/booking/branches
```

Expected response (200):
```json
{
  "data": [
    {
      "id": "branch-id-1",
      "name": "Downtown Branch",
      "address": "123 Main St",
      "city": "New York",
      "country": "USA",
      "timezone": "America/New_York"
    }
  ]
}
```

### 10. Get services for a branch

Replace `BRANCH_ID` with an actual branch ID:

**Postman/API Client:**
- Method: `GET`
- URL: `http://localhost:3000/api/v1/booking/branches/BRANCH_ID/services`

**cURL:**
```bash
curl http://localhost:3000/api/v1/booking/branches/BRANCH_ID/services
```

Expected response (200):
```json
{
  "data": [
    {
      "id": "service-id-1",
      "name": "Haircut",
      "durationMinutes": 30,
      "price": 25.00
    }
  ]
}
```

### 11. Get availability

**Postman/API Client:**
- Method: `GET`
- URL: `http://localhost:3000/api/v1/booking/availability?branchId=BRANCH_ID&serviceId=SERVICE_ID&startDate=2026-02-01&endDate=2026-02-07`
- Optional query param: `resourceId=RESOURCE_ID`

**cURL:**
```bash
curl "http://localhost:3000/api/v1/booking/availability?branchId=BRANCH_ID&serviceId=SERVICE_ID&startDate=2026-02-01&endDate=2026-02-07"
```

With optional resourceId:
```bash
curl "http://localhost:3000/api/v1/booking/availability?branchId=BRANCH_ID&serviceId=SERVICE_ID&startDate=2026-02-01&endDate=2026-02-07&resourceId=RESOURCE_ID"
```

Expected response (200):
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

### 12. Reserve a booking slot (requires authentication)

Replace `YOUR_ACCESS_TOKEN` with a valid access token:

**Postman/API Client:**
- Method: `POST`
- URL: `http://localhost:3000/api/v1/booking/reserve`
- Headers:
  - `Authorization: Bearer YOUR_ACCESS_TOKEN`
  - `Content-Type: application/json`
- Body (raw JSON):
```json
{
  "branchId": "branch-id-1",
  "serviceId": "service-id-1",
  "date": "2026-02-01",
  "time": "10:00",
  "resourceId": "resource-id-1"
}
```

Note: `resourceId` is optional.

**cURL:**
```bash
curl -X POST http://localhost:3000/api/v1/booking/reserve \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "branchId": "branch-id-1",
    "serviceId": "service-id-1",
    "date": "2026-02-01",
    "time": "10:00",
    "resourceId": "resource-id-1"
  }'
```

Without resourceId:
```bash
curl -X POST http://localhost:3000/api/v1/booking/reserve \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "branchId": "branch-id-1",
    "serviceId": "service-id-1",
    "date": "2026-02-01",
    "time": "10:00"
  }'
```

Expected response (201):
```json
{
  "data": {
    "reservationId": "uuid",
    "expiresAt": "2026-02-01T10:10:00Z"
  }
}
```

### 13. Confirm a reservation (requires authentication)

Replace `YOUR_ACCESS_TOKEN` and `RESERVATION_ID` with actual values:

**Postman/API Client:**
- Method: `POST`
- URL: `http://localhost:3000/api/v1/booking/confirm`
- Headers:
  - `Authorization: Bearer YOUR_ACCESS_TOKEN`
  - `Content-Type: application/json`
- Body (raw JSON):
```json
{
  "reservationId": "RESERVATION_ID"
}
```

**cURL:**
```bash
curl -X POST http://localhost:3000/api/v1/booking/confirm \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "reservationId": "RESERVATION_ID"
  }'
```

Expected response (200):
```json
{
  "data": {
    "id": "uuid",
    "userId": "uuid",
    "branchId": "branch-id-1",
    "serviceId": "service-id-1",
    "resourceId": "resource-id-1",
    "startDateTime": "2026-02-01T10:00:00Z",
    "timifyAppointmentId": "timify-appointment-id",
    "status": "CONFIRMED",
    "createdAt": "2026-01-26T..."
  }
}
```

## Bookings Management Endpoints (Mes RDVs)

### 14. Get current user's bookings (requires authentication)

Replace `YOUR_ACCESS_TOKEN` with a valid access token:

**Postman/API Client:**
- Method: `GET`
- URL: `http://localhost:3000/api/v1/bookings/me?status=upcoming&limit=20`
- Headers:
  - `Authorization: Bearer YOUR_ACCESS_TOKEN`
- Query Parameters (optional):
  - `status`: `upcoming` (default), `past`, or `all`
  - `limit`: Number of results (1-50, default: 20)
  - `cursor`: Pagination cursor (format: `ISO_DATE|UUID`)

**cURL:**
```bash
curl -X GET "http://localhost:3000/api/v1/bookings/me?status=upcoming&limit=20" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

With pagination:
```bash
curl -X GET "http://localhost:3000/api/v1/bookings/me?status=upcoming&limit=20&cursor=2026-02-01T10:00:00Z|uuid" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Expected response (200):
```json
{
  "data": {
    "items": [
      {
        "id": "uuid",
        "startDateTime": "2026-02-01T10:00:00Z",
        "status": "CONFIRMED",
        "branch": {
          "id": "branch-id-1",
          "name": "Downtown Branch",
          "city": "New York"
        },
        "service": {
          "id": "service-id-1",
          "name": "Haircut"
        }
      }
    ],
    "nextCursor": "2026-02-01T10:00:00Z|uuid"
  }
}
```

### 15. Get booking details (requires authentication)

Replace `YOUR_ACCESS_TOKEN` and `BOOKING_ID` with valid values:

**Postman/API Client:**
- Method: `GET`
- URL: `http://localhost:3000/api/v1/bookings/BOOKING_ID`
- Headers:
  - `Authorization: Bearer YOUR_ACCESS_TOKEN`

**cURL:**
```bash
curl -X GET http://localhost:3000/api/v1/bookings/BOOKING_ID \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Expected response (200):
```json
{
  "data": {
    "id": "uuid",
    "startDateTime": "2026-02-01T10:00:00Z",
    "status": "CONFIRMED",
    "branch": {
      "id": "branch-id-1",
      "name": "Downtown Branch",
      "address": "123 Main St",
      "city": "New York",
      "timezone": "America/New_York"
    },
    "service": {
      "id": "service-id-1",
      "name": "Haircut",
      "durationMinutes": 30
    },
    "timifyAppointmentId": "timify-appt-123"
  }
}
```

Error response (403) if booking belongs to another user:
```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "Booking does not belong to user"
  }
}
```

Error response (404) if booking not found:
```json
{
  "error": {
    "code": "BOOKING_NOT_FOUND",
    "message": "Booking not found"
  }
}
```

### 16. Cancel a booking (requires authentication)

Replace `YOUR_ACCESS_TOKEN` and `BOOKING_ID` with valid values. Requires `ENABLE_LOCAL_CANCEL=true` in environment.

**Postman/API Client:**
- Method: `POST`
- URL: `http://localhost:3000/api/v1/bookings/BOOKING_ID/cancel`
- Headers:
  - `Authorization: Bearer YOUR_ACCESS_TOKEN`

**cURL:**
```bash
curl -X POST http://localhost:3000/api/v1/bookings/BOOKING_ID/cancel \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Expected response (200):
```json
{
  "data": {
    "status": "CANCELED"
  }
}
```

Error response (400) if cancellation not available:
```json
{
  "error": {
    "code": "CANCEL_NOT_AVAILABLE",
    "message": "Cancellation is not available"
  }
}
```

Error response (400) if booking cannot be canceled:
```json
{
  "error": {
    "code": "BOOKING_NOT_CANCELABLE",
    "message": "Booking cannot be canceled less than 60 minutes before start time"
  }
}
```

## Offers Endpoints

### 21. Get list of offers (public)

**Postman/API Client:**
- Method: `GET`
- URL: `http://localhost:3000/api/v1/offers?status=active&limit=20`
- Query Parameters (optional):
  - `status`: `active` (default) or `all`
  - `limit`: Number of results (1-50, default: 20)
  - `cursor`: Pagination cursor (format: `ISO_DATE|UUID`)

**cURL:**
```bash
curl -X GET "http://localhost:3000/api/v1/offers?status=active&limit=20"
```

With pagination:
```bash
curl -X GET "http://localhost:3000/api/v1/offers?status=active&limit=20&cursor=2026-01-26T20:00:00Z|uuid"
```

Expected response (200):
```json
{
  "data": {
    "items": [
      {
        "id": "uuid",
        "title": "Summer Special",
        "description": "Get 20% off on all services",
        "imageUrl": "https://example.com/offer.jpg",
        "validFrom": "2026-06-01T00:00:00Z",
        "validTo": "2026-08-31T23:59:59Z"
      }
    ],
    "nextCursor": "2026-01-26T20:00:00Z|uuid"
  }
}
```

### 22. Get offer details (public)

Replace `OFFER_ID` with a valid offer UUID:

**Postman/API Client:**
- Method: `GET`
- URL: `http://localhost:3000/api/v1/offers/OFFER_ID`

**cURL:**
```bash
curl -X GET http://localhost:3000/api/v1/offers/OFFER_ID
```

Expected response (200):
```json
{
  "data": {
    "id": "uuid",
    "title": "Summer Special",
    "description": "Get 20% off on all services",
    "imageUrl": "https://example.com/offer.jpg",
    "validFrom": "2026-06-01T00:00:00Z",
    "validTo": "2026-08-31T23:59:59Z"
  }
}
```

Error response (404) if offer not found:
```json
{
  "error": {
    "code": "OFFER_NOT_FOUND",
    "message": "Offer not found"
  }
}
```

Error response (400) for invalid offer ID format:
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "fields": {
      "id": "Invalid uuid"
    }
  }
}
```

## Loyalty Endpoints

### 23. Get current user's loyalty state (requires authentication)

Replace `YOUR_ACCESS_TOKEN` with a valid access token:

**Postman/API Client:**
- Method: `GET`
- URL: `http://localhost:3000/api/v1/loyalty/me`
- Headers:
  - `Authorization: Bearer YOUR_ACCESS_TOKEN`

**cURL:**
```bash
curl -X GET http://localhost:3000/api/v1/loyalty/me \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Expected response (200):
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

### 24. Generate QR code for loyalty redemption (requires authentication)

Replace `YOUR_ACCESS_TOKEN` with a valid access token. User must have stamps >= target.

**Postman/API Client:**
- Method: `GET`
- URL: `http://localhost:3000/api/v1/loyalty/qr`
- Headers:
  - `Authorization: Bearer YOUR_ACCESS_TOKEN`

**cURL:**
```bash
curl -X GET http://localhost:3000/api/v1/loyalty/qr \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Expected response (200):
```json
{
  "data": {
    "qrPayload": "LOYALTY:abc123def456...",
    "expiresAt": "2026-01-26T19:33:13.822Z"
  }
}
```

If not eligible (400):
```json
{
  "error": {
    "code": "LOYALTY_NOT_READY",
    "message": "Loyalty target not reached"
  }
}
```

**Note**: The mobile app converts `qrPayload` into a QR code image. The backend only provides the payload string.

### 25. Scan QR code (Salon side - no authentication required)

This endpoint is used by salon staff to scan and redeem QR codes.

**Postman/API Client:**
- Method: `POST`
- URL: `http://localhost:3000/api/v1/loyalty/scan`
- Headers: `Content-Type: application/json`
- Body (raw JSON):
```json
{
  "qrPayload": "LOYALTY:abc123def456..."
}
```

**cURL:**
```bash
curl -X POST http://localhost:3000/api/v1/loyalty/scan \
  -H "Content-Type: application/json" \
  -d '{
    "qrPayload": "LOYALTY:abc123def456..."
  }'
```

Expected response (200):
```json
{
  "data": {
    "status": "redeemed",
    "resetStamps": true
  }
}
```

If invalid/expired (400):
```json
{
  "error": {
    "code": "INVALID_OR_EXPIRED_QR",
    "message": "QR code is invalid or expired"
  }
}
```

**Note**: This endpoint is rate-limited to 10 requests per minute per IP.

### 26. Redeem loyalty reward (legacy endpoint, requires authentication)

Replace `YOUR_ACCESS_TOKEN` with a valid access token:

**Postman/API Client:**
- Method: `POST`
- URL: `http://localhost:3000/api/v1/loyalty/redeem`
- Headers:
  - `Authorization: Bearer YOUR_ACCESS_TOKEN`

**cURL:**
```bash
curl -X POST http://localhost:3000/api/v1/loyalty/redeem \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Expected response (200):
```json
{
  "stamps": 0,
  "target": 10,
  "eligibleForReward": false,
  "remaining": 10
}
```

If not enough stamps (400):
```json
{
  "error": {
    "code": "BOOKING_VALIDATION_ERROR",
    "message": "Not enough stamps to redeem reward"
  }
}
```

## Error Testing

### Invalid credentials

```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "wrongpassword"
  }'
```

Expected response (401):
```json
{
  "error": {
    "code": "INVALID_CREDENTIALS",
    "message": "Invalid email/phone or password"
  }
}
```

### Missing authorization header

```bash
curl -X GET http://localhost:3000/api/v1/auth/me
```

Expected response (401):
```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid authorization header"
  }
}
```

### Validation error

```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "invalid-email",
    "phoneNumber": "+1234567890",
    "password": "short"
  }'
```

Expected response (400):
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "fields": {
      "email": "Invalid email format",
      "password": "Password must be at least 8 characters"
    }
  }
}
```

## Development Endpoints

### View sent emails (development only)

In development/test mode, you can view all emails sent via the DevEmailProvider:

**Postman/API Client:**
- Method: `GET`
- URL: `http://localhost:3000/api/v1/dev/emails`

**cURL:**
```bash
curl http://localhost:3000/api/v1/dev/emails
```

Expected response (200):
```json
{
  "emails": [
    {
      "id": "uuid",
      "to": "test@example.com",
      "subject": "Reset Your Password",
      "html": "...",
      "text": "...",
      "sentAt": "2026-01-25T..."
    }
  ]
}
```

To extract the reset token from the email, look for the `token` parameter in the reset URL within the `html` or `text` field.

### Clear sent emails (development only)

**Postman/API Client:**
- Method: `DELETE`
- URL: `http://localhost:3000/api/v1/dev/emails`

**cURL:**
```bash
curl -X DELETE http://localhost:3000/api/v1/dev/emails
```

## Booking Error Scenarios

### Reservation Expired

If you try to confirm a reservation that has expired:

```bash
curl -X POST http://localhost:3000/api/v1/booking/confirm \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "reservationId": "EXPIRED_RESERVATION_ID"
  }'
```

Expected response (400):
```json
{
  "error": {
    "code": "BOOKING_VALIDATION_ERROR",
    "message": "Reservation expired"
  }
}
```

### Reservation Already Used

If you try to confirm a reservation that was already confirmed:

```bash
curl -X POST http://localhost:3000/api/v1/booking/confirm \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "reservationId": "ALREADY_USED_RESERVATION_ID"
  }'
```

Expected response (400):
```json
{
  "error": {
    "code": "BOOKING_VALIDATION_ERROR",
    "message": "Reservation already used"
  }
}
```

### Slot Not Available

If you try to reserve a slot that's already taken:

```bash
curl -X POST http://localhost:3000/api/v1/booking/reserve \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "branchId": "branch-id-1",
    "serviceId": "service-id-1",
    "date": "2026-02-01",
    "time": "10:00"
  }'
```

Expected response (409):
```json
{
  "error": {
    "code": "BOOKING_SLOT_UNAVAILABLE",
    "message": "Booking slot already taken"
  }
}
```

## Bookings Management Error Scenarios

### Booking Not Found

```bash
curl -X GET http://localhost:3000/api/v1/bookings/00000000-0000-0000-0000-000000000000 \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Expected response (404):
```json
{
  "error": {
    "code": "BOOKING_NOT_FOUND",
    "message": "Booking not found"
  }
}
```

### Access Forbidden (Booking Belongs to Another User)

```bash
curl -X GET http://localhost:3000/api/v1/bookings/OTHER_USER_BOOKING_ID \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Expected response (403):
```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "Booking does not belong to user"
  }
}
```

### Cancellation Not Available

```bash
curl -X POST http://localhost:3000/api/v1/bookings/BOOKING_ID/cancel \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Expected response (400) when `ENABLE_LOCAL_CANCEL=false`:
```json
{
  "error": {
    "code": "CANCEL_NOT_AVAILABLE",
    "message": "Cancellation is not available"
  }
}
```

### Booking Not Cancelable (Past Booking)

```bash
curl -X POST http://localhost:3000/api/v1/bookings/PAST_BOOKING_ID/cancel \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Expected response (400):
```json
{
  "error": {
    "code": "BOOKING_NOT_CANCELABLE",
    "message": "Cannot cancel past bookings"
  }
}
```

### Booking Not Cancelable (Within Cutoff Time)

```bash
curl -X POST http://localhost:3000/api/v1/bookings/NEAR_FUTURE_BOOKING_ID/cancel \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Expected response (400):
```json
{
  "error": {
    "code": "BOOKING_NOT_CANCELABLE",
    "message": "Booking cannot be canceled less than 60 minutes before start time"
  }
}
```

### Booking Already Canceled

```bash
curl -X POST http://localhost:3000/api/v1/bookings/CANCELED_BOOKING_ID/cancel \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Expected response (400):
```json
{
  "error": {
    "code": "BOOKING_NOT_CANCELABLE",
    "message": "Booking is already canceled"
  }
}
```

## Salons Error Scenarios

### Salon Not Found

```bash
curl -X GET http://localhost:3000/api/v1/salons/00000000-0000-0000-0000-000000000000
```

Expected response (404):
```json
{
  "error": {
    "code": "SALON_NOT_FOUND",
    "message": "Salon not found"
  }
}
```

### Invalid Salon ID Format

```bash
curl -X GET http://localhost:3000/api/v1/salons/invalid-id
```

Expected response (400):
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "fields": {
      "id": "Invalid uuid"
    }
  }
}
```

## Barbers Error Scenarios

### Barber Not Found

```bash
curl -X GET http://localhost:3000/api/v1/barbers/00000000-0000-0000-0000-000000000000
```

Expected response (404):
```json
{
  "error": {
    "code": "BARBER_NOT_FOUND",
    "message": "Barber not found"
  }
}
```

### Invalid Barber ID Format

```bash
curl -X GET http://localhost:3000/api/v1/barbers/invalid-id
```

Expected response (400):
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "fields": {
      "id": "Invalid uuid"
    }
  }
}
```

## Offers Error Scenarios

### Offer Not Found

```bash
curl -X GET http://localhost:3000/api/v1/offers/00000000-0000-0000-0000-000000000000
```

Expected response (404):
```json
{
  "error": {
    "code": "OFFER_NOT_FOUND",
    "message": "Offer not found"
  }
}
```

### Invalid Offer ID Format

```bash
curl -X GET http://localhost:3000/api/v1/offers/invalid-id
```

Expected response (400):
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "fields": {
      "id": "Invalid uuid"
    }
  }
}
```

### Invalid Limit Parameter

```bash
curl -X GET "http://localhost:3000/api/v1/offers?limit=100"
```

Expected response (400):
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "fields": {
      "limit": "Number must be less than or equal to 50"
    }
  }
}
```

## Loyalty Error Scenarios

### Not Enough Stamps to Redeem

```bash
curl -X POST http://localhost:3000/api/v1/loyalty/redeem \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Expected response (400):
```json
{
  "error": {
    "code": "BOOKING_VALIDATION_ERROR",
    "message": "Not enough stamps to redeem reward"
  }
}
```

### QR Code Not Ready (Stamps < Target)

```bash
curl -X GET http://localhost:3000/api/v1/loyalty/qr \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Expected response (400):
```json
{
  "error": {
    "code": "LOYALTY_NOT_READY",
    "message": "Loyalty target not reached"
  }
}
```

### Invalid QR Code Format

```bash
curl -X POST http://localhost:3000/api/v1/loyalty/scan \
  -H "Content-Type: application/json" \
  -d '{
    "qrPayload": "INVALID:token"
  }'
```

Expected response (400):
```json
{
  "error": {
    "code": "INVALID_OR_EXPIRED_QR",
    "message": "QR code is invalid or expired"
  }
}
```

### Expired QR Code

If you try to scan a QR code that has expired (default: 2 minutes):

```bash
curl -X POST http://localhost:3000/api/v1/loyalty/scan \
  -H "Content-Type: application/json" \
  -d '{
    "qrPayload": "LOYALTY:expired-token"
  }'
```

Expected response (400):
```json
{
  "error": {
    "code": "INVALID_OR_EXPIRED_QR",
    "message": "QR code is invalid or expired"
  }
}
```

### Reused QR Code

If you try to scan the same QR code twice:

```bash
# First scan (success)
curl -X POST http://localhost:3000/api/v1/loyalty/scan \
  -H "Content-Type: application/json" \
  -d '{
    "qrPayload": "LOYALTY:valid-token"
  }'

# Second scan (fails)
curl -X POST http://localhost:3000/api/v1/loyalty/scan \
  -H "Content-Type: application/json" \
  -d '{
    "qrPayload": "LOYALTY:valid-token"
  }'
```

Expected response (400):
```json
{
  "error": {
    "code": "INVALID_OR_EXPIRED_QR",
    "message": "QR code is invalid or expired"
  }
}
```

## Health Check

```bash
curl http://localhost:3000/health
```

Expected response (200):
```json
{
  "status": "ok",
  "timestamp": "2026-01-26T..."
}
```

## Complete Test Flow Example

Here's a complete end-to-end test flow:

### Step 1: Register a User
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "phoneNumber": "+1234567890",
    "password": "password123",
    "fullName": "Test User"
  }'
```

Save the `accessToken` from the response.

### Step 2: Get Branches
```bash
curl http://localhost:3000/api/v1/booking/branches
```

### Step 3: Get Services
```bash
curl http://localhost:3000/api/v1/booking/branches/BRANCH_ID/services
```

### Step 4: Check Availability
```bash
curl "http://localhost:3000/api/v1/booking/availability?branchId=BRANCH_ID&serviceId=SERVICE_ID&startDate=2026-02-01&endDate=2026-02-07"
```

### Step 5: Reserve a Slot
```bash
curl -X POST http://localhost:3000/api/v1/booking/reserve \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "branchId": "BRANCH_ID",
    "serviceId": "SERVICE_ID",
    "date": "2026-02-01",
    "time": "10:00"
  }'
```

Save the `reservationId` from the response.

### Step 6: Confirm Reservation
```bash
curl -X POST http://localhost:3000/api/v1/booking/confirm \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "reservationId": "RESERVATION_ID"
  }'
```

### Step 7: Check Loyalty Status
```bash
curl -X GET http://localhost:3000/api/v1/loyalty/me \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

You should see 1 stamp added after confirming the booking.

### Step 8: Generate QR Code (when eligible - stamps >= target)
```bash
curl -X GET http://localhost:3000/api/v1/loyalty/qr \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Save the `qrPayload` from the response.

### Step 9: Scan QR Code (Salon Side)
```bash
curl -X POST http://localhost:3000/api/v1/loyalty/scan \
  -H "Content-Type: application/json" \
  -d '{
    "qrPayload": "LOYALTY:token-from-step-8"
  }'
```

This will redeem the reward and reset stamps to 0.

### Step 10: Verify Stamps Reset
```bash
curl -X GET http://localhost:3000/api/v1/loyalty/me \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Stamps should now be 0.

## Test Coverage Summary

The test suite includes comprehensive coverage:

### Authentication Tests (24 tests)
- User registration with validation
- Login with email and phone
- Token refresh and rotation
- Logout and token revocation
- Password reset flow
- Protected endpoint access
- Error handling for all scenarios

### Booking Tests (17 tests)
- Branch listing and filtering
- Service retrieval
- Availability transformation
- Reservation creation and expiration
- Booking confirmation
- Error handling (expired, used, unavailable slots)
- TIMIFY API mocking

### Loyalty Tests (21 tests)
- Loyalty state retrieval (with eligibleForReward field)
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

**Total: 119 tests, all passing**
