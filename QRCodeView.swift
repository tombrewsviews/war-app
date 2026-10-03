import SwiftUI
import CoreImage.CIFilterBuiltins

/// Renders a scannable QR code for any short string (e.g. a MESH contact code).
struct QRCodeView: View {
    let content: String

    var body: some View {
        if let image = Self.generate(from: content) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.15))
                .overlay(
                    Image(systemName: "qrcode")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                )
        }
    }

    private static func generate(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    QRCodeView(content: "H7K2-9QXM")
        .frame(width: 200, height: 200)
        .padding()
}
