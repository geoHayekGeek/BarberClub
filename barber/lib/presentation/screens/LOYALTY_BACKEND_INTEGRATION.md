# Carte Fidélité — Backend Integration Guide

This document describes what you need to know when connecting the loyalty card feature to the backend.

---

## 1. Data Model (`lib/domain/models/loyalty_card_data.dart`)

**Current state:** Plain Dart class used as a frontend placeholder.

**Fields (must match API):**

| Field | Type | Example |
|-------|------|---------|
| `firstName` | String | `"Jean"` |
| `lastName` | String | `"Dupont"` |
| `memberSince` | DateTime | `2024-01-15` |
| `currentVisits` | int | `4` |
| `totalRequiredVisits` | int | `10` |
| `rewardLabel` | String | `"1 coupe offerte"` |

**Integration steps:**
- Add `factory LoyaltyCardData.fromJson(Map<String, dynamic> json)` when the API contract is known.
- Or replace the class with a freezed/DTO model generated from the API schema.
- Keep the same field names and types so `LoyaltyCardWidget` and `LoyaltyProgressBar` stay unchanged.

---

## 2. Provider (`lib/presentation/providers/loyalty_providers.dart`)

**Current state:** `loyaltyCardProvider` returns dummy data when the user is authenticated. No API call.

**Integration steps:**
1. Create `LoyaltyRepository` (interface + implementation) in `domain/repositories/` and `data/repositories/`.
2. Add a method such as `Future<LoyaltyCardData> getLoyaltyCard()` that calls the backend.
3. In `loyaltyCardProvider`, replace the dummy fetch with:

   ```dart
   final repository = ref.watch(loyaltyRepositoryProvider);
   return repository.getLoyaltyCard();
   ```

4. Keep the auth check: return `null` when `authState.status != AuthStatus.authenticated` so the login prompt still appears for unauthenticated users.
5. Handle errors (401, 404, network) and surface them appropriately in the UI.

---

## 3. QR Code Integration (`lib/presentation/screens/loyalty_card_screen.dart`)

**Current state:** No QR logic. A TODO comment marks where it will go.

**Integration steps:**
1. Backend must provide a QR payload (e.g. token or URL) for the user's loyalty card.
2. Add that field to `LoyaltyCardData` (e.g. `String? qrPayload`).
3. Add a QR display section below the card in `LoyaltyCardWidget` (or a dedicated widget) when `qrPayload != null`.
4. Do not implement scan/validation logic in the app until the backend API for that is defined.

---

## 4. API Endpoint Expectations

When implementing the repository, you will likely need:

| Method | Endpoint (example) | Auth |
|--------|--------------------|------|
| GET | `/api/v1/loyalty/card` | Bearer token required |

**Response shape (expected):**

```json
{
  "firstName": "Jean",
  "lastName": "Dupont",
  "memberSince": "2024-01-15",
  "currentVisits": 4,
  "totalRequiredVisits": 10,
  "rewardLabel": "1 coupe offerte"
}
```

Field names may differ (e.g. `member_since`). Map them in `fromJson` accordingly.

---

## 5. Widgets (no changes needed)

- **`LoyaltyCardWidget`** — Reads `LoyaltyCardData` only. No business logic. No changes if the model shape stays the same.
- **`LoyaltyProgressBar`** — Uses `currentVisits` and `totalRequiredVisits`. Configurable. No changes unless you add new visuals.
- **`loyalty_ui_constants.dart`** — French strings and design tokens. Update strings here if copy changes.

---

## 6. Auth Flow

- Unauthenticated → `loyaltyCardProvider` returns `null` → screen shows "Connectez-vous pour accéder à votre carte fidélité" and "Se connecter" button.
- Authenticated → provider fetches from API → screen shows the card (or loading/error).
- `authStateProvider` is already used; no changes needed for auth wiring.

---

## 7. Checklist for Backend Integration

- [ ] Define API contract (endpoint, request/response, auth).
- [ ] Create `LoyaltyRepository` and wire it to `loyaltyCardProvider`.
- [ ] Add `fromJson` to `LoyaltyCardData` (or replace with generated model).
- [ ] Handle loading, error, and empty states in `LoyaltyCardScreen`.
- [ ] Add QR payload to model and display QR when provided by backend.
- [ ] Test with real tokens and backend responses.
