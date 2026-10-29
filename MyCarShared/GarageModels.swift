import Foundation

enum TirePosition: String, CaseIterable, Codable, Identifiable, Hashable {
    case frontLeft, frontRight, rearLeft, rearRight
    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .frontLeft: "Front left"
        case .frontRight: "Front right"
        case .rearLeft: "Rear left"
        case .rearRight: "Rear right"
        }
    }

    var isFront: Bool { self == .frontLeft || self == .frontRight }
    var isLeft: Bool { self == .frontLeft || self == .rearLeft }
}

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

enum TireSeason: String, CaseIterable, Codable, Identifiable {
    case summer, winter, allSeason
    var id: String { rawValue }
    var titleKey: String {
        switch self {
        case .summer: "Summer"
        case .winter: "Winter"
        case .allSeason: "All-season"
        }
    }
}

struct TireRecord: Codable, Identifiable {
    var position: TirePosition
    var lanes: [TreadLane]
    var notes: String
    var manufacturer: String
    var model: String
    var size: String
    var dot: String

    var id: TirePosition { position }
    var treadDepthMM: Double? { lanes.compactMap(\.depthMM).min() }
    var measuredAt: Date? { lanes.compactMap(\.measuredAt).max() }
    var measuredLaneCount: Int { lanes.filter { $0.depthMM != nil }.count }

    init(position: TirePosition,
         lanes: [TreadLane] = (0..<4).map { _ in TreadLane() },
         notes: String = "", manufacturer: String = "", model: String = "",
         size: String = "", dot: String = "") {
        self.position = position
        self.lanes = lanes.isEmpty ? [TreadLane()] : lanes
        self.notes = notes
        self.manufacturer = manufacturer
        self.model = model
        self.size = size
        self.dot = dot
    }

    private enum CodingKeys: String, CodingKey {
        case position, lanes, notes, treadDepthMM, measuredAt
        case manufacturer, model, size, dot
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        position = try c.decode(TirePosition.self, forKey: .position)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        manufacturer = try c.decodeIfPresent(String.self, forKey: .manufacturer) ?? ""
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        size = try c.decodeIfPresent(String.self, forKey: .size) ?? ""
        dot = try c.decodeIfPresent(String.self, forKey: .dot) ?? ""
        if let current = try c.decodeIfPresent([TreadLane].self, forKey: .lanes),
           !current.isEmpty {
            lanes = current
        } else if let previous = try c.decodeIfPresent(Double.self, forKey: .treadDepthMM) {
            let measured = try c.decodeIfPresent(Date.self, forKey: .measuredAt)
            lanes = [TreadLane(depthMM: previous, measuredAt: measured)]
                + (0..<3).map { _ in TreadLane() }
        } else {
            lanes = (0..<4).map { _ in TreadLane() }
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(position, forKey: .position)
        try c.encode(lanes, forKey: .lanes)
        try c.encode(notes, forKey: .notes)
        try c.encode(manufacturer, forKey: .manufacturer)
        try c.encode(model, forKey: .model)
        try c.encode(size, forKey: .size)
        try c.encode(dot, forKey: .dot)
    }
}

struct TireSet: Codable, Identifiable {
    var id: UUID
    var name: String
    var season: TireSeason
    var tires: [TireRecord]

    init(id: UUID = UUID(), name: String = "Tire set",
         season: TireSeason = .summer,
         tires: [TireRecord] = TirePosition.allCases.map { TireRecord(position: $0) }) {
        self.id = id
        self.name = name
        self.season = season
        self.tires = tires
    }

    func tire(at position: TirePosition) -> TireRecord {
        tires.first(where: { $0.position == position }) ?? TireRecord(position: position)
    }
}

struct CarProfile: Codable {
    var name: String = "My Car"
    var manufacturer: String = ""
    var model: String = ""
    var year: Int?
    var licensePlate: String = ""
    var odometerKM: Int = 0
    // Optional for decoding car profiles saved before this feature existed.
    var vin: String?
    var details: String?
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

struct GarageSnapshot: Codable, Identifiable {
    var id: UUID = UUID()
    var car: CarProfile
    var tireSets: [TireSet]
    var activeTireSetID: UUID
    var issues: [CarIssue]
    var service: ServiceReminder

    init() {
        let first = TireSet(name: "My tires")
        car = CarProfile()
        tireSets = [first]
        activeTireSetID = first.id
        issues = []
        service = ServiceReminder()
    }

    var activeIssueCount: Int { issues.filter { !$0.isResolved }.count }
    var activeTireSet: TireSet? {
        tireSets.first(where: { $0.id == activeTireSetID }) ?? tireSets.first
    }

    // Compatibility with the widget and other consumers of the former tires property.
    var tires: [TireRecord] { activeTireSet?.tires ?? [] }
    func tire(at position: TirePosition) -> TireRecord {
        activeTireSet?.tire(at: position) ?? TireRecord(position: position)
    }

    private enum CodingKeys: String, CodingKey {
        case id, car, tireSets, activeTireSetID, tires, issues, service
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        car = try c.decodeIfPresent(CarProfile.self, forKey: .car) ?? CarProfile()
        issues = try c.decodeIfPresent([CarIssue].self, forKey: .issues) ?? []
        service = try c.decodeIfPresent(ServiceReminder.self, forKey: .service) ?? ServiceReminder()

        if let existingSets = try c.decodeIfPresent([TireSet].self, forKey: .tireSets),
           !existingSets.isEmpty {
            tireSets = existingSets
            let selected = try c.decodeIfPresent(UUID.self, forKey: .activeTireSetID)
            activeTireSetID = existingSets.contains(where: { $0.id == selected })
                ? selected! : existingSets[0].id
        } else {
            // Carry all four tires and their measurements forward from v1/v2.
            let legacy = try c.decodeIfPresent([TireRecord].self, forKey: .tires) ?? []
            let first = TireSet(name: "My tires", tires: TirePosition.allCases.map { position in
                legacy.first(where: { $0.position == position }) ?? TireRecord(position: position)
            })
            tireSets = [first]
            activeTireSetID = first.id
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(car, forKey: .car)
        try c.encode(tireSets, forKey: .tireSets)
        try c.encode(activeTireSetID, forKey: .activeTireSetID)
        try c.encode(issues, forKey: .issues)
        try c.encode(service, forKey: .service)
    }
}

struct GarageArchive: Codable {
    var cars: [GarageSnapshot]
    var selectedCarID: UUID

    init() {
        let first = GarageSnapshot()
        cars = [first]
        selectedCarID = first.id
    }

    var selected: GarageSnapshot {
        cars.first(where: { $0.id == selectedCarID }) ?? cars[0]
    }

    private enum CodingKeys: String, CodingKey { case cars, selectedCarID }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = try c.decode([GarageSnapshot].self, forKey: .cars)
        cars = decoded.isEmpty ? [GarageSnapshot()] : decoded
        let chosen = try c.decode(UUID.self, forKey: .selectedCarID)
        selectedCarID = cars.contains(where: { $0.id == chosen }) ? chosen : cars[0].id
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(cars, forKey: .cars)
        try c.encode(selectedCarID, forKey: .selectedCarID)
    }
}

enum GaragePersistence {
    static let appGroup = "group.dev.kaskader.mycar"
    static let key = "garage.snapshot.v1"
    static let archiveKey = "garage.archive.v2"

    static var sharedDefaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func loadArchive() -> GarageArchive {
        if let data = sharedDefaults?.data(forKey: archiveKey)
             ?? UserDefaults.standard.data(forKey: archiveKey),
           let saved = try? JSONDecoder().decode(GarageArchive.self, from: data) {
            return saved
        }
        if let old = sharedDefaults?.data(forKey: key)
             ?? UserDefaults.standard.data(forKey: key),
           let car = try? JSONDecoder().decode(GarageSnapshot.self, from: old) {
            var archive = GarageArchive()
            archive.cars = [car]
            archive.selectedCarID = car.id
            return archive
        }
        return GarageArchive()
    }

    static func load() -> GarageSnapshot { loadArchive().selected }

    /// Widgets cannot access the main application's standard defaults.
    static func loadForWidget() -> GarageSnapshot? {
        guard let defaults = sharedDefaults else { return nil }
        if let data = defaults.data(forKey: archiveKey),
           let archive = try? JSONDecoder().decode(GarageArchive.self, from: data) {
            return archive.selected
        }
        if let data = defaults.data(forKey: key) {
            return try? JSONDecoder().decode(GarageSnapshot.self, from: data)
        }
        return nil
    }

    @discardableResult
    static func saveArchive(_ archive: GarageArchive) -> Bool {
        guard let data = try? JSONEncoder().encode(archive),
              let selected = try? JSONEncoder().encode(archive.selected) else { return false }
        UserDefaults.standard.set(data, forKey: archiveKey)
        UserDefaults.standard.set(selected, forKey: key)
        sharedDefaults?.set(data, forKey: archiveKey)
        sharedDefaults?.set(selected, forKey: key)
        return true
    }

    @discardableResult
    static func save(_ snapshot: GarageSnapshot) -> Bool {
        var archive = loadArchive()
        if let index = archive.cars.firstIndex(where: { $0.id == snapshot.id }) {
            archive.cars[index] = snapshot
        } else {
            archive.cars.append(snapshot)
        }
        archive.selectedCarID = snapshot.id
        return saveArchive(archive)
    }
}
