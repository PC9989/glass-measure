import SwiftUI

struct JobFormSheet: View {
    var title: String
    @State private var customer: String
    @State private var notes: String
    var onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    init(title: String, customer: String, notes: String, onSave: @escaping (String, String) -> Void) {
        self.title = title
        self.onSave = onSave
        _customer = State(initialValue: customer)
        _notes = State(initialValue: notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(Copy.customer) {
                    TextField(Copy.customerPlaceholder, text: $customer)
                        .font(.body)
                }
                Section(Copy.notes) {
                    TextField(Copy.notesPlaceholder, text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Text("名稱可留空。工作、相片及報告只儲存在這部裝置。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(Copy.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Copy.save) {
                        onSave(customer, notes)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
