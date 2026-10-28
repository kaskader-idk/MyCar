import SwiftUI

struct ServiceView: View {
    @ObservedObject var store: GarageStore
    @State private var showEditor = false

    private var reminder: ServiceReminder { store.snapshot.service }
    private var overdue: Bool {
        reminder.isOverdue(odometer: store.snapshot.car.odometerKM)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Service planner").font(.largeTitle.bold())
                Text("Keep upcoming maintenance in sight.")
                    .foregroundStyle(CarTheme.muted)

                if reminder.isConfigured {
                    Panel {
                        VStack(alignment: .leading, spacing: 14) {
                            Label(overdue ? "Service due" : "Next service", systemImage: "calendar.badge.clock")
                                .font(.headline)
                                .foregroundStyle(overdue ? CarTheme.danger : CarTheme.accent)
                            if let dueDate = reminder.dueDate {
                                Text(dueDate, format: .dateTime.day().month(.wide).year())
                                    .font(.title2.bold())
                                if let days = reminder.daysUntilDue() {
                                    if days < 0 {
                                        Text("\(abs(days)) days overdue")
                                            .foregroundStyle(CarTheme.danger)
                                    } else if days == 0 {
                                        Text("Due today")
                                            .foregroundStyle(CarTheme.warning)
                                    } else {
                                        Text("\(days) days remaining")
                                            .foregroundStyle(CarTheme.muted)
                                    }
                                }
                            }
                            if let km = reminder.dueOdometerKM {
                                Divider().overlay(CarTheme.raised)
                                HStack {
                                    Label("Due at", systemImage: "speedometer")
                                    Spacer()
                                    Text("\(km.formatted()) km").fontWeight(.bold)
                                }
                                if let distance = reminder.distanceUntilDue(odometer: store.snapshot.car.odometerKM) {
                                    Text(distance <= 0 ? "Mileage target reached" : "\(distance.formatted()) km remaining")
                                        .font(.subheadline)
                                        .foregroundStyle(distance <= 0 ? CarTheme.warning : CarTheme.muted)
                                }
                            }
                        }
                    }
                    if !reminder.notes.isEmpty {
                        Panel {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionLabel(title: "Service notes", symbol: "note.text")
                                Text(reminder.notes).foregroundStyle(CarTheme.muted)
                            }
                        }
                    }
                    if let lastDate = reminder.lastServiceDate {
                        Panel {
                            HStack {
                                Text("Last service")
                                Spacer()
                                Text(lastDate, format: .dateTime.day().month().year())
                                    .foregroundStyle(CarTheme.muted)
                            }
                        }
                    }
                } else {
                    EmptyPanel(symbol: "wrench.and.screwdriver.fill",
                               title: "No service reminder yet",
                               subtitle: "Add the next service date or mileage to see it in your widget.")
                }

                Button {
                    showEditor = true
                } label: {
                    Label(reminder.isConfigured ? "Edit reminder" : "Add reminder",
                          systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Panel {
                    Label("Add the MyCar Service widget to your Home Screen for a quick reminder.",
                          systemImage: "apps.iphone")
                        .font(.subheadline)
                        .foregroundStyle(CarTheme.muted)
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Service")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditor) { ServiceEditorView(store: store) }
        .carPage()
    }
}

struct ServiceEditorView: View {
    @ObservedObject var store: GarageStore
    @Environment(\.dismiss) private var dismiss
    @State private var hasDate: Bool
    @State private var date: Date
    @State private var hasMileage: Bool
    @State private var mileage: String
    @State private var notes: String
    @State private var hasLastDate: Bool
    @State private var lastDate: Date

    init(store: GarageStore) {
        self.store = store
        let service = store.snapshot.service
        _hasDate = State(initialValue: service.dueDate != nil)
        _date = State(initialValue: service.dueDate ?? .now)
        _hasMileage = State(initialValue: service.dueOdometerKM != nil)
        _mileage = State(initialValue: service.dueOdometerKM.map(String.init) ?? "")
        _notes = State(initialValue: service.notes)
        _hasLastDate = State(initialValue: service.lastServiceDate != nil)
        _lastDate = State(initialValue: service.lastServiceDate ?? .now)
    }

    private var validMileage: Bool {
        !hasMileage || (Int(mileage).map { $0 > 0 } ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Next service") {
                    Toggle("Remind by date", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Due date", selection: $date, displayedComponents: .date)
                    }
                    Toggle("Remind by mileage", isOn: $hasMileage)
                    if hasMileage {
                        TextField("Mileage in km", text: $mileage)
                            .keyboardType(.numberPad)
                        if !validMileage {
                            Text("Enter a valid positive mileage.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                Section("History") {
                    Toggle("Record last service", isOn: $hasLastDate)
                    if hasLastDate {
                        DatePicker("Last service", selection: $lastDate,
                                   in: ...Date(), displayedComponents: .date)
                    }
                }
                Section("Notes") {
                    TextField("e.g. Oil, filters, inspection", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CarTheme.background)
            .navigationTitle("Service reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = ServiceReminder(
                            dueDate: hasDate ? date : nil,
                            dueOdometerKM: hasMileage ? Int(mileage) : nil,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            lastServiceDate: hasLastDate ? lastDate : nil)
                        store.updateService(updated)
                        dismiss()
                    }
                    .disabled(!validMileage)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
