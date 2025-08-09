//
//  ContentView.swift
//  Kyron
//
//  Created by Curtis Halbrook on 6/27/25.
//

import SwiftUI
import Kyron

struct ContentView: View {
    @State private var items: [KyronItem<URL>] = []
    @State private var selectedURL: URL?
    @State private var isScrolling = true
    @State private var resumeDelay: TimeInterval = 5.0

    var body: some View {
        VStack(spacing: 0) {
            if let url = selectedURL {
                WebView(url: url)
            } else {
                // Placeholder for when no URL is selected
                VStack {
                    Text("Select an item below to view it here.")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // --- Kyron View and Controls ---
            VStack(spacing: 10) {
                Kyron(
                    items: items,
                    isScrolling: $isScrolling,
                    scrollSpeed: 10,
                    height: 50,
                    spacing: 20,
                    resumeDelay: resumeDelay,
                    content: { item in
                        Text(item.displayText)
                            .font(.title)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    },
                    onSelect: { item in
                        // The view now handles its own pause/resume. The consumer
                        // only needs to react to the selection.
                        selectedURL = item.navigation
                    }
                )

                // --- Control Panel ---
                HStack {
                    Button(isScrolling ? "Pause" : "Play") {
                        isScrolling.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                    
                    Text("Resume Delay:")
                    Slider(value: $resumeDelay, in: 1...10, step: 1)
                        .frame(width: 150)
                    Text("\(Int(resumeDelay))s")
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 10)
            .background(Color(white: 0.95)) // Very light gray
        }
        .onAppear(perform: setupItems)
    }
    
    // MARK: - Private Implementation

    private func setupItems() {
        items = [
            KyronItem(displayText: "Apple Unveils New M4-Powered Vision Pro, Revolutionizing Spatial Computing", navigation: URL(string: "https://www.apple.com")!),
            KyronItem(displayText: "Google Announces Major Breakthrough in Quantum Computing with New 'Sycamore' Processor", navigation: URL(string: "https://www.google.com")!),
            KyronItem(displayText: "GitHub Launches AI-Powered Code Review Assistant to Supercharge Developer Productivity", navigation: URL(string: "https://www.github.com")!),
            KyronItem(displayText: "Stack Overflow Partners with OpenAI to Integrate GPT-4 into Community Q&A Platform", navigation: URL(string: "https://stackoverflow.com")!),
            KyronItem(displayText: "Swift.org Releases Swift 6.0 with Major Performance Enhancements and New Concurrency Features", navigation: URL(string: "https://swift.org")!)
        ]
    }
}

#Preview {
    ContentView()
}
