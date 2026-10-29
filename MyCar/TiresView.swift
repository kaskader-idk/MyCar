import SwiftUI

/// Colors are visual condition hints only, not legal tread-depth limits.
private enum TreadVisual {
    static func color(_ mm: Double?) -> Color {
        guard let mm else { return CarTheme.muted }
        if mm >= 5 { return CarTheme.success }
        if mm >= 3.5 { return .yellow }
        if mm >= 1.6 { return CarTheme.warning }
        return CarTheme.danger
    }
}

/// A single tire, divided into adjacent measurement channels with no card gaps.
/// Each channel shows a colored vertical bar proportional to its tread depth.
private struct ConnectedTreadView: View {
    let lanes: [TreadLane]
    var height: CGFloat = 158
    var showValues: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(lanes.enumerated()), id: \.element.id) { index, lane in
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .bottom) {
                            Rectangle()
                                .fill(LinearGradient(colors: [
                                    Color(red: 0.23, green: 0.29, blue: 0.39),
                                    CarTheme.background,
                                    Color(red: 0.20, green: 0.25, blue: 0.33)
                                ], startPoint: .leading, endPoint: .trailing))
                            VStack(spacing: 0) {
                                ForEach(0..<11, id: \.self) { _ in
                                    Capsule()
                                        .fill(.white.opacity(0.12))
                                        .frame(height: 2.5)
                                        .frame(maxHeight: .infinity)
                                        .padding(.horizontal, 3)
                                }
                            }
                            .padding(.vertical, 10)

                            if let mm = lane.depthMM {
                                Capsule()
                                    .fill(TreadVisual.color(mm))
                                    .frame(width: max(3, min(6, geo.size.width * 0.15)),
                                           height: max(6, (geo.size.height - 20) *
                                                min(max(CGFloat(mm) / 8, 0), 1)))
                                    .shadow(color: TreadVisual.color(mm).opacity(0.55), radius: 3)
                                    .padding(.bottom, 9)
                            } else {
                                Capsule().fill(CarTheme.muted.opacity(0.4))
                                    .frame(width: 3, height: 12)
                                    .padding(.bottom, 9)
                            }
                        }
                        .overlay {
                            Rectangle().stroke(.white.opacity(0.16), lineWidth: 0.5)
                        }
                    }
                    .frame(height: height)
                    if showValues {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(CarTheme.muted)
                        HStack(spacing: 1) {
                            if let mm = lane.depthMM {
                                Text(mm, format: .number.precision(.fractionLength(1)))
                                    .foregroundStyle(TreadVisual.color(mm))
                            } else {
                                Text("—").foregroundStyle(CarTheme.muted)
                            }
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .background(CarTheme.background.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(CarTheme.accent.opacity(0.7), lineWidth: 1.3)
        }
        .accessibilityElement(children: .contain)
    }
}

struct TiresView: View {
    @ObservedObject var store: GarageStore
    @State private var creatingSet = false
    @State private var editingSet: TireSet?
    @State private var removalPosition: TirePosition?

    private var set: TireSet? { store.snapshot.activeTireSet }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Tires").font(.largeTitle.bold())

                if let set {
                    Panel {
                        VStack(alignment: .leading, spacing: 13) {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Selected tire set")
                                        .font(.caption).foregroundStyle(CarTheme.muted)
                                    Text(set.name).font(.title3.bold()).lineLimit(2)
                                    Text(LocalizedStringKey(set.season.titleKey))
                                        .font(.caption).foregroundStyle(CarTheme.accent)
                                }
                                Spacer()
                                Button { editingSet = set } label: {
                                    Image(systemName: "pencil")
                                        .frame(width: 40, height: 40)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel("Edit tire set")
                            }

                            Menu {
                                ForEach(store.snapshot.tireSets) { item in
                                    Button {
                                        store.selectTireSet(item.id)
                                    } label: {
                                        if item.id == set.id {
                                            Label(item.name, systemImage: "checkmark")
                                        } else {
                                            Text(item.name)
                                        }
                                    }
                                }
                            } label: {
                                Label("Switch tire set", systemImage: "chevron.up.chevron.down")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            Button { creatingSet = true } label: {
                                Label("Add tire set", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    Text("FRONT")
                        .font(.caption.bold())
                        .tracking(2)
                        .foregroundStyle(CarTheme.muted)
                        .frame(maxWidth: .infinity)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                        GridItem(.flexible(), spacing: 12)], spacing: 14) {
                        ForEach([TirePosition.frontLeft, .frontRight, .rearLeft, .rearRight]) { position in
                            tireTile(set: set, position: position)
                        }
                    }
                    Text("REAR")
                        .font(.caption.bold())
                        .tracking(2)
                        .foregroundStyle(CarTheme.muted)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Tread depth status", systemImage: "ruler").font(.headline)
                        HStack(spacing: 11) {
                            legend("5+ mm", color: CarTheme.success)
                            legend("3.5+", color: .yellow)
                            legend("1.6+", color: CarTheme.warning)
                            legend("<1.6", color: CarTheme.danger)
                        }
                        Text("Colors are indicative only; requirements depend on tire type and local law.")
                            .font(.caption).foregroundStyle(CarTheme.muted)
                    }
                    .padding(16)
                    .background(CarTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Tires")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $creatingSet) { TireSetEditorView(store: store, existing: nil) }
        .sheet(item: $editingSet) { item in TireSetEditorView(store: store, existing: item) }
        .alert("Remove last groove?", isPresented: Binding(
            get: { removalPosition != nil },
            set: { if !$0 { removalPosition = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let removalPosition, let set {
                    store.changeGrooveCount(position: removalPosition, setID: set.id, change: -1)
                }
                removalPosition = nil
            }
            Button("Cancel", role: .cancel) { removalPosition = nil }
        } message: {
            Text("The last groove's measurement will be deleted.")
        }
        .carPage()
    }

    private func legend(_ label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.system(size: 10)).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func tireTile(set: TireSet, position: TirePosition) -> some View {
        let tire = set.tire(at: position)
        return VStack(spacing: 10) {
            NavigationLink {
                TireDetailView(store: store, setID: set.id, position: position)
            } label: {
                VStack(alignment: .leading, spacing: 9) {
                    Text(LocalizedStringKey(position.localizationKey))
                        .font(.subheadline.bold())
                    ConnectedTreadView(lanes: tire.lanes, height: 112)
                    Text(tire.size.isEmpty ? "Tire size not set" : tire.size)
                        .font(.caption.bold())
                        .foregroundStyle(CarTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if !tire.manufacturer.isEmpty || !tire.model.isEmpty {
                        Text([tire.manufacturer, tire.model].filter { !$0.isEmpty }.joined(separator: " "))
                            .font(.caption2)
                            .foregroundStyle(CarTheme.muted)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack {
                Button {
                    guard tire.lanes.count > 1 else { return }
                    if tire.lanes.last?.depthMM != nil {
                        removalPosition = position
                    } else {
                        store.changeGrooveCount(position: position, setID: set.id, change: -1)
                    }
                } label: {
                    Image(systemName: "minus").frame(maxWidth: .infinity)
                }
                .disabled(tire.lanes.count <= 1)
                .accessibilityLabel("Remove last groove")
                Button {
                    store.changeGrooveCount(position: position, setID: set.id, change: 1)
                } label: {
                    Image(systemName: "plus").frame(maxWidth: .infinity)
                }
                .disabled(tire.lanes.count >= 12)
                .accessibilityLabel("Add groove")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Text("\(tire.lanes.count) grooves")
                .font(.caption2).foregroundStyle(CarTheme.muted)
        }
        .padding(12)
        .background(CarTheme.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct TireSetEditorView: View {
    @ObservedObject var store: GarageStore
    let existing: TireSet?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var season: TireSeason
    @State private var confirmDelete = false

    init(store: GarageStore, existing: TireSet?) {
        self.store = store
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _season = State(initialValue: existing?.season ?? .summer)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tire set") {
                    TextField("Name (e.g. Winter 2026)", text: $name)
                    Picker("Tire type", selection: $season) {
                        ForEach(TireSeason.allCases) { type in
                            Text(LocalizedStringKey(type.titleKey)).tag(type)
                        }
                    }
                }
                Section {
                    Text("Each set has four separate tires. Open a wheel to edit its size, manufacturer, model, DOT and tread measurements.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if existing != nil && store.snapshot.tireSets.count > 1 {
                    Section {
                        Button("Delete tire set", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(CarTheme.background)
            .navigationTitle(existing == nil ? "Add tire set" : "Edit tire set")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let existing {
                            store.updateTireSet(id: existing.id, name: cleaned, season: season)
                        } else {
                            store.createTireSet(name: cleaned, season: season)
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("Delete tire set?", isPresented: $confirmDelete) {
                Button("Delete tire set", role: .destructive) {
                    if let existing { store.deleteTireSet(existing.id) }
                    dismiss()
                }
            } message: {
                Text("This deletes all four tires and their measurements in this set.")
            }
            .preferredColorScheme(.dark)
        }
    }
}

private struct GrooveDraft: Identifiable {
    let id: UUID
    var text: String
    let original: Double?
    let date: Date?

    init(_ lane: TreadLane) {
        id = lane.id
        text = lane.depthMM.map { String(format: "%.1f", $0) } ?? ""
        original = lane.depthMM
        date = lane.measuredAt
    }

    var value: Double? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return cleaned.isEmpty ? nil : Double(cleaned)
    }

    var isValid: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || (value.map { $0.isFinite && (0...15).contains($0) } ?? false)
    }

    func stored() -> TreadLane {
        let mm = value
        return TreadLane(id: id, depthMM: mm,
                         measuredAt: mm == nil ? nil : (mm == original ? (date ?? .now) : .now))
    }
}

struct TireDetailView: View {
    @ObservedObject var store: GarageStore
    let setID: UUID
    let position: TirePosition

    @Environment(\.dismiss) private var dismiss
    @State private var grooves: [GrooveDraft]
    @State private var notes: String
    @State private var manufacturer: String
    @State private var model: String
    @State private var size: String
    @State private var dot: String
    @State private var pendingRemoval: UUID?

    init(store: GarageStore, setID: UUID, position: TirePosition) {
        self.store = store
        self.setID = setID
        self.position = position
        let tire = store.snapshot.tireSets.first(where: { $0.id == setID })?
            .tire(at: position) ?? TireRecord(position: position)
        _grooves = State(initialValue: tire.lanes.map(GrooveDraft.init))
        _notes = State(initialValue: tire.notes)
        _manufacturer = State(initialValue: tire.manufacturer)
        _model = State(initialValue: tire.model)
        _size = State(initialValue: tire.size)
        _dot = State(initialValue: tire.dot)
    }

    private var valid: Bool { grooves.allSatisfy(\.isValid) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(LocalizedStringKey(position.localizationKey))
                    .font(.largeTitle.bold())
                Text("Each tread groove has its own measurement.")
                    .font(.subheadline).foregroundStyle(CarTheme.muted)

                Panel {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Tire profile", systemImage: "circle.dotted.circle")
                                .font(.headline)
                            Spacer()
                            Text("\(grooves.count)")
                                .font(.caption.bold())
                            Text("grooves")
                                .font(.caption).foregroundStyle(CarTheme.muted)
                        }
                        ConnectedTreadView(lanes: grooves.map { $0.stored() },
                                           height: 220, showValues: true)
                        Text("Grooves are arranged from left to right. Colored bars indicate depth.")
                            .font(.caption).foregroundStyle(CarTheme.muted)
                    }
                }

                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            SectionLabel(title: "Tread grooves", symbol: "ruler")
                            Spacer()
                            Button {
                                if grooves.count > 1 {
                                    let last = grooves.last!
                                    if last.value != nil { pendingRemoval = last.id }
                                    else { grooves.removeLast() }
                                }
                            } label: { Image(systemName: "minus") }
                                .disabled(grooves.count <= 1)
                                .accessibilityLabel("Remove last groove")
                                .buttonStyle(.bordered)
                            Button {
                                if grooves.count < 12 { grooves.append(GrooveDraft(TreadLane())) }
                            } label: { Image(systemName: "plus") }
                                .disabled(grooves.count >= 12)
                                .accessibilityLabel("Add groove")
                                .buttonStyle(.borderedProminent)
                        }
                        ForEach(Array(grooves.enumerated()), id: \.element.id) { index, groove in
                            HStack(spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.headline.monospacedDigit())
                                    .frame(width: 24)
                                Text("Groove").font(.subheadline)
                                Spacer()
                                TextField("—", text: $grooves[index].text)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .padding(10)
                                    .background(CarTheme.raised, in: RoundedRectangle(cornerRadius: 10))
                                Text("mm").foregroundStyle(CarTheme.muted)
                                Button {
                                    if groove.value != nil { pendingRemoval = groove.id }
                                    else { remove(groove.id) }
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(CarTheme.muted)
                                }
                                .disabled(grooves.count <= 1)
                                .accessibilityLabel("Remove groove")
                            }
                            if !groove.isValid {
                                Text("Enter a value between 0 and 15 mm.")
                                    .font(.caption).foregroundStyle(CarTheme.danger)
                            }
                            if index < grooves.count - 1 { Divider().overlay(CarTheme.raised) }
                        }
                        HStack {
                            Text("Minimum measured depth").foregroundStyle(CarTheme.muted)
                            Spacer()
                            if let minDepth = grooves.compactMap(\.value).min() {
                                Text(minDepth, format: .number.precision(.fractionLength(1)))
                                    .foregroundStyle(TreadVisual.color(minDepth))
                                Text("mm")
                            } else {
                                Text("—")
                            }
                        }
                    }
                }

                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(title: "Tire details", symbol: "info.circle")
                        field("Tire size", placeholder: "225/40 R18", value: $size)
                        field("Manufacturer", placeholder: "Bridgestone", value: $manufacturer)
                        field("Model", placeholder: "Turanza 6", value: $model)
                        field("DOT", placeholder: "e.g. 2424", value: $dot)
                        Text("Notes").font(.subheadline)
                        TextField("Optional tire notes", text: $notes, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(12)
                            .background(CarTheme.raised, in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                Button {
                    let record = TireRecord(position: position, lanes: grooves.map { $0.stored() },
                                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                                            manufacturer: manufacturer.trimmingCharacters(in: .whitespacesAndNewlines),
                                            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                                            size: size.trimmingCharacters(in: .whitespacesAndNewlines),
                                            dot: dot.trimmingCharacters(in: .whitespacesAndNewlines))
                    store.updateTire(record, in: setID)
                    dismiss()
                } label: {
                    Label("Save measurements", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!valid)
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Tire details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Remove groove?", isPresented: Binding(
            get: { pendingRemoval != nil },
            set: { if !$0 { pendingRemoval = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let pendingRemoval { remove(pendingRemoval) }
                pendingRemoval = nil
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: {
            Text("The measurement for this groove will be deleted.")
        }
        .carPage()
    }

    private func field(_ title: LocalizedStringKey, placeholder: String,
                       value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline)
            TextField(placeholder, text: value)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(CarTheme.raised, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func remove(_ id: UUID) {
        guard grooves.count > 1 else { return }
        grooves.removeAll(where: { $0.id == id })
    }
}
