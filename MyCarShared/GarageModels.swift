import Foundation

enum TirePosition: String, CaseIterable, Codable, Identifiable, Hashable {
    case frontLeft, frontRight, rearLeft, rearRight

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .frontLeft: return "Front left"
        case .frontRight: return "Front right"
        case .rearLeft: return "Rear left"
        case .rearRight: return "Rear right"
        }
    }

    var isFront: Bool { self == .frontLeft || self == .frontRight }
    var isLeft: Bool { self == .frontLeft || self == .rearLeft }
}

/// One transverse measurement track in a tire, ordered from left to right as shown.
struct TreadLane: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var depthMM: Double?
    var measuredAt: Date?

    init(id: UUID = UUID(), depthMM: Double? = nil, measuredAt: Date? = nil) {
        self.id = id
        self.depthMM = depthMM
        self.measuredAt = measuredAt
    }
}

struct TireRecord: Codable, Identifiable {
    var position: TirePosition
    var lanes: [TreadLane]
    var notes: String

    var id: TirePosition { position }

    /// The lowest measured groove, rather than an average that masks wear.
    var treadDepthMM: Double? { lanes.compactMap(\.depthMM).min() }
    var measuredAt: Date? { lanes.compactMap(\.measuredAt).max() }
    var measuredLaneCount: Int { lanes.filter { $0.depthMM != nil }.count }

    init(position: TirePosition, lanes: [TreadLane] = (0..<4).map { _ in TreadLane() },
         notes: String = "") {
        self.position = position
        self.lanes = lanes.isEmpty ? [TreadLane()] : lanes
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case position, lanes, notes, treadDepthMM, measuredAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        position = try values.decode(TirePosition.self, forKey: .position)
        notes = try values.decodeIfPresent(String.self, forKey: .notes) ?? ""
        if let storedLanes = try values.decodeIfPresent([TreadLane].self, forKey: .lanes),
           !storedLanes.isEmpty {
            lanes = storedLanes
        } else if let legacyDepth = try values.decodeIfPresent(Double.self, forKey: .treadDepthMM) {
            // Upgrade data saved by MyCar v1 without guessing values for other grooves.
            let previousDate = try values.decodeIfPresent(Date.self, forKey: .measuredAt)
            lanes = [TreadLane(depthMM: legacyDepth, measuredAt: previousDate)]
                + (0..<3).map { _ in TreadLane() }
        } else {
            lanes = (0..<4).map { _ in TreadLane() }
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(position, forKey: .position)
        try values.encode(lanes, forKey: .lanes)
        try values.encode(notes, forKey: .notes)
    }
}

struct CarProfile: Codable {
    var name: String = "My Car"
    var manufacturer: String = ""
    var model: String = ""
    var year: Int?
    var licensePlate: String = ""
    var odometerKM: Int = 0
}

struct CarIssue: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var details: String = ""
    var priority: Int = 3
    var createdAt: Date = .now
    var isResolved: Bool = false
    var resolvedAt: Date?

    static func == (lhs: CarIssue, rhs: CarIssue) -> Bool { lhs.id == rhs.id }
}

struct ServiceReminder: Codable {
    var dueDate: Date?
    var dueOdometerKM: Int?
    var notes: String = ""
    var lastServiceDate: Date?

    var isConfigured: Bool { dueDate != nil || dueOdometerKM != nil }

    func daysUntilDue(relativeTo now: Date = .now) -> Int? {
        guard let dueDate else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: dueDate)).day
    }

    func distanceUntilDue(odometer: Int) -> Int? {
        guard let dueOdometerKM else { return nil }
        return dueOdometerKM - odometer
    }

    func isOverdue(odometer: Int, now: Date = .now) -> Bool {
        (daysUntilDue(relativeTo: now).map { $0 < 0 } ?? false)
        || (distanceUntilDue(odometer: odometer).map { $0 <= 0 } ?? false)
    }
}

struct GarageSnapshot: Codable {
    var car = CarProfile()
    var tires: [TireRecord] = TirePosition.allCases.map { TireRecord(position: $0) }
    var issues: [CarIssue] = []
    var service = ServiceReminder()

    var activeIssueCount: Int { issues.filter { !$0.isResolved }.count }

    func tire(at position: TirePosition) -> TireRecord {
        tires.first(where: { $0.position == position }) ?? TireRecord(position: position)
    }
}

enum GaragePersistence {
    // Both the iOS app and the WidgetKit extension must use the SAME App Group.
    static let appGroup = "group.dev.kaskader.mycar"
    static let key = "garage.snapshot.v1"

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func load() -> GarageSnapshot {
        guard let data = sharedDefaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(GarageSnapshot.self, from: data) else {
            return GarageSnapshot()
        }
        return snapshot
    }

    @discardableResult
    static func save(_ snapshot: GarageSnapshot) -> Bool {
        guard let data = try? JSONEncoder().encode(snapshot) else { return false }
        sharedDefaults.set(data, forKey: key)
        return true
    }
}
