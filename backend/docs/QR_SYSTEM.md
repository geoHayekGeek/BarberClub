# QR Code System Documentation

## QR Payload Format (v1)

All QR codes follow a standardized pipe-separated format:

```
BC|v1|<type>|<token>
```

**Components:**
- `BC`: Fixed prefix (Barber Club)
- `v1`: Protocol version
- `<type>`: Either `P` (loyalty point) or `C` (coupon)
- `<token>`: 64-character hex token (URL-safe, no special chars)

**Examples:**
```
BC|v1|P|a1b2c3d4e5f6...  (loyalty point increment)
BC|v1|C|9f8e7d6c5b4a...  (free haircut coupon)
```

## Security

- Tokens are generated using `crypto.randomBytes(32).toString('hex')`
- Stored as SHA-256 hash with server-side pepper (`QR_TOKEN_PEPPER`)
- Tokens expire after `LOYALTY_QR_TTL_SECONDS` (default: 120s)
- Single-use only
- Never log raw tokens in production

## Backend Endpoints

### User Endpoints

**Generate loyalty point QR**
```bash
POST /api/v1/loyalty/qr
Authorization: Bearer <user-token>

Response:
{
  "data": {
    "qrPayload": "BC|v1|P|<token>",
    "expiresAt": "2024-03-15T14:30:00.000Z"
  }
}
```

**Generate coupon QR**
```bash
POST /api/v1/loyalty/coupons/:id/qr
Authorization: Bearer <user-token>

Response:
{
  "data": {
    "qrPayload": "BC|v1|C|<token>",
    "expiresAt": "2024-03-15T14:30:00.000Z"
  }
}
```

### Admin Endpoints

**Scan loyalty point QR**
```bash
POST /api/v1/admin/loyalty/scan
Authorization: Bearer <admin-token>
Content-Type: application/json

{
  "qrPayload": "BC|v1|P|<token>"
}

Response:
{
  "data": {
    "success": true,
    "rewardEarned": false
  }
}
```

**Redeem coupon QR**
```bash
POST /api/v1/admin/loyalty/redeem
Authorization: Bearer <admin-token>
Content-Type: application/json

{
  "qrPayload": "BC|v1|C|<token>"
}

Response:
{
  "data": {
    "success": true
  }
}
```

## Rate Limiting

Admin scan endpoint is rate-limited to 1 request per 5 seconds per IP to prevent spam.

## Error Handling

All invalid QR scenarios return the same generic error for security:
```json
{
  "error": {
    "code": "INVALID_OR_EXPIRED_QR",
    "message": "QR code invalide"
  }
}
```

This applies to:
- Invalid format
- Token not found
- Token expired
- Token already used
- Coupon already redeemed

## Environment Variables

Required for QR system:

```bash
# Loyalty settings
LOYALTY_TARGET=10                    # Points required for reward
LOYALTY_QR_TTL_SECONDS=120          # QR token expiration (2 minutes)

# Security
QR_TOKEN_PEPPER=<min-32-chars>      # Server-side pepper for token hashing
```

## Testing

Run QR utility tests:
```bash
cd backend
npm test -- qr.test.ts
```

## Flutter Integration

### Display QR Code

QR codes are displayed at 300x300 logical pixels with:
- High error correction level (H)
- White background (high contrast)
- 8px padding for quiet zone
- Expiration time shown to user

### Scanner Integration

Admin scanner:
- Reads raw QR string
- Trims whitespace only
- Detects type from payload prefix
- Routes to correct endpoint
- Shows appropriate success message
- 5-second cooldown between scans
