# Hosil X

Flutter agro marketplace and farm-management app backed by Supabase.

## Development

Install a compatible Flutter SDK, then run:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Provide the Supabase project URL and its public anon/publishable key with
`SUPABASE_URL` and `SUPABASE_ANON_KEY` Dart defines. Never put a service-role
or other privileged key in the mobile app.

## Database changes

The app does not apply SQL automatically. Review the live schema, existing
policies, and backups before running any migration. The additive migrations in this work are intended to run after the existing
base schema and migrations 2–9 (including `migration6_flutter_app.sql`,
`migration7_seller_public.sql`, `migration8_audit_triggers.sql`, and
`migration9_profile_realtime.sql`), in this order:

1. `supabase/migration10_product_reports.sql`
2. `supabase/migration11_superapp_data.sql`
3. `supabase/migration12_chat_messages.sql`
4. `supabase/migration13_service_listings.sql`
5. `supabase/migration14_harvest_passports.sql`
6. `supabase/migration15_push_tokens.sql`
7. `supabase/migration16_trust_and_transactions.sql`
8. `supabase/migration17_profile_avatars.sql`
9. `supabase/migration18_agroapteka.sql`
10. `supabase/migration19_universal_goals.sql`
11. `supabase/migration20_banner_targets.sql`
12. `supabase/migration21_ai_request_quota.sql`
13. `supabase/migration22_service_listing_images.sql`

The new features depend on the existing `profiles`, `products`, `inquiries`,
`reports`, `audit_logs`, and `public.is_admin()` schema. Verify those
dependencies against the target Supabase project before applying the SQL.
`supabase/stage7_rls_tests.sql` is a separate, intentionally failing
transactional test script; its final exception reports results and rolls back
the test transaction. It must be run only in an appropriate test environment.
Rollback-only RLS scripts are also provided:
`migration10_reports_rls_tests.sql`,
`migration11_goals_fieldbook_rls_tests.sql`,
`migration12_chat_rls_tests.sql`,
`migration13_services_rls_tests.sql`,
`migration14_passport_rls_tests.sql`,
`migration15_push_rls_tests.sql`, and
`migration16_trust_rls_tests.sql`. They require the fixtures described in each
script header and have not been run here.
Do not apply new migrations until the target schema and each policy have been
reviewed. Migration 16 adds private seller-review and transaction ledgers;
clients cannot create or change transaction rows or mark sellers verified.

Migration 18 adds the Agroapteka catalog, private owner-only business details,
product listings, customer inquiries and messages, user reports, admin review,
and moderation audit entries. Apply it manually only after checking that
migrations 6–17 and `public.is_admin()` are present. It is additive and is not
run by the app. Public store coordinates are returned only after the owner
explicitly enables public map visibility; private email, document references,
and review notes are protected by RLS. Product images use the existing
`images` bucket and its existing policies. Verify those storage policies on the
target project before release. No online payment is enabled; Agroapteka actions
create inquiries only.

Migration 19 adds owner-scoped universal goals, task links, and private goal
history. It does not remove or rewrite `financial_goals`; the existing savings
screen remains available from the universal goals screen. Apply and test the
migration manually before using the new `/goals` screen. Migration 20 expands
the existing banner `link_type` check constraint so admins can link verified
products, active categories, approved Agroapteka stores, active warehouses,
active logistics/equipment listings, or HTTPS URLs. Neither migration is
applied automatically.

Harvest passport QR codes use one canonical URL:
`<SUPABASE_URL>/functions/v1/verify-harvest-passport?token=<passport-uuid>`.
The Edge Function returns a responsive, privacy-limited HTML verification page
and accepts CORS preflight for browser clients. Deploy it manually after review:

```sh
supabase functions deploy verify-harvest-passport
```

The function must be deployed to the same Supabase project URL configured for
the Flutter build. It uses the platform-provided Supabase URL and anon key;
never add a service-role key. `WEB_URL` is not used for passport verification
or AI requests.

## Feature availability

Weather data is fetched from Open-Meteo for the selected region's approximate
centre; it is a general forecast, not a field-level measurement or crop
recommendation. Equipment and logistics listings remain private until an
admin approves them. Harvest passports identify a server-issued public listing
only; they are not laboratory, quality, origin, or certification claims.

### Passport and push setup

Deploy `supabase/functions/verify-harvest-passport` after reviewing migration
14. For Android push, register this Android package as a Firebase app and
provide the real Firebase app options as Dart defines:
`FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, and
`FIREBASE_PROJECT_ID`. Set the `FCM_SERVICE_ACCOUNT_JSON` secret
for the `send-push` Edge Function, deploy it, and configure a Supabase
Database Webhook for `public.notifications` inserts to POST its standard row
payload to that function. Configure `Content-Type: application/json` and an
`Authorization: Bearer <service-role-key>` header in the webhook; never put
that key in the app or commit it. Push is inactive until these steps are
complete.

### Phone verification, seller review, and payments

Phone confirmation is the Supabase Auth `phone_confirmed_at` value; the
editable `profiles.phone` field is not proof of verification. Configure a
supported Supabase Auth SMS provider, phone auth, and rate limits before using
the OTP UI. A verified phone is required to submit a seller-review request.
Admins can review requests from the admin dashboard; clients cannot set seller
verification status themselves.

Profile pictures use the existing public `images` storage bucket. Apply
`migration17_profile_avatars.sql` before releasing a build that reads
`profiles.avatar_url`.

No payment provider or verified webhook is configured in this repository.
Migration 16 prepares a private, participant-readable transaction ledger with
audited state transitions, but deliberately grants no client transaction
creation/update rights. Escrow, collection, refunds, and settlement are not
available. Before enabling them, select a payment provider, implement a
server-side adapter implementing
`supabase/functions/_shared/payment_provider.ts` and a
signature/idempotency-checked webhook,
determine legal and dispute-handling requirements, and test all transitions
against a non-production Supabase project. Never treat a client status or an
unverified webhook payload as proof of payment.

`supabase/migration16_trust_rls_tests.sql` is a rollback-only RLS test script
requiring test users, an admin, a product, and a profile without a confirmed
phone; its final exception is expected. It has not been run here.
`supabase/migration14_passport_rls_tests.sql` likewise needs an active,
approved product and two users, and tests owner-only issuance and public data
minimization. It has not been run.

### Agroapteka

After reviewing the target schema and backups, apply
`supabase/migration18_agroapteka.sql` manually after migration 17. Never run it
against production without first testing its RLS using separate farmer, store
owner, and administrator accounts. An owner profile and each product start in
moderation; only administrator review makes a shop or product publicly
visible. Editing store identity or location sends its profile back for review.
No rating, open/closed calculation, inventory reservation, verified-license
claim, or online payment is fabricated. A customer request is not a completed
sale.

### AI assistant

The Flutter app calls the `ai-assistant` Supabase Edge Function, not the
website. The function validates the user's Supabase JWT and accesses finance
rows only through the user's RLS-scoped client. The OpenAI key and model
configuration stay server-side. `supabase/functions/ai-assistant` and its
provider adapter have been added but are not deployed. Review and test the
function and migration against a non-production Supabase project first.

Apply `supabase/migration21_ai_request_quota.sql` manually after migration 20.
It creates a private daily-usage table and a service-role-only quota RPC; it
does not expose quota data to app users. Verify the function grants and quota
behavior before deployment. No database migration is applied automatically.

Deploy the Edge Function only after the migration succeeds:

```sh
supabase functions deploy ai-assistant
```

In the trusted Supabase dashboard, set `OPENAI_API_KEY` as a Function secret;
never add the value to Flutter, Dart defines, the repository, or an APK. Set
`AI_PROVIDER=openai` and `AI_MODEL=gpt-6.1-sol` there as configurable server
settings. Optional `AI_DAILY_REQUEST_LIMIT`, `AI_MAX_REQUEST_BYTES`,
`AI_MAX_MESSAGE_CHARS`, and `AI_TIMEOUT_MS` bound usage. The configured model
ID is listed by the official OpenAI OpenAPI specification; it can be changed
without editing Dart code. Provider quota/errors are mapped to safe messages.
There is no live price source, and the doctor mode does not accept photos or
make a definitive diagnosis. AI cannot run offline. Configure provider privacy
and retention settings and Supabase invocation-level abuse controls before
production use.

Migration 22 adds nullable `service_listings.image_url` so existing logistics
and equipment listings remain intact. New listing forms upload images to the
existing `images` bucket. The migration prevents publishing image-less service
listings but is not applied automatically; verify bucket upload policies first.

The repository currently contains Android platform files only. The 1024×1024
source brand asset is `assets/branding/hosil_x_app_icon.png`; Android density
launcher images and an adaptive icon foreground are generated from that source.
The Flutter UI uses the same image for its restrained brand mark. iOS and web
platform folders are not present in this checkout, so their launcher icons and
web favicon/PWA icons are not configured here.

On a Windows machine with Flutter and Android build prerequisites installed,
run the following from the repository root to fetch dependencies, analyze,
test, and build the APKs:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
```
