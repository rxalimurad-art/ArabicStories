//
//  ImageCache.swift
//  Arabicly
//  Image caching utility using URLCache for better performance
//

import SwiftUI

/// Image cache manager using URLCache for disk and memory caching
class ImageCache {
    static let shared = ImageCache()
    
    private let urlCache: URLCache
    private let imageCache = NSCache<NSString, UIImage>()
    
    init() {
        // Configure URLCache: 50MB memory, 100MB disk
        let memoryCapacity = 50 * 1024 * 1024  // 50 MB
        let diskCapacity = 100 * 1024 * 1024   // 100 MB
        urlCache = URLCache(memoryCapacity: memoryCapacity,
                           diskCapacity: diskCapacity,
                           diskPath: "image_cache")
        
        // Configure NSCache
        imageCache.countLimit = 100  // Max 100 images in memory
        imageCache.totalCostLimit = 50 * 1024 * 1024  // 50 MB
    }
    
    /// Get cached image for URL
    func image(for url: URL) -> UIImage? {
        let key = url.absoluteString as NSString
        
        // Check memory cache first
        if let cachedImage = imageCache.object(forKey: key) {
            return cachedImage
        }
        
        // Check URLCache (disk/memory)
        let request = URLRequest(url: url)
        if let cachedResponse = urlCache.cachedResponse(for: request),
           let image = UIImage(data: cachedResponse.data) {
            // Store in memory cache for faster access
            imageCache.setObject(image, forKey: key, cost: cachedResponse.data.count)
            return image
        }
        
        return nil
    }
    
    /// Store image in cache
    func store(image: UIImage, data: Data, for url: URL, response: URLResponse) {
        let key = url.absoluteString as NSString
        
        // Store in memory cache
        imageCache.setObject(image, forKey: key, cost: data.count)
        
        // Store in URLCache
        let request = URLRequest(url: url)
        let cachedResponse = CachedURLResponse(response: response, data: data)
        urlCache.storeCachedResponse(cachedResponse, for: request)
    }
    
    /// Clear all caches
    func clearCache() {
        imageCache.removeAllObjects()
        urlCache.removeAllCachedResponses()
    }
}

// MARK: - Cached Async Image View

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url, !isLoading else { return }
        
        isLoading = true
        
        // Check cache first
        if let cachedImage = ImageCache.shared.image(for: url) {
            self.image = cachedImage
            isLoading = false
            return
        }
        
        // Download image
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let downloadedImage = UIImage(data: data) else {
                    isLoading = false
                    return
                }
                
                // Store in cache
                ImageCache.shared.store(image: downloadedImage, 
                                       data: data, 
                                       for: url, 
                                       response: response)
                
                await MainActor.run {
                    self.image = downloadedImage
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Simplified Cached Image View

struct CachedImage: View {
    let url: String?
    var contentMode: ContentMode = .fill
    
    var body: some View {
        Group {
            if let urlString = url, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } placeholder: {
                    Color(.systemGray5)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                }
            } else {
                Color(.systemGray5)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
        }
    }
}
