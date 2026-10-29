import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: GarageStore
    @AppStorage("mycar.language") private var language = "system"
    @AppStorage("mycar.textSize") private var textSize = "normal"
    @State private var isEditingCar = false
    @State private var addingCar = false
    @State private var newCarName = ""
    @State private var confirmDelete = false

    var body: some View {
        Form {
            Section("My vehicles") {
                ForEach(store.cars) { car in
                    Button {
                        store.selectCar(car.id)
                    } label: {
                        HStack {
                            Text(car.car.name)
                            Spacer()
                            if car.id == store.snapshot.id { Image(systemName: "checkmark.circle.fill") }
                        }
                    }
                }
                Button("Add vehicle", systemImage: "plus") { addingCar = true }
                if store.cars.count > 1 {
                    Button("Delete selected vehicle", role: .destructive) { confirmDelete = true }
                }
            }
            Section("Vehicle") {
                LabeledContent("Name", value: store.snapshot.car.name)
                if !store.snapshot.car.licensePlate.isEmpty {
                    LabeledContent("License plate", value: store.snapshot.car.licensePlate)
                }
                LabeledContent("Odometer", value: "\(store.snapshot.car.odometerKM.formatted()) km")
                LabeledContent("VIN", value: store.snapshot.car.vin?.isEmpty == false
                    ? (store.snapshot.car.vin ?? "") : "Not entered")
                if let details = store.snapshot.car.details, !details.isEmpty {
                    Text(details).font(.subheadline).foregroundStyle(.secondary)
                }
                Button("Edit vehicle") { isEditingCar = true }
            }
            Section("Vehicle photo") {
                if let photo = store.carPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 145)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .accessibilityLabel("Current car photo")
                }
                VehiclePhotoButton(store: store)
                if store.carPhoto != nil {
                    Button("Remove car photo", role: .destructive) {
                        store.removeCarPhoto()
                    }
                }
            }
            Section("Appearance") {
                Picker("Language", selection: $language) {
                    Text("System default").tag("system")
                    Text("Deutsch").tag("de")
                    Text("English").tag("en")
                }
                Picker("Text size", selection: $textSize) {
                    Text("Normal").tag("normal")
                    Text("Large").tag("large")
                    Text("Extra large").tag("extra")
                }
            }
            Section("Widget sync") {
                if FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: GaragePersistence.appGroup
                ) != nil {
                    Label("Shared storage available", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Open MyCar after installation to refresh the widgets.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Label("App Group signing missing", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Widgets cannot access your car data without App Group entitlements. A sideloaded IPA may not preserve them.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Privacy") {
                Text("Vehicle data is stored locally and shared only with the MyCar widgets on this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditingCar) { VehicleEditorView(store: store) }
        .alert("Add vehicle", isPresented: $addingCar) {
            TextField("Vehicle name", text: $newCarName)
            Button("Add") {
                let title = newCarName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty { store.createCar(name: title) }
                newCarName = ""
            }
            Button("Cancel", role: .cancel) { newCarName = "" }
        } message: { Text("Enter a name for your new car.") }
        .confirmationDialog("Delete selected vehicle?", isPresented: $confirmDelete) {
            Button("Delete vehicle", role: .destructive) { store.deleteCurrentCar() }
        } message: { Text("This permanently deletes its tire sets, problems and service records.") }
        .carPage()
    }
}

struct VehicleEditorView: View {
    @ObservedObject var store: GarageStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var manufacturer: String
    @State private var model: String
    @State private var plate: String
    @State private var year: String
    @State private var odometer: String
    @State private var vin: String
    @State private var details: String

    init(store: GarageStore) {
        self.store = store
        let car = store.snapshot.car
        _name = State(initialValue: car.name)
        _manufacturer = State(initialValue: car.manufacturer)
        _model = State(initialValue: car.model)
        _plate = State(initialValue: car.licensePlate)
        _year = State(initialValue: car.year.map(String.init) ?? "")
        _odometer = State(initialValue: String(car.odometerKM))
        _vin = State(initialValue: car.vin ?? "")
        _details = State(initialValue: car.details ?? "")
    }

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && (Int(odometer).map { $0 >= 0 } ?? false)
        && (year.isEmpty || (Int(year).map { (1886...2100).contains($0) } ?? false))
        && (vin.isEmpty || vin.trimmingCharacters(in: .whitespacesAndNewlines).count == 17)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your car") {
                    TextField("Nickname", text: $name)
                    TextField("Manufacturer", text: $manufacturer)
                    TextField("Model", text: $model)
                    TextField("License plate", text: $plate)
                    TextField("Model year (optional)", text: $year)
                        .keyboardType(.numberPad)
                    TextField("Odometer (km)", text: $odometer)
                        .keyboardType(.numberPad)
                    TextField("VIN", text: $vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Car details", text: $details, axis: .vertical)
                        .lineLimit(3...7)
                }
                if !valid {
                    Text("Enter a name, valid mileage, model year and a 17-character VIN (or leave it empty).")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CarTheme.background)
            .navigationTitle("Edit vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let car = CarProfile(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            manufacturer: manufacturer.trimmingCharacters(in: .whitespacesAndNewlines),
                            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                            year: Int(year),
                            licensePlate: plate.trimmingCharacters(in: .whitespacesAndNewlines),
                            odometerKM: Int(odometer) ?? 0,
                            vin: vin.uppercased().trimmingCharacters(in: .whitespacesAndNewlines),
                            details: details.trimmingCharacters(in: .whitespacesAndNewlines))
                        store.updateCar(car)
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
