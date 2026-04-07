import PhotosUI
import SwiftUI
import TimelordKit

struct BrandingSettingsView: View {
    @AppStorage("businessName") private var businessName = ""
    @AppStorage("businessAddress") private var businessAddress = ""
    @AppStorage("businessLogoData") private var logoData: Data = Data()

    @State private var selectedPhotoItem: PhotosPickerItem?

    private var logoImage: Image? {
        guard !logoData.isEmpty,
              let uiImage = UIImage(data: logoData) else { return nil }
        return Image(uiImage: uiImage)
    }

    var body: some View {
        Form {
            businessInfoSection
            logoSection
            previewSection
        }
        .navigationTitle("Invoice Branding")
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task { await loadPhoto(from: newItem) }
        }
    }

    // MARK: - Business Info

    private var businessInfoSection: some View {
        Section {
            TextField("Business Name", text: $businessName)
            TextField("Business Address", text: $businessAddress, axis: .vertical)
                .lineLimit(3...6)
        } header: {
            Text("Business Details")
        } footer: {
            Text("This information appears on your invoices.")
        }
    }

    // MARK: - Logo

    private var logoSection: some View {
        Section("Logo") {
            HStack {
                if let logoImage {
                    logoImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                        .frame(width: 60, height: 60)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }

                Spacer()

                VStack(spacing: 8) {
                    let hasLogo = !logoData.isEmpty
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        Text(hasLogo ? "Change Logo" : "Choose Logo")
                    }

                    if !logoData.isEmpty {
                        Button("Remove", role: .destructive) {
                            logoData = Data()
                            selectedPhotoItem = nil
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        Section("Invoice Preview") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    if let logoImage {
                        logoImage
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(businessName.isEmpty ? "Your Business Name" : businessName)
                            .font(.headline)
                            .foregroundStyle(businessName.isEmpty ? .secondary : .primary)
                        Text(businessAddress.isEmpty ? "123 Main St\nCity, State" : businessAddress)
                            .font(.caption)
                            .foregroundStyle(businessAddress.isEmpty ? .secondary : .primary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("INVOICE")
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                        Text("#INV-001")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Divider()

                Text("This is a preview of how your branding will appear on invoices.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Actions

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }

        // Resize to keep storage small
        guard let uiImage = UIImage(data: data) else { return }
        let maxDimension: CGFloat = 256
        let scale = min(maxDimension / uiImage.size.width, maxDimension / uiImage.size.height, 1.0)
        let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            uiImage.draw(in: CGRect(origin: .zero, size: newSize))
        }

        if let compressed = resized.jpegData(compressionQuality: 0.7) {
            logoData = compressed
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        BrandingSettingsView()
    }
}
#endif
