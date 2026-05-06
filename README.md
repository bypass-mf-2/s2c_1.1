# Scan to Cart — SwiftUI

Native SwiftUI rewrite of the Scan to Cart grocery scanner. iOS 17+, Swift 5.10.

## What's wired up

- **Six-tab nav**: Home, Scan, Nutrition, Budget, Cart, Profile
- **Onboarding flow** (3 pages, persists "complete" flag)
- **Working barcode scanner** via `AVCaptureMetadataOutput` (EAN-8/13, UPC-E, Code 128, Code 39, PDF417, QR)
- **Open Food Facts lookup** for scanned barcodes (no API key needed)
- **Mock product fallback** for offline / unknown barcodes
- **Manual product search** (mock catalog)
- **Cart with per-store pricing** (Target, Walmart, Amazon, Costco, Kroger, Whole Foods, Trader Joe's) and quantity stepper
- **Nutrition tracking** — daily progress rings + macro bars (protein/carbs/fat/fiber)
- **Budget tracking** — monthly spend vs limit, by-category bar chart (Swift Charts)
- **Settings** — preferred store, daily nutrition goals, monthly budget, scan history
- **Persistence** — Codable + UserDefaults for settings and scanned items
- **Theme** — clean white, teal/green accent (Apple-style per the original PLAN.md)

## What's stubbed (intentional)

These all need accounts, entitlements, or service config the parent app has but a fresh project doesn't:

- **HealthKit** — toggle in Profile is cosmetic; no real read/write yet
- **Auth** (Supabase) — no sign-in flow; cart lives on-device only
- **Paywall** (RevenueCat) — no subscription gate
- **Cloud sync** — local-only
- **Push notifications** — not registered
- **Garmin / Fitbit / Kroger OAuth** — not ported (the existing `server/` Express proxy still works for both apps)
- **Crashlytics** — not added
- **Price comparison** — uses the same category × calorie heuristic as the RN app, not real retailer prices

## Configuration / API keys

Both this app and the React Native build (`s2c_1.1/expo/`) read the same set of project credentials. Copy the template and fill in the keys you have — all are optional except RevenueCat (subscription gating). The app degrades gracefully when keys are missing.

```bash
cd ~/ScanToCart
cp Config.xcconfig.example Config.xcconfig
# edit Config.xcconfig
```

| Key | Mirrors RN var | Purpose |
|---|---|---|
| `SUPABASE_URL` | `EXPO_PUBLIC_SUPABASE_URL` | Cloud sync (optional) |
| `SUPABASE_ANON_KEY` | `EXPO_PUBLIC_SUPABASE_ANON_KEY` | Cloud sync (optional) |
| `USDA_API_KEY` | `EXPO_PUBLIC_USDA_API_KEY` | USDA food search (optional) |
| `GARMIN_PROXY_URL` | `EXPO_PUBLIC_GARMIN_PROXY_URL` | Points at your `server/` Express proxy |
| `SERPAPI_KEY` | `EXPO_PUBLIC_SERPAPI_KEY` | Real grocery price comparison (optional) |
| `REVENUECAT_API_KEY` | `EXPO_PUBLIC_REVENUECAT_IOS_KEY` | Subscriptions (required when paywall is wired) |

> **xcconfig gotcha**: lines starting with `//` are comments. URLs must escape the double-slash as `https:/$()/example.com`. The template already shows this pattern.

Values flow `Config.xcconfig` → `Info.plist` (`$(VAR)` substitution) → Swift via [`Config.swift`](ScanToCart/Services/Config.swift). Reference them in code as `Config.supabaseURL`, `Config.usdaAPIKey`, etc.

`Config.xcconfig` is gitignored. Never commit it.

## Generating the Xcode project

The fastest path uses [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
cd ~/ScanToCart
xcodegen generate
open ScanToCart.xcodeproj
```

### Manual fallback (no XcodeGen)

If you'd rather not install XcodeGen:

1. Open Xcode → **File → New → Project → iOS → App**
2. Product Name: `ScanToCart`, Interface: SwiftUI, Language: Swift
3. Save it somewhere temporary
4. In the Project navigator, delete the auto-generated `ContentView.swift` and `ScanToCartApp.swift`
5. Drag the contents of `~/ScanToCart/ScanToCart/` into the project's source folder ("Copy items if needed" off — they're already in place)
6. Set deployment target to **iOS 17.0**
7. Build and run

## Project layout

```
ScanToCart/
├── ScanToCart/
│   ├── ScanToCartApp.swift           # @main entry
│   ├── Info.plist
│   ├── Assets.xcassets/
│   ├── Models/
│   │   ├── Product.swift             # Product, ScannedItem, NutritionInfo, StorePrice
│   │   ├── UserSettings.swift
│   │   └── MockProducts.swift
│   ├── Services/
│   │   ├── FoodDatabase.swift        # Open Food Facts client
│   │   ├── PriceEstimator.swift      # Category-based price heuristics
│   │   └── Storage.swift             # UserDefaults persistence
│   ├── Stores/
│   │   └── AppStore.swift            # @Observable global store
│   ├── Theme/
│   │   └── Theme.swift
│   └── Views/
│       ├── RootView.swift            # Tab nav + onboarding gate
│       ├── Onboarding/OnboardingView.swift
│       ├── Home/HomeScreen.swift
│       ├── Scanner/                  # ScannerScreen, BarcodeScannerView, ProductDetailSheet
│       ├── Nutrition/NutritionScreen.swift
│       ├── Budget/BudgetScreen.swift
│       ├── Lists/ListsScreen.swift
│       ├── Profile/ProfileScreen.swift
│       └── Components/               # ProgressRing, MacroBar, ProductCard
├── project.yml                       # XcodeGen spec
└── README.md
```

## Testing the scanner

The simulator can't scan real barcodes (no camera). To test:

- Run on a real device (free Apple ID dev account works for personal builds)
- Or test the manual search path: type "yogurt", "bread", "chicken", etc. into the Scan tab's search bar — mock products will surface
- Or use a known barcode against Open Food Facts directly: e.g., `737628064502` (a real product). Use a 2nd phone or printed image pointed at the device camera.