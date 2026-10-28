import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: GarageStore

    private var car: CarProfile { store.snapshot.car }
    private var service: ServiceReminder { store.snapshot.service }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("YOUR GARAGE")
                            .font(.caption.weight(.bold))
                            .tracking(2)
                            .foregroundStyle(CarTheme.accent)
                        Text(car.name)
                            .font(.largeTitle.bold())
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        Text("All the details that keep you moving.")
                            .font(.subheadline)
                            .foregroundStyle(CarTheme.muted)
                    }
                    Spacer(minLength: 8)
                    NavigationLink {
                        SettingsView(store: store)
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .padding(13)
                            .background(CarTheme.raised, in: Circle())
                    }
                    .accessibilityLabel("Settings")
                }
                carBanner
                Text("Overview").font(.title2.bold())
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 13) {
                    NavigationLink { TiresView(store: store) } label: {
                        quickCard(icon: "circle.hexagongrid.fill", title: "Tires",
                                  detail: tireSummary, tint: CarTheme.accent)
                    }
                    NavigationLink { ProblemsView(store: store) } label: {
                        quickCard(icon: "engine.combustion.fill", title: "Problems",
                                  detail: String(store.snapshot.activeIssueCount),
                                  tint: store.snapshot.activeIssueCount > 0 ? CarTheme.warning : CarTheme.success)
                    }
                }
                NavigationLink { ServiceView(store: store) } label: {
                    Panel {
                        HStack(spacing: 16) {
                            Image(systemName: "wrench.adjustable.fill")
                                .font(.title2)
                                .foregroundStyle(CarTheme.accent)
                                .frame(width: 52, height: 52)
                                .background(CarTheme.raised, in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Next service")
                                    .font(.headline)
                                if let due = service.dueDate {
                                    Text(due, format: .dateTime.day().month(.abbreviated).year())
                                        .font(.subheadline)
                                        .foregroundStyle(CarTheme.muted)
                                } else if let km = service.dueOdometerKM {
                                    Text("\(km.formatted()) km")
                                        .font(.subheadline)
                                        .foregroundStyle(CarTheme.muted)
                                } else {
                                    Text("Set a reminder")
                                        .font(.subheadline)
                                        .foregroundStyle(CarTheme.muted)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(CarTheme.muted)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if service.isOverdue(odometer: car.odometerKM) {
                            Circle().fill(CarTheme.danger).frame(width: 9, height: 9).padding(12)
                        }
                    }
                }
                Text("Your data stays on your device.")
                    .font(.caption)
                    .foregroundStyle(CarTheme.muted)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .navigationBarHidden(true)
        .buttonStyle(.plain)
        .carPage()
    }

    private var tireSummary: String {
        let measured = store.snapshot.tires.reduce(0) { $0 + $1.measuredLaneCount }
        let total = store.snapshot.tires.reduce(0) { $0 + $1.lanes.count }
        return "\(measured)/\(total)"
    }

    private var carBanner: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [
                    Color(red: 0.13, green: 0.27, blue: 0.47),
                    Color(red: 0.10, green: 0.14, blue: 0.23)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "car.side.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.white.opacity(0.18))
                .frame(width: 235, height: 135)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 10)
            VStack(alignment: .leading, spacing: 6) {
                Text("ODOMETER")
                    .font(.caption2.bold())
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.72))
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(car.odometerKM.formatted())
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("km").foregroundStyle(.white.opacity(0.7))
                }
                if !car.manufacturer.isEmpty || !car.model.isEmpty {
                    Text([car.manufacturer, car.model].filter { !$0.isEmpty }.joined(separator: " "))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(23)
        }
        .frame(height: 182)
        .accessibilityElement(children: .combine)
    }

    private func quickCard(icon: String, title: LocalizedStringKey, detail: String, tint: Color) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 17) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 46, height: 46)
                    .background(CarTheme.raised, in: RoundedRectangle(cornerRadius: 13))
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.title2.bold())
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}
