import SwiftUI

// The brand, sampled from the app icon rather than invented next to it:
// #FFB758 falling to #F48037. Orange is an identity color here, not a text
// color; body copy never renders in it.
extension Color {
    static let brand = Color(red: 0.957, green: 0.502, blue: 0.216)
    static let brandLight = Color(red: 1.0, green: 0.718, blue: 0.345)
}

extension LinearGradient {
    static let brand = LinearGradient(
        colors: [.brandLight, .brand],
        startPoint: .top,
        endPoint: .bottom
    )
}

// The app icon in miniature: the same gradient squircle and the same cat,
// standing where a dry wordmark used to sit.
struct BrandMark: View {
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: "cat.fill")
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(LinearGradient.brand, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .accessibilityLabel(Text(verbatim: "CopyKat"))
    }
}
