import SwiftUI

struct EditProfileSheet: View {
    @State private var auth = AuthService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var firstName: String = ""
    @State private var fullName: String = ""
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Full name", text: $fullName)
                        .textContentType(.name)
                }

                Section {
                    Text("This is how Scan to Cart greets you on the home screen.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            saving = true
                            await auth.updateProfile(firstName: firstName, fullName: fullName)
                            saving = false
                            dismiss()
                        }
                    }
                    .disabled(saving)
                }
            }
            .onAppear {
                if case .signedIn(let profile) = auth.state {
                    firstName = profile.firstName ?? ""
                    fullName = profile.fullName ?? ""
                }
            }
        }
    }
}
