import SwiftUI
import SwiftData

struct RootView: View {
    @State private var selection: UUID?

    var body: some View {
        NavigationSplitView {
            JobListView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
        } detail: {
            JobDetailColumn(selection: selection)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct JobDetailColumn: View {
    var selection: UUID?
    @Query(sort: \MeasureJob.updatedAt, order: .reverse) private var jobs: [MeasureJob]

    var body: some View {
        if let selection, let job = jobs.first(where: { $0.uuid == selection }) {
            JobDetailView(job: job)
        } else {
            ContentUnavailableView(
                Copy.emptyDetailTitle,
                systemImage: "rectangle.split.2x1",
                description: Text(Copy.emptyDetailMessage)
            )
        }
    }
}

struct JobListView: View {
    @Binding var selection: UUID?
    @Environment(\.modelContext) private var context
    @Query(sort: \MeasureJob.updatedAt, order: .reverse) private var jobs: [MeasureJob]
    @State private var query = ""
    @State private var showNew = false
    @State private var pendingDelete: MeasureJob?

    private var filtered: [MeasureJob] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return jobs }
        return jobs.filter {
            $0.displayName.localizedCaseInsensitiveContains(needle) || $0.notes.localizedCaseInsensitiveContains(needle)
        }
    }

    var body: some View {
        Group {
            if jobs.isEmpty {
                ContentUnavailableView {
                    Label(Copy.emptyJobsTitle, systemImage: "ruler")
                } description: {
                    Text(Copy.emptyJobsMessage)
                } actions: {
                    Button(Copy.newJob) { showNew = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List(selection: $selection) {
                    ForEach(filtered) { job in
                        JobRow(job: job)
                            .tag(job.uuid)
                            .swipeActions {
                                Button(Copy.delete, role: .destructive) { pendingDelete = job }
                            }
                    }
                }
                .listStyle(.insetGrouped)
                .overlay {
                    if filtered.isEmpty {
                        ContentUnavailableView.search
                    }
                }
            }
        }
        .navigationTitle(Copy.jobs)
        .searchable(text: $query, prompt: Copy.customer)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNew = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Copy.newJob)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text(Copy.localOnly)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .sheet(isPresented: $showNew) {
            JobFormSheet(title: Copy.newJob, customer: "", notes: "") { customer, notes in
                let job = MeasureJob(customerName: customer, notes: notes)
                context.insert(job)
                try? context.save()
                selection = job.uuid
            }
        }
        .confirmationDialog(
            "刪除這份工作？",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(Copy.delete, role: .destructive) {
                if let job = pendingDelete {
                    if selection == job.uuid { selection = nil }
                    context.delete(job)
                    try? context.save()
                }
                pendingDelete = nil
            }
            Button(Copy.cancel, role: .cancel) { pendingDelete = nil }
        } message: {
            Text("工作內的玻璃、相片及尺寸會一併刪除，且只影響這部裝置。")
        }
    }
}

private struct JobRow: View {
    var job: MeasureJob

    var body: some View {
        let summary = JobAreaSummary(panes: job.orderedPanes)
        VStack(alignment: .leading, spacing: 4) {
            Text(job.displayName)
                .font(.headline)
            Text(MeasureFormat.dateTime(job.updatedAt))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                if summary.hasAbsoluteArea {
                    Text(MeasureFormat.area(summary.grand))
                        .monospacedDigit()
                    if summary.estimateCount > 0 {
                        Text("含估算")
                            .foregroundStyle(Theme.estimate)
                    }
                }
                if summary.pending > 0 {
                    Text(Copy.pendingPieces(summary.pending))
                        .foregroundStyle(Theme.pending)
                }
                if !summary.hasAbsoluteArea && summary.pending == 0 {
                    Text("未有玻璃")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
