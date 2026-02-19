//
//  InAppBrowser.swift
//  Papercut
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true

        let safariVC = SFSafariViewController(url: url, configuration: config)
        safariVC.preferredControlTintColor = .systemBlue
        safariVC.dismissButtonStyle = .close

        return safariVC
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Browser Sheet Modifier
struct BrowserSheet: ViewModifier {
    @Binding var url: URL?

    func body(content: Content) -> some View {
        content
            .sheet(item: $url) { url in
                SafariView(url: url)
                    .ignoresSafeArea()
            }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

extension View {
    func browserSheet(url: Binding<URL?>) -> some View {
        modifier(BrowserSheet(url: url))
    }
}
