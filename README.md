# MyCar

A native **SwiftUI iPhone app** for keeping track of your vehicle, tire tread depths, car problems, and upcoming service. The look is inspired by the references in [PLANS/PLANS.md](PLANS/PLANS.md).

## Features

- Dark dashboard with vehicle name, model, mileage, **your own car photo** behind the odometer, number of measured tires (not grooves), open problems, and next service.
- Four independently editable tires (front left/right and rear left/right). Each tire has its own editable **tread grooves** (default: 4, adjustable from 1 to 12 with +/- controls). Every groove stores a separate depth in **millimeters** and measurement date, while the tire overview shows the lowest measured depth. Tap a tire in the car diagram or list to open its enlarged profile and editor. Removing a measured groove asks for confirmation.
- Problems with title, details, a **1–99 priority** (1 = most urgent), editing, delete, resolve/reopen, and priority/date sorting.
- Service reminder by **date and/or odometer**, with notes and last service date; overdue and remaining time/distance displays.
- **WidgetKit widgets:** MyCar Service (small and medium) and MyCar Overview (medium).
- Tap the camera icon on the odometer card to pick your own photo from the system Photos picker; replace/remove it in Settings. The photo is resized and stored as a local JPEG file, not included in widget JSON. No broad Photos permission is required.
- The four-wheel tires overview displays just the **minimum tread depth per tire**. Each groove is visible and editable only on that tire’s detail page.
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

Photos are stored separately in the local Application Support directory (or the App Group container when provisioned). They stay on the device and are removed when the user deletes them in Settings. Existing v1 single-depth values are automatically migrated into the first groove; remaining grooves stay unmeasured instead of receiving invented values. The app and widgets read/write `garage.snapshot.v1` in `UserDefaults(suiteName: "group.dev.kaskader.mycar")` as JSON. If the suite is unavailable the app falls back to its own preferences, so car data entry remains usable; widget sharing still requires the entitlement. Modifying or deleting the app can delete stored data; there is currently no cloud sync or backup/export.

## Code layout

- `MyCar/`: iOS app, interface, editors and observable store.
- `MyCarShared/`: Codable models and persistence used by both targets.
- `MyCarWidgets/`: service and overview widgets.
- `Localization/`: English and German interface text.
- `.github/workflows/ios.yml`: automatic unsigned simulator/device builds and IPA artifact.

## Implementation status

The requirements in `PLANS/PLANS.md` are implemented in source. Device signing, App Group provisioning and physical iPhone testing remain environment-dependent. The GitHub Actions workflow validates builds on an Apple runner.


## Latest UI and tire-set update

- The **home screen matches the provided layout concept**: large customizable car image, car name, VIN, vehicle details, mileage, and a five-item bottom navigation (problems, tires, My Car, service, settings).
- Add/edit VIN (17 characters) and free-text vehicle details in **My Car** or Settings.
- **Multiple tire sets**, each with a name and summer / winter / all-season classification. Select the mounted set from the Tires screen. Creating a set starts with four independent, unmeasured tires; deleting a set requires confirmation and cannot delete the final set.
- **Per-wheel specifications:** tire size, manufacturer, model, DOT and notes. Each set has its own four tires and its own tread measurements.
- **Connected tread strips:** adjacent grooves form one tire tread block; each groove has a separate measured value and a colored vertical line indicating approximate depth (green ≥5, yellow ≥3.5, orange ≥1.6, red below 1.6 mm; gray = unmeasured). These colors are illustrative, **not legal minimums or inspection advice**.
- Each wheel card offers **+ / −** for 1–12 grooves. Removing a groove containing a measurement needs confirmation. Tap a wheel for full-size measurements and tire specifications.
- Overview widgets and readings use **only the selected tire set**, and use the *minimum measured depth* rather than averaging.
- **Existing data:** JSON from earlier releases with a top-level \`tires\` array is migrated into the first tire set. Existing grooves, notes and vehicle fields are retained. Previous vehicle details without VIN remain valid.

### Installation

Open [GitHub Actions](https://github.com/kaskader-idk/MyCar/actions), select the latest successful **iOS build**, and download the \`MyCar-unsigned-ipa\` artifact. Unzip it, then **sign** the IPA with a compatible tool before installation; the unsigned IPA cannot be installed directly. Enabling shared App Group entitlements for widgets may require suitable Apple Developer provisioning. A source build with Xcode supports simulator testing.


## Multi-car garage and widget synchronization

- Manage vehicles under **Settings → My vehicles**. Add cars, select one, or delete the selected vehicle (at least one is kept).
- Swipe horizontally on **My garage, Tires, Problems, or Service** to move between cars; the selector shows the active car. Tire sets, issues, service and vehicle details are separate for every car. The widgets display the currently selected car.
- Your old single-car records migrate into the first garage vehicle. Each newly created vehicle starts with its own empty maintenance and tire data.
- The app immediately seeds shared widget data at launch and updates widget timelines whenever the selected car or its records change. Widgets never read their own isolated standard preferences as though they were main-app data.
- **Widgets require a correctly provisioned App Group** (`group.dev.kaskader.mycar`) in BOTH the app and embedded widget extension. When signing with Sideloadly/free Personal Team the capability may be stripped; no app-code change can bypass iOS sandboxing. Check **Settings → Widget sync** in MyCar. If it says *App Group signing missing*, the IPA must be signed with matching App Group entitlements using a suitable Apple Developer team. After installation launch MyCar once and re-add the widgets if needed.
