import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAILED: \(message)\n", stderr)
        exit(1)
    }
}

func approximatelyEqual(_ value: Double?, _ expected: Double) -> Bool {
    guard let value else { return false }
    return abs(value - expected) < 0.0001
}

// Brand-new tires have four independent, unmeasured tracks.
let fresh = TireRecord(position: .frontLeft)
require(fresh.lanes.count == 4, "New tire should have four editable grooves")
require(fresh.measuredLaneCount == 0, "Do not invent measurements")
require(fresh.treadDepthMM == nil, "No minimum before measuring")

// Every groove keeps its own value, and the minimum is used in overview/widgets.
let measured = TireRecord(position: .frontRight, lanes: [
    TreadLane(depthMM: 6.1),
    TreadLane(depthMM: 5.8),
    TreadLane(depthMM: 4.9),
    TreadLane(depthMM: nil)
], notes: "front axle")
require(measured.lanes.count == 4, "Four measurements retained")
require(measured.measuredLaneCount == 3, "Count only measured grooves")
require(approximatelyEqual(measured.treadDepthMM, 4.9), "Use least tread depth")

let encoder = JSONEncoder()
let decoder = JSONDecoder()
let roundtrip = try decoder.decode(TireRecord.self, from: encoder.encode(measured))
require(roundtrip.lanes.count == 4, "All grooves survive persistence")
require(approximatelyEqual(roundtrip.lanes[1].depthMM, 5.8), "Specific groove survives persistence")
require(roundtrip.lanes[2].id == measured.lanes[2].id, "Stable groove identity")
require(roundtrip.notes == "front axle", "Notes persist")

// Previous MyCar release stored only one treadDepthMM. Preserve it on upgrade.
let oldJSON = #"{"position":"rearLeft","treadDepthMM":5.3,"measuredAt":780000000,"notes":"from v1"}"#
let migrated = try decoder.decode(TireRecord.self, from: Data(oldJSON.utf8))
require(migrated.lanes.count == 4, "Migration creates four editable tracks")
require(approximatelyEqual(migrated.lanes[0].depthMM, 5.3), "Legacy value is preserved")
require(migrated.lanes[0].measuredAt != nil, "Legacy date is preserved")
require(migrated.lanes.dropFirst().allSatisfy { $0.depthMM == nil }, "Migration never invents depths")
require(migrated.notes == "from v1", "Legacy notes remain")
let newJSON = try encoder.encode(migrated)
let decodedAgain = try decoder.decode(TireRecord.self, from: newJSON)
require(approximatelyEqual(decodedAgain.treadDepthMM, 5.3),
        "Migrated record roundtrips")

let emptyJSON = #"{"position":"rearRight","treadDepthMM":null,"measuredAt":null,"notes":""}"#
let migratedEmpty = try decoder.decode(TireRecord.self, from: Data(emptyJSON.utf8))
require(migratedEmpty.lanes.count == 4 && migratedEmpty.measuredLaneCount == 0,
        "Unmeasured legacy record migrates without values")

print("Garage model checks passed (new grooves, min depth, persistence, legacy migration).")



// v2 snapshot had tires directly and no tireSets. Migrate measurements and car.
let oldSnapshotJSON = """
{
 "car":{"name":"Old car","manufacturer":"BMW","model":"320d","year":2010,
        "licensePlate":"RI-123","odometerKM":286000},
 "tires":[{"position":"frontLeft","lanes":[{"id":"00000000-0000-0000-0000-000000000001","depthMM":5.5,"measuredAt":780000000}],
           "notes":"old tire"}],
 "issues":[],
 "service":{"dueDate":null,"dueOdometerKM":null,"notes":"","lastServiceDate":null}
}
"""
let upgraded = try decoder.decode(GarageSnapshot.self, from: Data(oldSnapshotJSON.utf8))
require(upgraded.tireSets.count == 1, "Old snapshot becomes exactly one tire set")
require(approximatelyEqual(upgraded.tire(at: .frontLeft).treadDepthMM, 5.5),
        "Old tire measurement is migrated")
require(upgraded.car.name == "Old car", "Old vehicle data preserved")
require(upgraded.car.vin == nil, "New optional VIN works for old files")

var multiSet = upgraded
let second = TireSet(name: "Winter", season: .winter,
                     tires: [TireRecord(position: .frontLeft,
                            lanes: [TreadLane(depthMM: 6.3)],
                            manufacturer: "Michelin", model: "Alpin", size: "225/45 R17",
                            dot: "2525")])
multiSet.tireSets.append(second)
multiSet.activeTireSetID = second.id
require(approximatelyEqual(multiSet.tire(at: .frontLeft).treadDepthMM, 6.3),
        "Selecting tire set changes active readings")
require(multiSet.tire(at: .frontLeft).manufacturer == "Michelin",
        "Individual tire manufacturer is retained")
let serializedSets = try encoder.encode(multiSet)
let restoredSets = try decoder.decode(GarageSnapshot.self, from: serializedSets)
require(restoredSets.tireSets.count == 2, "All tire sets survive JSON roundtrip")
require(restoredSets.activeTireSetID == second.id, "Active tire set persists")
require(restoredSets.tire(at: .frontLeft).size == "225/45 R17", "Individual tire size persists")
require(restoredSets.tireSets[0].tire(at: .frontLeft).notes == "old tire",
        "Inactive set preserves its own tire details")
require(restoredSets.tireSets[1].season == .winter, "Season selection persists")

print("Tire set and backward-compatibility tests passed.")


// Multi-car migration and isolation checks.
let archived = try decoder.decode(GarageArchive.self, from: Data(
    #"{"cars":[{"id":"00000000-0000-0000-0000-000000000011","car":{"name":"First","manufacturer":"","model":"","licensePlate":"","odometerKM":123},"issues":[],"service":{"notes":""}},{"id":"00000000-0000-0000-0000-000000000022","car":{"name":"Second","manufacturer":"","model":"","licensePlate":"","odometerKM":456},"issues":[],"service":{"notes":""}}],"selectedCarID":"00000000-0000-0000-0000-000000000022"}"#.utf8))
require(archived.cars.count == 2, "Two vehicles are kept separate")
require(archived.selected.car.name == "Second", "Selected car restored")
let restoredArchive = try decoder.decode(GarageArchive.self, from: encoder.encode(archived))
require(restoredArchive.selected.car.odometerKM == 456, "Selected vehicle data persists")
require(restoredArchive.cars[0].car.odometerKM == 123, "Other vehicle stays unchanged")
var mutableArchive = restoredArchive
mutableArchive.selectedCarID = mutableArchive.cars[0].id
require(mutableArchive.selected.car.name == "First", "Car selection switches records")
print("Multi-car archive isolation checks passed.")
