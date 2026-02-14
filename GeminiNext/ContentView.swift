//
//  ContentView.swift
//  GeminiNext
//
//  Created by Jray on 2026/2/10.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: WebViewModel

    /// Tracks whether the initial page load has completed
    @State private var hasFinishedInitialLoad: Bool = false

    var body: some View {
        ZStack {
            GeminiWebView(viewModel: viewModel)
                .frame(minWidth: 800, minHeight: 600)

            // Branded splash screen for initial load (no error)
            if !hasFinishedInitialLoad && viewModel.errorMessage == nil {
                SplashView(isLoading: !viewModel.isPageReady)
                    .zIndex(1)
            }

            // Subtle top progress bar for subsequent navigations
            if hasFinishedInitialLoad && viewModel.isLoading && viewModel.errorMessage == nil {
                VStack {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(Color(red: 0.35, green: 0.50, blue: 0.98))
                    Spacer()
                }
                .transition(.opacity)
            }

            // Error message and retry
            if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(errorMessage)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Button("Reload") {
                        viewModel.retry()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(30)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
                .cornerRadius(12)
            }
        }
        .onChange(of: viewModel.isPageReady) { _, newValue in
            // Mark initial load as complete once the input field is detected
            if newValue && !hasFinishedInitialLoad && viewModel.errorMessage == nil {
                // Delay slightly to allow the SplashView fade-out animation to play
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    hasFinishedInitialLoad = true
                }
            }
        }
    }
}

#Preview {
    ContentView(viewModel: WebViewModel())
}
