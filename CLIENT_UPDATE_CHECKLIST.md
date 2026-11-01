# Website alignment and client requests

Reference: https://barberclub-grenoble.fr/ (initial review 18 October 2026; release verification updated 1 November 2026).
Website content and the website reservation API are authoritative. Do not invent photos, biographies, prices, availability, or opening days.

## Implementation checklist

- [x] Map app routes, active screen sections, data providers, and backend responsibilities in `APP_CODE_MAP.md`.
- [x] Import current website salon content, contact information, opening hours, images, and galleries, including Voiron.
- [x] Import website barber profiles and current portraits (Louay, Durel, Eddine, Lucas, Ju, and the rest of the published team).
- [x] Show Voiron and its website team throughout salon discovery, barber discovery, offers/prices, and booking.
- [x] Use the same full-width landing panel for all salons: city name, subtitle, typography and Découvrir button. Voiron is no longer a separate name/address preview card; its landing subtitle is “Barbershop premium à Voiron” as explicitly requested, while website opening information is preserved elsewhere.
- [x] Remove the two-salon restriction in booking and handle any published salon.
- [x] Fix barber-selection scrolling; regression tests cover 320x568 phones at normal and 150% text size.
- [x] Fix per-appointment cancellation token storage/recovery, list appointments across all salons, and evaluate the 12-hour policy in Paris time. Isolated regression tests passed; live appointment changes are explicitly excluded by the user.
- [x] Compare website prices/services and booking teams per salon against the live reservation API (read-only).
- [x] Run automated tests and the read-only website/media audit. Build Android and verify the public screens in the emulator.
- [x] Record deployment requirements and remaining client content gaps below.

## Confirmed findings

- Railway public catalogue currently contains only Grenoble and Meylan, with seven older profiles. The website publishes three salons and additional barbers.
- The RDV salon picker truncates its source to two salons; its split-panel widget also only renders two.
- Barber discovery hardcodes only two salon buckets and sends unknown salons into Grenoble.
- Reservations use https://api.barberclub-grenoble.fr/api independently of Railway app authentication/loyalty.
- Website team pages and reservation availability deliberately differ (e.g. not every displayed team member currently accepts bookings at every salon). Use the reservation API's own barber IDs and availability for actual bookings.
- Jules and Gabriel have no published personal portrait: the website uses its own `barber-soon` image. Retain that placeholder until real portraits are published.
- The client message warns that early Voiron storefront visuals may be AI illustrations. Use the website's published assets; do not describe them as verified real photography or publish them to Google.

## Delivery status

Implemented and pushed to `main` in `742dbc5` and `05d498a`. Railway's deployment checks succeeded and the final health endpoint returned HTTP 200/status `ok`. Public editorial content comes directly from website pages with a five-minute in-memory cache. Booking IDs, services and availability still come from the website reservation API; Railway still owns app accounts, loyalty and staff administration.

Current app release: signed `1.4.6+14`. Homepage discovery, current/multiple offer parsing and compact-screen offers layouts are fixed. Authentication retries are bounded, stale login responses are ignored, rejected registration cannot delete a previously signed-in account, and known barber aliases preserve profile-to-booking selection and updated portraits. Backend sync now rejects conflicting ownership/identities before profile/password updates; repeated loyalty reads/skips are cached/summarized without changing enrollment rules.

Cancellation diagnosis: concurrent hydration previously rewrote one shared cancellation-token map, losing entries. Tokens now use independent secure-storage keys, older entries migrate lazily, and missing credentials are recovered for the exact selected booking. Cancellation requests include the reservation session. Account history no longer hides bookings at other salons.

### Verification

- Current release: 73 Flutter tests, 21 mocked backend unit tests, backend TypeScript build and focused Dart analysis passed. Live checks passed for 24 content loads, 16 primary images and 15 deployed API/login reads. Full analysis has no errors and 483 existing non-error findings. The signed AAB passed signature/package/SDK/ABI/static 16 KB alignment checks. Pixel 8 now runs an APK generated from that release bundle; no appointment write was performed.
- The following counts and debug-build observations describe the initial 18 October verification, retained for history.
- 44 Flutter tests passed, including concurrent token writes/restarts, legacy token migration, exact-booking cancellation recovery using mocked HTTP, Paris/DST cutoff, website parsing, Voiron offer expiry, missing event-configuration handling, compact-screen scrolling, profile-to-booking selection and consistent landing panels at normal/enlarged text sizes.
- Read-only live audit checked all three salons, 17 published team cards, profile content, service prices and image response types. Bookable team sizes were Grenoble 6, Meylan 4 and Voiron 5; published team sizes were 8, 4 and 5.
- Android debug APK builds successfully for the x64 emulator. Emulator review includes the updated home hero, website portraits, vertical team scrolling, Voiron discovery/offers and reaching Voiron's live booking team without submitting a booking.
- The earlier full-project analyzer run reported no errors and 504 non-error lint/warning findings. A wider legacy-code cleanup is outside this change.
- No customer appointments, personal data, loyalty balances or production schemas were modified. No live bookings, cancellations, rescheduling or waitlist submissions were attempted.

### Pending / required input

- **Optional legacy staff support, not a customer-release blocker:** the Railway catalogue still has only Grenoble and Meylan. The staff scanner remains routed for ADMIN users, but current customer booking and automatic booking-based loyalty do not depend on its salon/services catalogue. With staff scanning retired from the business workflow, Voiron staff setup is out of scope. Removing those still-wired routes/screens would be separate cleanup.
- **Unpublished client photos:** Jules and Gabriel still use the website's official placeholder. Real personal portraits and verified new Voiron photography must be supplied/published by the client or website maintainer; no substitute photos were invented.
- **Live appointment verification:** deliberately not performed because the user said appointments cannot be tested. The cancellation correction is regression-tested in isolation, not proven against real bookings.
- **Production delivery:** Android `1.4.6+14` is signed and validated using the replacement upload key that Play previously accepted for version 11. The current Play upload/review session is in progress; publication must be verified in Console. See `barber/ANDROID_RELEASE.md` for the bundle hash and checks.
- **Conflicting customer identities:** the deployed sync guards skip conflicting records safely. Existing duplicates require ownership review; no automatic merge or destructive database repair was performed.
- **Source maintenance:** website HTML is the editorial source. If its structure changes, update parser fixtures/selectors; errors are surfaced rather than silently restoring obsolete content.

## Local handoff

- Code map: `APP_CODE_MAP.md`.
- Reproducible public audit: from `barber/`, run `dart run tool/audit_website.dart --check-media`.
- Current signed Play bundle: `barber/build/releases/BarberClub-1.4.6-14.aab`.
- Current emulator APK: `barber/build/verification/BarberClub-1.4.6-14-emulator.apk` (release code signed with the Android debug key for local testing; not a store upload).
- Emulator screenshots: `barber/build/verification/` (ignored build artifacts).
