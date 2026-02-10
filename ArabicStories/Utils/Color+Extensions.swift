//
//  Color+Extensions.swift
//  Hikaya
//  App color palette and extensions
//

import SwiftUI

extension Color {
    // MARK: - Brand Colors
    
    /// Teal - Primary brand color
    static let hikayaTeal = Color(red: 0.2, green: 0.6, blue: 0.6)
    
    /// Orange - Accent color
    static let hikayaOrange = Color(red: 0.95, green: 0.5, blue: 0.2)
    
    /// Cream - Background color
    static let hikayaCream = Color(red: 0.98, green: 0.96, blue: 0.94)
    
    /// Sand - Secondary background
    static let hikayaSand = Color(red: 0.94, green: 0.91, blue: 0.87)
    
    /// Deep Teal - Dark variant
    static let hikayaDeepTeal = Color(red: 0.1, green: 0.4, blue: 0.4)
    
    /// Light Orange - Light variant
    static let hikayaLightOrange = Color(red: 1.0, green: 0.85, blue: 0.7)
    
    // MARK: - Semantic Colors
    
    static var hikayaBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
                : UIColor(red: 0.98, green: 0.96, blue: 0.94, alpha: 1.0)
        })
    }
    
    static var hikayaCardBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.18, green: 0.18, blue: 0.2, alpha: 1.0)
                : .systemBackground
        })
    }
    
    // MARK: - Difficulty Colors
    
    static func difficultyColor(_ level: Int) -> Color {
        switch level {
        case 1: return .green
        case 2: return .hikayaTeal
        case 3: return .blue
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }
}

// MARK: - Shimmer Effect Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .white.opacity(0.5),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Arabic Font Support

extension Font {
    static func arabic(_ size: CGFloat, weight: Weight = .regular) -> Font {
        // Use Noto Naskh Arabic or fallback to system
        if let descriptor = UIFontDescriptor
            .preferredFontDescriptor(withTextStyle: .body)
            .withDesign(.serif) {
            return Font(UIFont(descriptor: descriptor, size: size) as CTFont)
        }
        return .system(size: size, weight: weight, design: .serif)
    }
}

// MARK: - View Extensions

extension View {
    func hikayaCardStyle() -> some View {
        self
            .background(Color.hikayaCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}
