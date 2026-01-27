# Admin Endpoints Documentation

## Overview

The admin endpoints provide write access to create salons, barbers, and offers. **These endpoints are NOT for mobile app usage.** They exist only for manual administration via tools like Postman, curl, or custom scripts.

## Authentication

Admin endpoints use a shared secret authentication mechanism. The `adminSecret` must be sent in the request body and must match the `ADMIN_SECRET` environment variable.

### Setting ADMIN_SECRET

1. Add `ADMIN_SECRET` to your `.env` file:
   ```
   ADMIN_SECRET=your-strong-secret-here-minimum-32-characters
   ```

2. In production, `ADMIN_SECRET` is **required** and must be:
   - At least 32 characters long
   - Changed from the default value (`change-me-in-production`)
   - A strong, randomly generated string

3. The secret is validated at application startup. If invalid in production, the application will not start.

### Security Rules

- **Never log `adminSecret`**: The middleware removes it from the request body before processing
- **Never return `adminSecret`**: It is stripped from all responses
- **Never store `adminSecret` in the database**: It exists only as an environment variable
- **Keep the secret private**: Only share with trusted administrators
- **Rotate if leaked**: If the secret is compromised, generate a new one immediately
- **Do not expose to frontend**: These endpoints should never be called from client-side code

## Rate Limiting

Admin endpoints are aggressively rate limited:
- **Production**: 5 requests per 15 minutes per IP
- **Development**: 20 requests per 15 minutes per IP

## Endpoints

### Create Salon

**POST** `/api/v1/admin/salons`

Creates a new salon.

**Request Body:**
```json
{
  "adminSecret": "your-admin-secret",
  "name": "Salon Name",
  "city": "Paris",
  "address": "123 Main Street",
  "description": "A modern barber salon in the heart of the city",
  "openingHours": "Mon-Fri 9:00-18:00, Sat 10:00-16:00",
  "images": [
    "https://example.com/salon1.jpg",
    "https://example.com/salon2.jpg"
  ],
  "isActive": true
}
```

**Required Fields:**
- `adminSecret` (string): Admin authentication secret
- `name` (string): Salon name (min 1 character)
- `city` (string): City name (min 1 character)
- `address` (string): Street address (min 1 character)
- `description` (string): Salon description (min 1 character)
- `openingHours` (string): Opening hours description (min 1 character)

**Optional Fields:**
- `images` (string[]): Array of image URLs (default: `[]`)
- `isActive` (boolean): Whether the salon is active (default: `true`)

**Response:**
- **201 Created**: Salon created successfully
  ```json
  {
    "data": {
      "id": "uuid",
      "name": "Salon Name",
      "city": "Paris",
      "address": "123 Main Street",
      "description": "A modern barber salon...",
      "openingHours": "Mon-Fri 9:00-18:00...",
      "images": ["https://example.com/salon1.jpg"]
    }
  }
  ```

- **400 Bad Request**: Validation error
- **403 Forbidden**: Invalid admin secret

**cURL Example:**
```bash
curl -X POST http://localhost:3000/api/v1/admin/salons \
  -H "Content-Type: application/json" \
  -d '{
    "adminSecret": "your-admin-secret",
    "name": "Salon Name",
    "city": "Paris",
    "address": "123 Main Street",
    "description": "A modern barber salon",
    "openingHours": "Mon-Fri 9:00-18:00",
    "images": ["https://example.com/salon1.jpg"],
    "isActive": true
  }'
```

### Create Barber

**POST** `/api/v1/admin/barbers`

Creates a new barber and associates them with one or more salons.

**Request Body:**
```json
{
  "adminSecret": "your-admin-secret",
  "firstName": "John",
  "lastName": "Doe",
  "bio": "Experienced barber with 10 years of expertise in modern haircuts",
  "experienceYears": 10,
  "interests": ["Haircuts", "Beards", "Styling"],
  "images": [
    "https://example.com/barber1.jpg"
  ],
  "salonIds": [
    "uuid-of-salon-1",
    "uuid-of-salon-2"
  ],
  "isActive": true
}
```

**Required Fields:**
- `adminSecret` (string): Admin authentication secret
- `firstName` (string): Barber's first name (min 1 character)
- `lastName` (string): Barber's last name (min 1 character)
- `bio` (string): Barber biography (min 1 character)
- `salonIds` (string[]): Array of salon UUIDs (min 1 salon, all must exist)

**Optional Fields:**
- `experienceYears` (number | null): Years of experience (default: `null`)
- `interests` (string[]): Array of interest tags (default: `[]`)
- `images` (string[]): Array of image URLs (default: `[]`)
- `isActive` (boolean): Whether the barber is active (default: `true`)

**Response:**
- **201 Created**: Barber created successfully
  ```json
  {
    "data": {
      "id": "uuid",
      "firstName": "John",
      "lastName": "Doe",
      "bio": "Experienced barber...",
      "experienceYears": 10,
      "interests": ["Haircuts", "Beards", "Styling"],
      "images": ["https://example.com/barber1.jpg"],
      "salons": [
        {
          "id": "uuid-of-salon-1",
          "name": "Salon Name",
          "city": "Paris"
        }
      ]
    }
  }
  ```

- **400 Bad Request**: Validation error (e.g., salon IDs don't exist)
- **403 Forbidden**: Invalid admin secret

**cURL Example:**
```bash
curl -X POST http://localhost:3000/api/v1/admin/barbers \
  -H "Content-Type: application/json" \
  -d '{
    "adminSecret": "your-admin-secret",
    "firstName": "John",
    "lastName": "Doe",
    "bio": "Experienced barber",
    "experienceYears": 10,
    "interests": ["Haircuts", "Beards"],
    "images": ["https://example.com/barber1.jpg"],
    "salonIds": ["uuid-of-salon-1"],
    "isActive": true
  }'
```

### Create Offer

**POST** `/api/v1/admin/offers`

Creates a new promotional offer.

**Request Body:**
```json
{
  "adminSecret": "your-admin-secret",
  "title": "Summer Special",
  "description": "Get 20% off on all haircuts this summer",
  "imageUrl": "https://example.com/offer.jpg",
  "validFrom": "2026-06-01T00:00:00Z",
  "validTo": "2026-08-31T23:59:59Z",
  "isActive": true
}
```

**Required Fields:**
- `adminSecret` (string): Admin authentication secret
- `title` (string): Offer title (min 1 character)
- `description` (string): Offer description (min 1 character)

**Optional Fields:**
- `imageUrl` (string | null): URL to offer image (default: `null`)
- `validFrom` (string | null): ISO 8601 datetime when offer becomes valid (default: `null`)
- `validTo` (string | null): ISO 8601 datetime when offer expires (default: `null`)
- `isActive` (boolean): Whether the offer is active (default: `true`)

**Validation Rules:**
- If both `validFrom` and `validTo` are provided, `validFrom` must be less than or equal to `validTo`
- Date strings must be valid ISO 8601 format

**Response:**
- **201 Created**: Offer created successfully
  ```json
  {
    "data": {
      "id": "uuid",
      "title": "Summer Special",
      "description": "Get 20% off on all haircuts this summer",
      "imageUrl": "https://example.com/offer.jpg",
      "validFrom": "2026-06-01T00:00:00.000Z",
      "validTo": "2026-08-31T23:59:59.000Z"
    }
  }
  ```

- **400 Bad Request**: Validation error (e.g., invalid date range)
- **403 Forbidden**: Invalid admin secret

**cURL Example:**
```bash
curl -X POST http://localhost:3000/api/v1/admin/offers \
  -H "Content-Type: application/json" \
  -d '{
    "adminSecret": "your-admin-secret",
    "title": "Summer Special",
    "description": "Get 20% off on all haircuts this summer",
    "imageUrl": "https://example.com/offer.jpg",
    "validFrom": "2026-06-01T00:00:00Z",
    "validTo": "2026-08-31T23:59:59Z",
    "isActive": true
  }'
```

## Error Responses

All errors follow this format:

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

### Common Error Codes

- `ADMIN_FORBIDDEN` (403): Invalid or missing admin secret
- `VALIDATION_ERROR` (400): Request validation failed
- `RATE_LIMIT_EXCEEDED` (429): Too many requests

## Security Best Practices

1. **Generate a Strong Secret**: Use a cryptographically secure random string generator
   ```bash
   # Example: Generate a 64-character random string
   openssl rand -hex 32
   ```

2. **Store Securely**: Keep `ADMIN_SECRET` in environment variables, never in code or version control

3. **Rotate Regularly**: Change the secret periodically or immediately if compromised

4. **Use HTTPS**: Always use HTTPS in production to protect the secret in transit

5. **Limit Access**: Only trusted administrators should have access to the secret

6. **Monitor Usage**: Monitor admin endpoint usage for suspicious activity

7. **Never Expose to Frontend**: These endpoints should only be called from server-side scripts or trusted tools

## Troubleshooting

### Application Won't Start in Production

If the application fails to start with an error about `ADMIN_SECRET`:
- Ensure `ADMIN_SECRET` is set in your environment
- Ensure it's at least 32 characters long
- Ensure it's not the default value `change-me-in-production`

### 403 Forbidden Errors

- Verify `ADMIN_SECRET` in your `.env` file matches what you're sending in requests
- Ensure you're sending `adminSecret` in the request body (not headers or query params)
- Check that the secret hasn't been changed or rotated

### Validation Errors

- Check that all required fields are present
- Verify field types match the schema (strings, numbers, arrays, etc.)
- For barbers, ensure all `salonIds` exist in the database
- For offers, ensure `validFrom <= validTo` if both dates are provided
