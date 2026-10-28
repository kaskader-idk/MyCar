import SwiftUI

@main
struct MyCarApp: App {
    @StateObject private var store = GarageStore()
    @AppStorage("mycar.language") private var language = "system"
    @AppStorage("mycar.textSize") private var textSize = "normal"

    private var selectedLocale: Locale {
        language == "system" ? .autoupdatingCurrent : Locale(identifier: language)
    }

    private var selectedTextSize: DynamicTypeSize {
        switch textSize {
        case "large": return .xLarge
        case "extra": return .xxxLarge
        default: return .large
        }
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                DashboardView(store: store)
            }
            .environment(\.locale, selectedLocale)
            .environment(\.dynamicTypeSize, selectedTextSize)
            .preferredColorScheme(.dark)
        }
    }
}
