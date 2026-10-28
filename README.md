# MyCar

A native **SwiftUI iPhone app** for keeping track of your vehicle, tire tread depths, car problems, and upcoming service. The look is inspired by the references in [PLANS/PLANS.md](PLANS/PLANS.md).

## Features

- Dark dashboard with vehicle name, model, mileage, tire measurement count, open problems, and next service.
- Four independently editable tires (front left/right and rear left/right). Tap a tire in the car diagram or list to open a full-screen detail view. Depth is entered in **millimeters** and notes and measurement dates are stored.
- Problems with title, details, a **1–99 priority** (1 = most urgent), editing, delete, resolve/reopen, and priority/date sorting.
- Service reminder by **date and/or odometer**, with notes and last service date; overdue and remaining time/distance displays.
- **WidgetKit widgets:** MyCar Service (small and medium) and MyCar Overview (medium).
- Settings for German/English/system language, text size, and vehicle details.
- Local-only JSON storage shared with widgets through an App Group. No login, server, ads, or external dependencies.

## Project / requirements

- iOS **17.0 or later**, Xcode **16 or later** on a Mac to open and build the source.
- Open `MyCar.xcodeproj`, choose the **MyCar** scheme and an iPhone simulator, then Run.
- You do **not** need to publish this app on the App Store to test it.

### Testing on a physical iPhone

1. In Xcode, open target **MyCar** → Signing & Capabilities and select your Apple Development team. Repeat for **MyCarWidgets**.
2. Change both bundle IDs if another developer has already claimed the defaults (`dev.kaskader.MyCar` and `dev.kaskader.MyCar.widgets`).
3. Register/enable the **App Groups** capability for both targets with the **same group** `group.dev.kaskader.mycar`. If you change the group, also change `GaragePersistence.appGroup` in `MyCarShared/GarageModels.swift` and both `.entitlements` files.
4. Connect and trust your iPhone, enable Developer Mode if requested, select it in Xcode, and Run.
5. Long-press the iPhone Home Screen → Add Widget → **MyCar** → select Service (small/medium) or Overview (medium).

**Important:** Widget data sharing requires valid App Group entitlements/provisioning. Apple may limit this capability for free Personal Teams; you may need a paid Apple Developer membership for physical-device widgets. Without a shared App Group the main app still saves locally, but widgets cannot reliably see its data.

### Windows / Sideloadly

GitHub Actions builds the iPhone app and uploads an unsigned **MyCar-unsigned.ipa** under each successful workflow run's **Artifacts**. That package must be **signed** before installing on a real iPhone (e.g. by a compatible sideloading/signing tool); an unsigned IPA is not directly installable. Signing of the embedded widget and its App Group entitlements depends on the signing method and developer account. You can use the app without App Store publication. These artifacts are build outputs, not App Store releases.

## Storage

The app and widgets read/write `garage.snapshot.v1` in `UserDefaults(suiteName: "group.dev.kaskader.mycar")` as JSON. If the suite is unavailable the app falls back to its own preferences, so car data entry remains usable; widget sharing still requires the entitlement. Modifying or deleting the app can delete stored data; there is currently no cloud sync or backup/export.

## Code layout

- `MyCar/`: iOS app, interface, editors and observable store.
- `MyCarShared/`: Codable models and persistence used by both targets.
- `MyCarWidgets/`: service and overview widgets.
- `Localization/`: English and German interface text.
- `.github/workflows/ios.yml`: automatic unsigned simulator/device builds and IPA artifact.

## Implementation status

The requirements in `PLANS/PLANS.md` are implemented in source. Device signing, App Group provisioning and physical iPhone testing remain environment-dependent. The GitHub Actions workflow validates builds on an Apple runner.
