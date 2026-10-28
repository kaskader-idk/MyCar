import SwiftUI

struct TiresView: View {
    @ObservedObject var store: GarageStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Tread depth")
                        .font(.largeTitle.bold())
                    Text("Select a tire to measure every tread groove.")
                        .font(.subheadline)
                        .foregroundStyle(CarTheme.muted)
                }

                Panel {
                    VStack(spacing: 10) {
                        Text("FRONT")
                            .font(.caption2.bold())
                            .tracking(2)
                            .foregroundStyle(CarTheme.muted)
                        vehicleDiagram
                        Text("REAR")
                            .font(.caption2.bold())
                            .tracking(2)
                            .foregroundStyle(CarTheme.muted)
                    }
                }

                SectionLabel(title: "Measurements", symbol: "ruler")
                ForEach(TirePosition.allCases) { position in
                    NavigationLink {
                        TireDetailView(store: store, position: position)
                    } label: {
                        tireRow(position)
                    }
                    .buttonStyle(.plain)
                }

                Text("The lowest measured groove is shown for each tire.")
                    .font(.caption)
                    .foregroundStyle(CarTheme.muted)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Tires")
        .navigationBarTitleDisplayMode(.inline)
        .carPage()
    }

    private var vehicleDiagram: some View {
        ZStack {
            // Simplified top-down car shape, leaving space for four tappable wheels.
            RoundedRectangle(cornerRadius: 43)
                .fill(LinearGradient(colors: [
                    Color(red: 0.19, green: 0.29, blue: 0.44),
                    Color(red: 0.09, green: 0.14, blue: 0.23)
                ], startPoint: .top, endPoint: .bottom))
                .frame(width: 147, height: 297)
                .overlay {
                    RoundedRectangle(cornerRadius: 43)
                        .stroke(.white.opacity(0.15), lineWidth: 2)
                }
                .overlay {
                    VStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 19)
                            .fill(CarTheme.background.opacity(0.65))
                            .frame(width: 99, height: 66)
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(.white.opacity(0.13), lineWidth: 2)
                            .frame(width: 105, height: 79)
                        Spacer()
                        RoundedRectangle(cornerRadius: 16)
                            .fill(CarTheme.background.opacity(0.55))
                            .frame(width: 97, height: 57)
                    }
                    .padding(.vertical, 20)
                }
            VStack {
                axle(left: .frontLeft, right: .frontRight)
                Spacer()
                axle(left: .rearLeft, right: .rearRight)
            }
            .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 340)
    }

    private func axle(left: TirePosition, right: TirePosition) -> some View {
        HStack {
            tireLink(left)
            Spacer(minLength: 125)
            tireLink(right)
        }
    }

    private func tireLink(_ position: TirePosition) -> some View {
        let tire = store.snapshot.tire(at: position)
        return NavigationLink {
            TireDetailView(store: store, position: position)
        } label: {
            VStack(spacing: 7) {
                MiniTireArtwork(grooves: tire.lanes.count)
                    .frame(width: 46, height: 84)
                if let depth = tire.treadDepthMM {
                    Text(depth, format: .number.precision(.fractionLength(1)))
                        .font(.caption.bold())
                    + Text(" mm").font(.caption2)
                } else {
                    Text("—").font(.caption.bold())
                }
            }
            .frame(minWidth: 62, minHeight: 110)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(position.localizationKey)))
    }

    private func tireRow(_ position: TirePosition) -> some View {
        let tire = store.snapshot.tire(at: position)
        return HStack(spacing: 13) {
            MiniTireArtwork(grooves: tire.lanes.count)
                .frame(width: 31, height: 57)
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(position.localizationKey))
                    .font(.headline)
                Text("\(tire.measuredLaneCount)/\(tire.lanes.count) grooves measured")
                    .font(.caption)
                    .foregroundStyle(CarTheme.muted)
            }
            Spacer()
            if let depth = tire.treadDepthMM {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(depth, format: .number.precision(.fractionLength(1)))
                        .font(.title3.bold().monospacedDigit())
                    Text("mm · min.")
                        .font(.caption2)
                        .foregroundStyle(CarTheme.muted)
                }
            } else {
                Text("Not measured")
                    .font(.subheadline)
                    .foregroundStyle(CarTheme.muted)
            }
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(CarTheme.muted)
        }
        .padding(15)
        .background(CarTheme.surface, in: RoundedRectangle(cornerRadius: 19))
    }
}

private struct MiniTireArtwork: View {
    let grooves: Int

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<max(1, min(grooves, 12)), id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CarTheme.raised)
                        .overlay {
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(.white.opacity(0.28), lineWidth: 0.6)
                        }
                }
            }
            .padding(5)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(CarTheme.accent.opacity(0.85), lineWidth: 1.5)
            }
        }
    }
}

private struct GrooveDraft: Identifiable {
    var id: UUID
    var text: String
    var originalValue: Double?
    var measuredAt: Date?

    init(_ lane: TreadLane) {
        id = lane.id
        text = lane.depthMM.map { String(format: "%.1f", $0) } ?? ""
        originalValue = lane.depthMM
        measuredAt = lane.measuredAt
    }

    var value: Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    var isValid: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || (value.map { $0.isFinite && (0...15).contains($0) } ?? false)
    }

    func stored() -> TreadLane {
        let newValue = value
        return TreadLane(id: id, depthMM: newValue,
                         measuredAt: newValue == nil ? nil :
                             (newValue == originalValue ? (measuredAt ?? .now) : .now))
    }
}

struct TireDetailView: View {
    @ObservedObject var store: GarageStore
    let position: TirePosition
    @Environment(\.dismiss) private var dismiss
    @State private var grooves: [GrooveDraft]
    @State private var notes: String
    @State private var pendingRemoval: UUID?

    init(store: GarageStore, position: TirePosition) {
        self.store = store
        self.position = position
        let tire = store.snapshot.tire(at: position)
        _grooves = State(initialValue: tire.lanes.map(GrooveDraft.init))
        _notes = State(initialValue: tire.notes)
    }

    private var canSave: Bool { grooves.allSatisfy(\.isValid) }
    private var minimumDepth: Double? { grooves.compactMap(\.value).min() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(LocalizedStringKey(position.localizationKey))
                        .font(.largeTitle.bold())
                    Text("Each groove has its own measurement.")
                        .font(.subheadline)
                        .foregroundStyle(CarTheme.muted)
                }

                Panel {
                    VStack(spacing: 15) {
                        HStack {
                            Label("Tire profile", systemImage: "circle.dotted.circle.fill")
                                .font(.headline)
                            Spacer()
                            Text("\(grooves.count) grooves")
                                .font(.caption.bold())
                                .foregroundStyle(CarTheme.muted)
                        }
                        // Wide tires with many grooves can scroll instead of shrinking tap targets.
                        ScrollView(.horizontal) {
                            HStack(spacing: 6) {
                                ForEach(Array(grooves.enumerated()), id: \.element.id) { index, groove in
                                    VStack(spacing: 9) {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(LinearGradient(colors: [
                                                Color(red: 0.24, green: 0.29, blue: 0.37),
                                                Color(red: 0.07, green: 0.10, blue: 0.16),
                                                Color(red: 0.24, green: 0.29, blue: 0.37)
                                            ], startPoint: .leading, endPoint: .trailing))
                                            .overlay {
                                                VStack(spacing: 9) {
                                                    ForEach(0..<12, id: \.self) { _ in
                                                        Capsule()
                                                            .fill(.white.opacity(0.12))
                                                            .frame(width: 24, height: 4)
                                                    }
                                                }
                                            }
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(CarTheme.accent.opacity(0.50), lineWidth: 1)
                                            }
                                            .frame(width: 55, height: 224)
                                        Text("\(index + 1)")
                                            .font(.caption.bold())
                                        Text(groove.value.map { String(format: "%.1f", $0) } ?? "—")
                                            .font(.caption.bold().monospacedDigit())
                                            .foregroundStyle(CarTheme.accent)
                                        Text("mm")
                                            .font(.caption2)
                                            .foregroundStyle(CarTheme.muted)
                                    }
                                    .frame(width: 55)
                                }
                            }
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity)
                        }
                        .scrollIndicators(.hidden)
                        Text("Grooves are ordered from left to right in the diagram.")
                            .font(.caption)
                            .foregroundStyle(CarTheme.muted)
                            .multilineTextAlignment(.center)
                    }
                }

                Panel {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 3) {
                                SectionLabel(title: "Tread grooves", symbol: "ruler")
                                Text("Depth in millimeters")
                                    .font(.caption)
                                    .foregroundStyle(CarTheme.muted)
                            }
                            Spacer()
                            Button {
                                requestRemoval(grooves.last?.id)
                            } label: {
                                Image(systemName: "minus")
                                    .frame(width: 33, height: 33)
                            }
                            .disabled(grooves.count <= 1)
                            .accessibilityLabel("Remove last groove")
                            .buttonStyle(.bordered)
                            Button {
                                if grooves.count < 12 {
                                    grooves.append(GrooveDraft(TreadLane()))
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .frame(width: 33, height: 33)
                            }
                            .disabled(grooves.count >= 12)
                            .accessibilityLabel("Add groove")
                            .buttonStyle(.borderedProminent)
                        }

                        ForEach(Array(grooves.enumerated()), id: \.element.id) { index, groove in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 11) {
                                    Text("\(index + 1)")
                                        .font(.headline.monospacedDigit())
                                        .foregroundStyle(CarTheme.accent)
                                        .frame(width: 28, height: 40)
                                        .background(CarTheme.raised, in: RoundedRectangle(cornerRadius: 9))
                                    Text("Groove")
                                        .font(.subheadline.weight(.medium))
                                    Spacer(minLength: 2)
                                    TextField("—", text: $grooves[index].text)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .font(.title3.bold().monospacedDigit())
                                        .frame(minWidth: 58, maxWidth: 95)
                                        .padding(.vertical, 9)
                                        .padding(.horizontal, 10)
                                        .background(CarTheme.raised, in: RoundedRectangle(cornerRadius: 10))
                                        .accessibilityLabel("Depth in millimeters")
                                    Text("mm")
                                        .font(.caption)
                                        .foregroundStyle(CarTheme.muted)
                                    Button {
                                        requestRemoval(groove.id)
                                    } label: {
                                        Image(systemName: "minus.circle")
                                            .foregroundStyle(CarTheme.muted)
                                            .frame(width: 26, height: 35)
                                    }
                                    .disabled(grooves.count <= 1)
                                    .accessibilityLabel("Remove groove")
                                }
                                if !groove.isValid {
                                    Text("Enter a value between 0 and 15 mm.")
                                        .font(.caption)
                                        .foregroundStyle(CarTheme.danger)
                                }
                            }
                            if index < grooves.count - 1 {
                                Divider().overlay(CarTheme.raised)
                            }
                        }

                        Divider().overlay(CarTheme.raised)
                        HStack {
                            Text("Minimum measured depth")
                                .font(.subheadline)
                                .foregroundStyle(CarTheme.muted)
                            Spacer()
                            if let depth = minimumDepth {
                                Text(depth, format: .number.precision(.fractionLength(1)))
                                    .font(.title3.bold().monospacedDigit())
                                Text("mm")
                                    .foregroundStyle(CarTheme.muted)
                            } else {
                                Text("—")
                                    .foregroundStyle(CarTheme.muted)
                            }
                        }
                    }
                }

                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Notes").font(.headline)
                        TextField("Optional tire notes", text: $notes, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(12)
                            .background(CarTheme.raised, in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                Button {
                    store.updateTire(position: position, lanes: grooves.map { $0.stored() },
                                     notes: notes.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                } label: {
                    Label("Save measurements", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canSave)

                Text("Empty fields mean a groove has not been measured.")
                    .font(.caption)
                    .foregroundStyle(CarTheme.muted)
            }
            .padding(20)
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

    private func requestRemoval(_ id: UUID?) {
        guard let id, grooves.count > 1, let target = grooves.first(where: { $0.id == id }) else {
            return
        }
        if target.value != nil || !target.text.isEmpty {
            pendingRemoval = id
        } else {
            remove(id)
        }
    }

    private func remove(_ id: UUID) {
        guard grooves.count > 1 else { return }
        grooves.removeAll(where: { $0.id == id })
    }
}
