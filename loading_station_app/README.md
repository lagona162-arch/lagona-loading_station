# Lagona Loading Station App

Flutter application for the Lagona Business Hub ➝ Loading Station ➝ Riders ➝ Merchants hierarchy.  
It centralizes onboarding, rider approvals, commission tracking, top-up bonuses, and fulfillment boards
for both **Pabili** and **Padala** flows backed by Supabase.

## ✨ Feature Highlights

- **Multi-step onboarding** for Loading Stations with BHCODE validation and document upload (DTI + Mayor’s Permit).  
- **Role-aware auth** with Supabase email login, session persistence, and demo/offline mode fallback.  
- **Live hierarchy view** (Business Hub → Loading Station → Riders → Merchants) with quick LSCODE regeneration.  
- **Dynamic commission card** reflecting Supabase `commission_settings` for Hub, Station, Rider, Shareholder.  
- **Operations dashboard** showing balances, request queues, merchant status, rider priority ladder, and top-up bonuses.  
- **Dedicated workspaces** for Deliveries, Riders, Wallet/Top-ups, and Merchants powered by Riverpod providers.  
- **Top-up simulator** honoring “₱5,000 ➝ ₱7,500” (50% bonus) & “₱1,000 ➝ ₱1,200–₱1,300” (20–30% bonus) use cases.  
- **Supabase integration layer** targeting the provided schema (`loading_stations`, `riders`, `merchants`, `deliveries`, `topups`, etc.).

## 🗂️ Project Structure

```
lib/
├── app.dart                     # MaterialApp + global theme
├── bootstrap.dart               # Supabase initialization / demo fallback
├── core/
│   ├── config/supabase_config.dart
│   ├── models/station_models.dart
│   ├── router/app_router.dart   # GoRouter shell with bottom navigation
│   └── theme/{app_colors,app_theme}.dart
├── features/
│   ├── auth/                    # Login + registration + auth repository
│   ├── dashboard/               # Station dashboard + repository/provider
│   ├── deliveries/              # Pabili & Padala board
│   ├── riders/                  # Rider queue + priority manager
│   ├── merchants/               # Merchant directory + status view
│   ├── topup/                   # Wallet + top-up requests
│   └── shell/                   # Navigation shell
└── services/supabase_service.dart
```

## 🚀 Getting Started

1. **Install dependencies**
   ```bash
   cd loading_station_app
   flutter pub get
   ```

2. **Configure Supabase (recommended)**
   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://<project>.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=<anon-key>
   ```
   Without credentials the app runs in **demo mode** with mock data (useful for UI previews).

3. **Run**
   ```bash
   flutter run
   ```

### Environment Expectations
- `loading_stations.id` == Auth user id (FK `public.users.id`).
- `business_hubs` contains BHCODE used during registration.
- `commission_settings` stores percentages per role.
- `pending_merchant_registrations` temporarily holds uploaded documents for admin review.
- Storage bucket `loading-station-documents` used for DTI/Mayor’s Permit uploads.

## 🧩 Extending / Customizing

- Add real-time listeners (Supabase Realtime) inside `StationRepository` for live booking broadcasts.
- Implement RPCs (e.g., `increment_loading_station_balance`) for atomic wallet updates.
- Wire notifications to Business Hub + Merchant apps via Supabase Edge Functions / Firebase Cloud Messaging.
- Replace mock charts with BI widgets (`Syncfusion`, `fl_chart`) when analytics requirements mature.

## 🧪 Testing / Linting

```
flutter analyze
flutter test
```

---

Designed with Lagona’s gold/charcoal palette and multi-role hierarchy in mind.  
Questions or new user stories? Update `StationDashboardData` or add a new Riverpod provider per module.###
