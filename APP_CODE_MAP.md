# BarberClub application map

Initial review and reference comparison: 18 October 2026. Release verification updated 1 November 2026.

Current delivery: app `1.4.6+14`, with fixes pushed to `main` and the backend successfully deployed on Railway. Verification passed 73 Flutter tests, 21 mocked backend tests, 24 live public content checks (three salons and 16 published barber profiles), 16 primary image URL checks and 15 post-deployment API checks. The signed AAB passed package/signature/ABI/16 KB alignment validation and the emulator runs an APK generated from the same release bundle. Live appointment writes remain excluded by the user.

The current HTML parser supports homepage links without `data-salon`, multiple current campaigns, hidden/expired offer handling and Paris-time countdowns. Network refresh is bounded and shared; delayed login responses cannot replace a newer customer state. Known published barber aliases connect website profiles and portraits to reservation names. Backend account-sync guards preserve one-to-one ownership and skip conflicting profile identities before password/profile writes.

## Data ownership

| Responsibility | Source | Implementation |
| --- | --- | --- |
| Published salons, team memberships, portraits, biographies, galleries, contact details, hours, history, FAQ | Public website HTML | `WebsiteCatalogRepository` + `WebsiteCatalogParser`; five-minute in-memory page cache, failed requests are evicted |
| Services, prices, bookable barbers, contracts/off-days, availability, bookings, cancellations, rescheduling, waitlist | `https://api.barberclub-grenoble.fr/api` | `ReservationRepositoryImpl` and the independent reservation session |
| App login, app profile/avatar, push registration, loyalty, rewards and admin access | Railway app API `/api/v1` | `DioClient`, app auth controller, loyalty providers |
| Published promotions and event signup configuration | Each website salon's offers page | `WebsiteOffersRepositoryImpl` + `WebsiteOffersPageParser` |
| Admin salon/service catalogue | Railway PostgreSQL/Prisma catalogue | `admin` routes, salon ACL and service queries; separate from public website content |

Public content IDs are website slugs, e.g. `voiron` and `voiron--jules`. They are never sent as Railway admin UUIDs or substituted for live reservation barber/service IDs. Booking from a published profile resolves the selected name against that salon's live reservation API team.

## Navigation and page sections

The five branches retain their state with `StatefulShellRoute.indexedStack`. Account and salon detail are separate routes. Admin accounts are redirected into their own shell.

| Route / feature | Screens and sections |
| --- | --- |
| `/home` | Brand hero, website/Instagram/account links, reserve CTA, same-size discovery panels for every published salon (city, subtitle and Découvrir CTA); Voiron's landing subtitle is explicitly “Barbershop premium à Voiron” as requested |
| `/salon/:id` | Salon image, introduction, address/Maps, telephone, published hours, live service prices, gallery, website history, expandable FAQ, social links, reserve-in-this-salon CTA |
| `/home/prestations/:salonId` | Salon service list, descriptions, durations, prices from the reservation API |
| `/coiffeurs` | One carousel per published salon, portrait cards, vertical page scrolling and horizontal team scrolling |
| `/coiffeurs/salon/:salonId` | Salon-specific barber grid, loading/empty/error/retry states |
| `/coiffeurs/salon/:salonId/barber/:id` | Portrait/optional hero video, published biography, photo/video haircut gallery, reserve-with-this-barber CTA |
| `/rdv` — salon choice | All published salons; no two-salon truncation |
| `/rdv` — commitments dialog | Punctuality, 12-hour cancellation policy, no-show terms, explicit acceptance |
| `/rdv` — barber step | Live bookable team plus “Peu importe”, website portraits, contract/work/off-date handling |
| `/rdv` — service step | Barber-specific services and category groups; live prices and custom/Saturday durations |
| `/rdv` — date step | Month availability, suggested dates, calendar navigation, slots, alternative barbers, waitlist preferences |
| `/rdv` — confirmation step | Booking summary, signed-in client or login/signup/password recovery forms, submission state and errors |
| `/rdv` — success | Confirmed appointment summary, practical salon information, next actions |
| `/compte` | Active `_CompteScreenShell`: welcome, visits/member/upcoming counters, “Mes RDV” and “Mon Profil” tabs |
| Account — appointments | All salons, next booking plus every later booking, per-booking cancellation/rescheduling, past history, book-again CTA |
| Account — rescheduling | Active V2 bottom sheet: calendar/month availability, slots, one-reschedule rule, confirmation |
| Account — profile | Avatar selection/crop/compression/upload, profile edit, password change, delete-account dialog, logout |
| `/carte-fidelite` | Guest sign-in gate; signed-in Private Club member card, rank preview, appointment progression, reward milestones, redemption confirmation, activity feed |
| `/offres` | Website offers for every published salon, current/upcoming or teaser cards, countdowns, event forms where published, gift card and conditions where published |
| `/offres/activation-qr` | Railway offer activation QR, polling for scan completion, cancel pending activation on exit |
| `/login` | Email/phone and password login, password visibility, signup/recovery links, redirect back to the requesting feature |
| `/signup` | Names, email, international phone, password/confirmation and validation; both app and reservation account synchronization |
| `/forgot-password` | Email request, neutral success feedback, navigate to reset screen |
| `/reset-password` | Email-bound OTP, password/confirmation, resend cooldown, success and return to login |
| `/admin` | Railway ACL-scoped salon selection, service selection, points shown before scanning |
| `/admin/scanner` | Delayed camera start, scan lock/cooldown, earn points for selected service, legacy coupon/voucher routing, feedback |
| `/admin/redeem` | Voucher QR validation, expiration/already-used feedback, reward/balance confirmation |
| `/admin/offer-scanner` | Offer activation QR validation and client/offer confirmation |
| `/admin/compte` | Admin identity/account information and logout |

`BarbersListScreen` and `PlaceholderScreen` exist but are not registered entry routes. `CompteScreen` contains an older unreachable layout after its active shell return, and the loyalty/RDV files retain several unused legacy widgets/demo branches. Those branches must not be mistaken for the active product.

## App infrastructure

- `main.dart` initializes Firebase, launch overlay, the router, session restore and push-event listeners. Reservation session bootstrap shares the in-flight refresh to prevent rotating-token races.
- `DioClient` adds only the Railway access token to Railway requests, serializes refresh attempts and handles authentication failure.
- Reservation authentication has its own access/refresh tokens and user profile. Account synchronization runs through the auth controller and backend website sync helpers.
- Secure storage keeps app tokens and reservation tokens separately. Cancellation tokens now have one secure key per appointment; older map entries migrate lazily.
- `BookingPolicy` evaluates the website's 12-hour change window in `Europe/Paris`, including daylight saving changes, independently of the phone timezone.
- Deep-link plumbing exists, but its current handler deliberately does not navigate password-reset links: password reset uses the in-app OTP flow.
- Firebase/local notifications drive reward/points/voucher success UI and refresh the relevant providers.
- Reusable widgets cover navigation, service rows, media galleries, QR overlays, loyalty modals, cards and theme/spacing constants.

## Backend map

- Express app: Helmet, CORS, payload parsing, public images, Swagger, `/health`, API routes and consistent error handling.
- Auth: registration/login, password hashes, access/rotating refresh tokens, profile/avatar updates, account deletion, password reset and website account synchronization.
- Public catalogue: salon/barber/prestation reads and admin catalogue creation through Prisma.
- Client offers: public windows, per-client activation states, QR activation/redemption and cancellation of pending activation.
- Loyalty: legacy stamps/coupons plus points accounts, rank-by-completed-appointments, reward catalogue, vouchers, transactions and hashed QR tokens.
- Admin: role/salon ACL checks, selected-service earning, reward/coupon scanning and offer validation.
- Jobs: user reconciliation, completed-website-booking rewards every ten minutes, expired flash-offer cleanup. Booking rewards use website booking IDs for idempotency and avoid duplicate multi-slot rewards.
- Operational scripts and migrations cover catalogue recovery, galleries, offers and loyalty repair. They require authenticated database access; they are not run against production as part of public content verification.

## Initial website comparison and remaining dependencies — 18 October snapshot

- Public site: Grenoble has 8 published team cards, Meylan 4, Voiron 5. Some people appear at multiple salons. Current bookable teams are 6, 4 and 5 respectively; the booking API, not the marketing list, determines available staff.
- Eddine and Benji have published portraits but no standalone biography/gallery link on their team cards. Voiron uses booking links for Clem/Ju/Jules/Gabriel; preserve the published information rather than inventing profile text.
- Jules and Gabriel use the website's `barber-soon` portrait. Their personal photos require publication by the client/site maintainer.
- Voiron lists 9h–19h and explicitly says opening days will be announced. The app displays that text and does not fabricate a weekly schedule.
- Website contact pages take precedence over older landing-page metadata (the Meylan phone number differs).
- Existing Railway public/admin catalogue still lacks Voiron. Public app discovery/booking now works through website sources, but enabling Voiron in the Railway staff scanner requires adding its salon/services and assigning admin access.
- No Railway CLI/login, Railway token, database URL, website database URL, or admin secret is configured in this checkout. Authenticated production admin updates require one of those supported access paths.
- Cancellation storage/request behavior is verified with isolated tests and mocked HTTP. The user explicitly excluded appointment testing; no live create/cancel/reschedule scenario was attempted, and live behavior remains unverified.
- Android emulator/debug build is the local delivery target. Release signing and store distribution require the production release workflow.

## Verification commands

From `barber/`:

```powershell
flutter test --no-pub --reporter expanded
dart run tool/audit_website.dart --check-media
flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings
flutter build apk --debug --no-pub --target-platform android-x64
```

The audit tool is read-only: it loads live content, checks image response types, and compares services and booking staff per salon. It does not create accounts, send alerts, book appointments, or modify loyalty data.

Initial verification result (18 October): 44 tests passed, including landing-page consistency at normal and enlarged text sizes; the public/media audit and Android x64 debug build passed. Current release verification is recorded above and in `barber/ANDROID_RELEASE.md`. Local Gradle currently reports a loopback-connection error during debug builds; the current emulator APK was generated directly from the verified release AAB. See `CLIENT_UPDATE_CHECKLIST.md` for current dependencies.
