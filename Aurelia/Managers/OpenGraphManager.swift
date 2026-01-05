//
//  OpenGraphManager.swift
//  Aurelia
//
//  Created by Bryant Perkins on 1/4/25.
//

import AppKit
import Foundation

/// Fetches and caches OpenGraph images from URLs
@Observable
final class OpenGraphManager {
    static let shared = OpenGraphManager()

    private var imageCache: [String: NSImage] = [:]
    private var failedURLs: Set<String> = []
    private var inProgressURLs: Set<String> = []

    private init() {}

    /// Get cached image for URL, or nil if not yet fetched
    func cachedImage(for urlString: String) -> NSImage? {
        imageCache[urlString]
    }

    /// Check if URL failed to fetch (no OG image available)
    func hasFailed(_ urlString: String) -> Bool {
        failedURLs.contains(urlString)
    }

    /// Check if URL is currently being fetched
    func isFetching(_ urlString: String) -> Bool {
        inProgressURLs.contains(urlString)
    }

    /// Fetch OpenGraph image for a URL
    func fetchImage(for urlString: String) async {
        // Skip if already cached, failed, or in progress
        guard imageCache[urlString] == nil,
              !failedURLs.contains(urlString),
              !inProgressURLs.contains(urlString) else {
            return
        }

        // Validate URL
        guard let url = URL(string: urlString),
              urlString.hasPrefix("http://") || urlString.hasPrefix("https://") else {
            await MainActor.run { _ = failedURLs.insert(urlString) }
            return
        }

        await MainActor.run { _ = inProgressURLs.insert(urlString) }

        do {
            // Fetch the HTML content
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)

            // Check for valid response
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let html = String(data: data, encoding: .utf8) else {
                await MainActor.run {
                    inProgressURLs.remove(urlString)
                    _ = failedURLs.insert(urlString)
                }
                return
            }

            // Extract og:image URL
            if let ogImageURL = extractOGImageURL(from: html, baseURL: url) {
                // Fetch the image
                let imageRequest = URLRequest(url: ogImageURL)
                let (imageData, _) = try await URLSession.shared.data(for: imageRequest)

                // Create image on main thread to avoid sendable issues
                await MainActor.run {
                    if let image = NSImage(data: imageData) {
                        imageCache[urlString] = image
                    }
                    inProgressURLs.remove(urlString)
                }

                if imageCache[urlString] != nil {
                    return
                }
            }

            // No og:image found or failed to load
            await MainActor.run {
                inProgressURLs.remove(urlString)
                _ = failedURLs.insert(urlString)
            }
        } catch {
            await MainActor.run {
                inProgressURLs.remove(urlString)
                _ = failedURLs.insert(urlString)
            }
        }
    }

    /// Extract og:image URL from HTML
    private func extractOGImageURL(from html: String, baseURL: URL) -> URL? {
        // Look for og:image meta tag
        // Pattern: <meta property="og:image" content="..."/>
        let patterns = [
            #"<meta[^>]*property=[\"']og:image[\"'][^>]*content=[\"']([^\"']+)[\"']"#,
            #"<meta[^>]*content=[\"']([^\"']+)[\"'][^>]*property=[\"']og:image[\"']"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                let imageURLString = String(html[range])

                // Handle relative URLs
                if imageURLString.hasPrefix("//") {
                    return URL(string: "https:" + imageURLString)
                } else if imageURLString.hasPrefix("/") {
                    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
                    components?.path = imageURLString
                    return components?.url
                } else if imageURLString.hasPrefix("http") {
                    return URL(string: imageURLString)
                }
            }
        }

        return nil
    }

    /// Clear cache (useful for memory pressure)
    func clearCache() {
        imageCache.removeAll()
        failedURLs.removeAll()
    }
}
