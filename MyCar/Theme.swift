import SwiftUI

enum CarTheme {
    static let background = Color(red: 0.055, green: 0.075, blue: 0.12)
    static let surface = Color(red: 0.10, green: 0.13, blue: 0.20)
    static let raised = Color(red: 0.14, green: 0.18, blue: 0.27)
    static let accent = Color(red: 0.31, green: 0.65, blue: 1.0)
    static let muted = Color(red: 0.63, green: 0.69, blue: 0.78)
    static let warning = Color(red: 1.0, green: 0.70, blue: 0.34)
    static let danger = Color(red: 1.0, green: 0.36, blue: 0.38)
    static let success = Color(red: 0.35, green: 0.84, blue: 0.62)
}

struct Panel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(CarTheme.surface, in: RoundedRectangle(cornerRadius: 23))
    }
}

struct PageBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(CarTheme.background.ignoresSafeArea())
            .foregroundStyle(.white)
            .tint(CarTheme.accent)
            .toolbarBackground(CarTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

extension View {
    func carPage() -> some View { modifier(PageBackground()) }
}

struct SectionLabel: View {
    var title: LocalizedStringKey
    var symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.headline)
            .foregroundStyle(.white)
    }
}

struct EmptyPanel: View {
    var symbol: String
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey

    var body: some View {
        Panel {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.largeTitle)
                    .foregroundStyle(CarTheme.accent)
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(CarTheme.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 25)
        }
    }
}


struct CarSwitcher: View {
    @ObservedObject var store: GarageStore

    var body: some View {
        HStack(spacing: 12) {
            Button { store.nextCar(direction: -1) } label: {
                Image(systemName: "chevron.left").frame(width: 32, height: 34)
            }
            .disabled(store.cars.first?.id == store.snapshot.id)
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                Text(store.snapshot.car.name).font(.headline).lineLimit(1)
                HStack(spacing: 5) {
                    ForEach(store.cars) { car in
                        Circle()
                            .fill(car.id == store.snapshot.id ? CarTheme.accent : CarTheme.muted.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }
                .accessibilityLabel("Swipe left or right to switch cars")
            }
            Spacer(minLength: 0)
            Button { store.nextCar(direction: 1) } label: {
                Image(systemName: "chevron.right").frame(width: 32, height: 34)
            }
            .disabled(store.cars.last?.id == store.snapshot.id)
        }
        .buttonStyle(.plain)
        .padding(11)
        .background(CarTheme.surface, in: RoundedRectangle(cornerRadius: 17))
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 55).onEnded { value in
                if value.translation.width < -60 { store.nextCar(direction: 1) }
                if value.translation.width > 60 { store.nextCar(direction: -1) }
            }
        )
    }
}
