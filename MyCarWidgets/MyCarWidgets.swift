import SwiftUI
import WidgetKit

private enum WidgetStyle {
    static let background = Color(red: 0.08, green: 0.12, blue: 0.20)
    static let accent = Color(red: 0.34, green: 0.69, blue: 1.0)
    static let muted = Color(red: 0.67, green: 0.73, blue: 0.81)
    static let warning = Color(red: 1, green: 0.65, blue: 0.35)
}

struct GarageWidgetEntry: TimelineEntry {
    let date: Date
    let garage: GarageSnapshot
    let hasSharedData: Bool
}

struct GarageWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GarageWidgetEntry {
        GarageWidgetEntry(date: .now, garage: GarageSnapshot(), hasSharedData: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (GarageWidgetEntry) -> Void) {
        let snapshot = GaragePersistence.loadForWidget()
        completion(GarageWidgetEntry(date: .now, garage: snapshot ?? GarageSnapshot(), hasSharedData: snapshot != nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GarageWidgetEntry>) -> Void) {
        let now = Date()
        let snapshot = GaragePersistence.loadForWidget()
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: now)
        let entries = (0..<8).compactMap { day -> GarageWidgetEntry? in
            guard let date = calendar.date(byAdding: .day, value: day, to: midnight) else { return nil }
            return GarageWidgetEntry(date: day == 0 ? now : date, garage: snapshot ?? GarageSnapshot(), hasSharedData: snapshot != nil)
        }
        let refreshDate = calendar.date(byAdding: .day, value: 8, to: midnight) ?? now.addingTimeInterval(86400)
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }
}

struct ServiceStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GarageWidgetEntry

    private var service: ServiceReminder { entry.garage.service }
    private var days: Int? { service.daysUntilDue(relativeTo: entry.date) }
    private var overdue: Bool {
        service.isOverdue(odometer: entry.garage.car.odometerKM, now: entry.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("MYCAR SERVICE", systemImage: "wrench.adjustable.fill")
                .font(.caption2.bold())
                .foregroundStyle(WidgetStyle.accent)
                .lineLimit(1)
            if !entry.hasSharedData {
                Text("Open MyCar to sync").font(.headline)
                Text("Widgets need shared App Group signing.")
                    .font(.caption).foregroundStyle(WidgetStyle.muted)
            } else if !service.isConfigured {
                Spacer(minLength: 3)
                Text("No service planned").font(.headline)
                Text("Open MyCar to add a reminder.")
                    .font(.caption)
                    .foregroundStyle(WidgetStyle.muted)
            } else {
                if let due = service.dueDate {
                    Text(due, format: .dateTime.day().month(.abbreviated).year())
                        .font(family == .systemSmall ? .headline : .title2.bold())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                } else if let km = service.dueOdometerKM {
                    Text("\(km.formatted()) km")
                        .font(.title2.bold())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                if let days {
                    if days < 0 {
                        Text("\(abs(days)) days overdue")
                            .font(.caption.bold())
                            .foregroundStyle(WidgetStyle.warning)
                    } else if days == 0 {
                        Text("Due today")
                            .font(.caption.bold())
                            .foregroundStyle(WidgetStyle.warning)
                    } else {
                        Text("\(days) days to go")
                            .font(.caption)
                            .foregroundStyle(WidgetStyle.muted)
                    }
                }
                if family == .systemMedium {
                    if let dueKm = service.dueOdometerKM {
                        Label("\(dueKm.formatted()) km target", systemImage: "speedometer")
                            .font(.caption)
                            .foregroundStyle(WidgetStyle.muted)
                    }
                    if !service.notes.isEmpty {
                        Text(service.notes)
                            .font(.caption)
                            .foregroundStyle(WidgetStyle.muted)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                if overdue {
                    Label("Action needed", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(WidgetStyle.warning)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(WidgetStyle.background, for: .widget)
        .foregroundStyle(.white)
    }
}

struct GarageOverviewWidgetView: View {
    let entry: GarageWidgetEntry

    private var minimumDepth: Double? {
        entry.garage.tires.compactMap(\.treadDepthMM).min()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "car.fill")
                    .foregroundStyle(WidgetStyle.accent)
                Text(entry.garage.car.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("MYCAR")
                    .font(.caption2.bold())
                    .foregroundStyle(WidgetStyle.muted)
            }
            if !entry.hasSharedData {
                Text("Open MyCar to sync. App Group signing required.")
                    .font(.caption).foregroundStyle(WidgetStyle.muted)
            } else {
            HStack(spacing: 10) {
                overviewItem(symbol: "speedometer", title: "Mileage",
                             value: "\(entry.garage.car.odometerKM.formatted()) km")
                overviewItem(symbol: "exclamationmark.circle", title: "Problems",
                             value: String(entry.garage.activeIssueCount))
                overviewItem(symbol: "circle.dotted.circle", title: "Min. tread",
                             value: minimumDepth.map { String(format: "%.1f mm", $0) } ?? "—")
            }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(WidgetStyle.background, for: .widget)
        .foregroundStyle(.white)
    }

    private func overviewItem(symbol: String, title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).foregroundStyle(WidgetStyle.accent)
            Text(value)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption2)
                .foregroundStyle(WidgetStyle.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MyCarServiceWidget: Widget {
    let kind = "MyCarServiceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GarageWidgetProvider()) { entry in
            ServiceStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("MyCar Service")
        .description("Shows your next service date and mileage target.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MyCarOverviewWidget: Widget {
    let kind = "MyCarOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GarageWidgetProvider()) { entry in
            GarageOverviewWidgetView(entry: entry)
        }
        .configurationDisplayName("MyCar Overview")
        .description("Car mileage, open issues and tire depth at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct MyCarWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MyCarServiceWidget()
        MyCarOverviewWidget()
    }
}
