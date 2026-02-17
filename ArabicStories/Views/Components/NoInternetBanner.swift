//
//  NoInternetBanner.swift
//  Arabicly
//  Banner displayed when internet connection is lost
//

import SwiftUI

struct NoInternetBanner: View {
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("No Internet Connection")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.9))
        }
        .offset(y: isVisible ? 0 : -100)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }
}

struct OfflineIndicator: View {
    let networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if !networkMonitor.isConnected {
                NoInternetBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: networkMonitor.isConnected)
    }
}

#Preview {
    NoInternetBanner()
}
