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

// The cat alone, standing where a dry wordmark used to sit. No tile around
// it: the warm wash behind the bar already carries the colour.
struct BrandMark: View {
    var body: some View {
        Image(systemName: "cat")
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.brand)
            .accessibilityLabel(Text(verbatim: "CopyKat"))
    }
}
