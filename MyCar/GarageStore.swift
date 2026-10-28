import Foundation
import Combine
import WidgetKit

@MainActor
final class GarageStore: ObservableObject {
    @Published private(set) var snapshot: GarageSnapshot

    init() { snapshot = GaragePersistence.load() }

    private func commit(_ change: (inout GarageSnapshot) -> Void) {
        var updated = snapshot
        change(&updated)
        snapshot = updated
        GaragePersistence.save(updated)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func updateCar(_ car: CarProfile) {
        commit { $0.car = car }
    }

    func updateTire(position: TirePosition, lanes: [TreadLane], notes: String) {
        commit { snapshot in
            // Every groove has a stable ID so edits and removals stay attached to
            // the correct measurement rather than shifting data between grooves.
            let new = TireRecord(position: position, lanes: lanes, notes: notes)
            if let index = snapshot.tires.firstIndex(where: { $0.position == position }) {
                snapshot.tires[index] = new
            } else {
                snapshot.tires.append(new)
            }
        }
    }

    func upsertIssue(_ issue: CarIssue) {
        commit { snapshot in
            if let index = snapshot.issues.firstIndex(where: { $0.id == issue.id }) {
                snapshot.issues[index] = issue
            } else {
                snapshot.issues.append(issue)
            }
        }
    }

    func setIssueResolved(_ issue: CarIssue, resolved: Bool) {
        var updated = issue
        updated.isResolved = resolved
        updated.resolvedAt = resolved ? .now : nil
        upsertIssue(updated)
    }

    func deleteIssue(_ id: UUID) {
        commit { $0.issues.removeAll(where: { $0.id == id }) }
    }

    func updateService(_ service: ServiceReminder) {
        commit { $0.service = service }
    }
}
