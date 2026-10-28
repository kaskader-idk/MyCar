import SwiftUI

private enum IssueSort: String, CaseIterable, Identifiable {
    case priority, newest, oldest

    var id: String { rawValue }
    var label: LocalizedStringKey {
        switch self {
        case .priority: return "Priority (lowest first)"
        case .newest: return "Newest first"
        case .oldest: return "Oldest first"
        }
    }
}

struct ProblemsView: View {
    @ObservedObject var store: GarageStore
    @State private var sorting: IssueSort = .priority
    @State private var showResolved = false
    @State private var showNew = false
    @State private var editing: CarIssue?

    private var issues: [CarIssue] {
        store.snapshot.issues
            .filter { showResolved || !$0.isResolved }
            .sorted { lhs, rhs in
                if lhs.isResolved != rhs.isResolved { return !lhs.isResolved }
                switch sorting {
                case .priority:
                    if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                    return lhs.createdAt > rhs.createdAt
                case .newest: return lhs.createdAt > rhs.createdAt
                case .oldest: return lhs.createdAt < rhs.createdAt
                }
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Problems").font(.largeTitle.bold())
                        Text("Track issues and fix the most important ones first.")
                            .font(.subheadline)
                            .foregroundStyle(CarTheme.muted)
                    }
                    Spacer()
                    Button { showNew = true } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                            .padding(14)
                            .background(CarTheme.accent, in: Circle())
                    }
                    .accessibilityLabel("Add problem")
                }
                Panel {
                    VStack(spacing: 14) {
                        HStack {
                            Text("Sort by").foregroundStyle(CarTheme.muted)
                            Spacer()
                            Picker("Sort by", selection: $sorting) {
                                ForEach(IssueSort.allCases) { option in
                                    Text(option.label).tag(option)
                                }
                            }
                            .tint(.white)
                        }
                        Toggle("Show resolved", isOn: $showResolved)
                            .tint(CarTheme.accent)
                    }
                }
                if issues.isEmpty {
                    EmptyPanel(symbol: "checkmark.shield.fill",
                               title: "No problems to show",
                               subtitle: "Add a problem to keep track of repairs.")
                }
                ForEach(issues) { issue in
                    Panel {
                        HStack(alignment: .top, spacing: 13) {
                            Text("\(issue.priority)")
                                .font(.title2.bold().monospacedDigit())
                                .foregroundStyle(issue.isResolved ? CarTheme.success :
                                    (issue.priority <= 2 ? CarTheme.danger : CarTheme.warning))
                                .frame(width: 46, height: 50)
                                .background(CarTheme.raised, in: RoundedRectangle(cornerRadius: 12))
                                .accessibilityLabel("Priority \(issue.priority)")
                            VStack(alignment: .leading, spacing: 8) {
                                Text(issue.title)
                                    .font(.headline)
                                    .foregroundStyle(issue.isResolved ? CarTheme.muted : .white)
                                if !issue.details.isEmpty {
                                    Text(issue.details)
                                        .font(.subheadline)
                                        .foregroundStyle(CarTheme.muted)
                                        .lineLimit(3)
                                }
                                HStack {
                                    Text(issue.createdAt, format: .dateTime.day().month().year())
                                        .font(.caption)
                                        .foregroundStyle(CarTheme.muted)
                                    if issue.isResolved {
                                        Label("Resolved", systemImage: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(CarTheme.success)
                                    }
                                }
                            }
                            Spacer(minLength: 0)
                            Menu {
                                Button("Edit", systemImage: "pencil") { editing = issue }
                                Button(issue.isResolved ? "Reopen" : "Mark resolved",
                                       systemImage: issue.isResolved ? "arrow.uturn.backward" : "checkmark") {
                                    store.setIssueResolved(issue, resolved: !issue.isResolved)
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    store.deleteIssue(issue.id)
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.headline)
                                    .foregroundStyle(CarTheme.muted)
                                    .frame(width: 32, height: 36)
                                    .contentShape(Rectangle())
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Problems")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNew) { IssueEditorView(store: store, issue: nil) }
        .sheet(item: $editing) { issue in IssueEditorView(store: store, issue: issue) }
        .carPage()
    }
}

struct IssueEditorView: View {
    @ObservedObject var store: GarageStore
    let issue: CarIssue?
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var details: String
    @State private var priority: Int

    init(store: GarageStore, issue: CarIssue?) {
        self.store = store
        self.issue = issue
        _title = State(initialValue: issue?.title ?? "")
        _details = State(initialValue: issue?.details ?? "")
        _priority = State(initialValue: issue?.priority ?? 3)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Issue") {
                    TextField("Title", text: $title)
                    TextField("Description (optional)", text: $details, axis: .vertical)
                        .lineLimit(3...7)
                }
                Section {
                    Stepper(value: $priority, in: 1...99) {
                        HStack {
                            Text("Priority")
                            Spacer()
                            Text("\(priority)").font(.title3.bold().monospacedDigit())
                        }
                    }
                    Text("Lower number = higher priority (1 is highest).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CarTheme.background)
            .navigationTitle(issue == nil ? "Add problem" : "Edit problem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = issue ?? CarIssue(title: title)
                        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.priority = priority
                        store.upsertIssue(updated)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
