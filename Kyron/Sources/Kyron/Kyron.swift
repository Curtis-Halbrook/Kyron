//
//  Kyron.swift
//  Kyron
//
//  Created by Curtis Halbrook on 8/9/25.
//

import SwiftUI
import Observation

/// A continuous, horizontally scrolling ticker view for SwiftUI.
///
/// `Kyron` is a highly customizable view that displays a collection of items in a seamless,
/// infinitely looping horizontal scroll. It is generic over the item type and the view used
/// to display each item.
///
/// ## Example
///
/// ```swift
/// struct ContentView: View {
///     @State private var items = [
///         MyItem(text: "First"),
///         MyItem(text: "Second")
///     ]
///     @State private var isScrolling = true
///
///     var body: some View {
///         Kyron(
///             items: items,
///             isScrolling: $isScrolling,
///             content: { item in
///                 Text(item.text)
///                     .padding()
///             },
///             onSelect: { item in
///                 print("\(item.text) selected")
///             }
///         )
///     }
/// }
/// ```
///
/// - Parameters:
///   - Item: The type of the identifiable and equatable items to display.
///   - Content: The type of view to render for each item.
public struct Kyron<Item: Identifiable & Equatable, Content: View>: View {
    // MARK: - Public Configuration & State
    
    /// The collection of items to be displayed in the ticker.
    public let items: [Item]
    
    /// A binding to a Boolean value that controls whether the ticker is currently scrolling.
    ///
    /// Set this to `true` to start the animation and `false` to stop it.
    @Binding public var isScrolling: Bool
    
    // MARK: - Public Customization
    
    /// A multiplier that adjusts the speed of the scroll.
    ///
    /// The final speed is `scrollSpeed * 10` points per second.
    public let scrollSpeed: Double
    
    /// The fixed height of the `Kyron` view.
    public let height: CGFloat
    
    /// The horizontal spacing between each item in the ticker.
    public let spacing: CGFloat
    
    /// The duration in seconds to wait before automatically resuming scrolling after it has been
    /// paused by a user interaction (e.g., tap or drag).
    public let resumeDelay: TimeInterval
    
    /// A view builder closure that returns the view to display for each item.
    public let content: (Item) -> Content
    
    /// A closure that is called when an item is tapped.
    public let onSelect: (Item) -> Void

    /// Creates a new `Kyron` view.
    ///
    /// - Parameters:
    ///   - items: The collection of items to display.
    ///   - isScrolling: A binding to control the scrolling animation.
    ///   - scrollSpeed: A multiplier for the scrolling speed. Defaults to `5.0`.
    ///   - height: The fixed height of the view. Defaults to `60`.
    ///   - spacing: The horizontal space between items. Defaults to `20`.
    ///   - resumeDelay: The delay before scrolling resumes after a user interaction. Defaults to `5.0`.
    ///   - content: A view builder to create the view for each item.
    ///   - onSelect: A closure to handle item selection. Defaults to an empty closure.
    public init(
        items: [Item],
        isScrolling: Binding<Bool>,
        scrollSpeed: Double = 5.0,
        height: CGFloat = 60,
        spacing: CGFloat = 20,
        resumeDelay: TimeInterval = 5.0,
        @ViewBuilder content: @escaping (Item) -> Content,
        onSelect: @escaping (Item) -> Void = { _ in }
    ) {
        self.items = items
        self._isScrolling = isScrolling
        self.scrollSpeed = scrollSpeed
        self.height = height
        self.spacing = spacing
        self.resumeDelay = resumeDelay
        self.content = content
        self.onSelect = onSelect
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(items) { item in
                    makeItemView(for: item)
                }
                ForEach(items) { item in
                    makeItemView(for: item)
                        .id("\(item.id.hashValue)-duplicate")
                }
            }
            .offset(x: viewModel.scrollOffset + dragOffset)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        if isScrolling {
                            viewModel.stop(isScrolling: $isScrolling, itemCount: items.count, resumeAfter: resumeDelay)
                        }
                        state = value.translation.width
                    }
                    .onEnded { value in
                        viewModel.updateScrollOffset(by: value.translation.width)
                        viewModel.stop(isScrolling: $isScrolling, itemCount: items.count, resumeAfter: resumeDelay)
                    }
            )
        }
        .scrollDisabled(true)
        .clipped()
        .frame(height: height)
        .onChange(of: items) {
            viewModel.restart()
            isScrolling = false // Stop scrolling when content changes
        }
        .task(id: isScrolling) {
            if isScrolling {
                await viewModel.runScrollAnimation(isScrolling: $isScrolling, scrollSpeed: scrollSpeed, spacing: spacing, itemCount: items.count)
            }
        }
    }
    
    // MARK: - Private Implementation
    
    @State private var viewModel = ViewModel()
    @GestureState private var dragOffset: CGFloat = 0

    @ViewBuilder
    private func makeItemView(for item: Item) -> some View {
        content(item)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            viewModel.updateWidth(for: item.id, to: geometry.size.width)
                        }
                }
            )
            .onTapGesture {
                viewModel.stop(isScrolling: $isScrolling, itemCount: items.count, resumeAfter: resumeDelay)
                onSelect(item)
            }
    }
}

extension Kyron {
    
    @MainActor
    @Observable
    class ViewModel {
        // MARK: - Public Properties
        
        /// The current horizontal offset for the scrolling `HStack`.
        private(set) var scrollOffset: CGFloat = 0
        
        // MARK: - Public Actions
        
        /// Resets the Kyron view to its initial state.
        func restart() {
            scrollOffset = 0
            itemWidths = [:] // Clear any previously measured widths.
        }
        
        /// Starts the scrolling animation by setting the controlling binding to true.
        func start(isScrolling: Binding<Bool>, itemCount: Int) {
            resumeTask?.cancel()
            resumeTask = nil
            
            guard itemCount > 0 else { return }
            isScrolling.wrappedValue = true
        }
        
        /// Stops the scrolling animation by setting the controlling binding to false.
        /// - Parameter resumeAfter: If greater than 0, schedules a task to set the
        ///   binding back to true after the delay.
        func stop(isScrolling: Binding<Bool>, itemCount: Int, resumeAfter delay: TimeInterval = 0) {
            isScrolling.wrappedValue = false
            resumeTask?.cancel()
            
            guard delay > 0 else { return }
            
            resumeTask = Task {
                do {
                    try await Task.sleep(for: .seconds(delay))
                    try Task.checkCancellation()
                    start(isScrolling: isScrolling, itemCount: itemCount)
                } catch {
                    // Task cancelled.
                }
            }
        }
        
        /// Called by the `KyronView` for each item as it appears on screen.
        /// This function is responsible for collecting the rendered width of each item.
        func updateWidth(for itemID: AnyHashable, to newWidth: CGFloat) {
            if itemWidths[itemID] != newWidth {
                itemWidths[itemID] = newWidth
            }
        }
        
        /// Called by the view's drag gesture to update the scroll offset.
        func updateScrollOffset(by value: CGFloat) {
            scrollOffset += value
        }
        
        /// The main animation loop, now driven by an external binding.
        func runScrollAnimation(isScrolling: Binding<Bool>, scrollSpeed: Double, spacing: CGFloat, itemCount: Int) async {
            while itemCount != itemWidths.count {
                try? await Task.sleep(for: .milliseconds(50))
            }
            
            let singleSetWidth = calculateTotalWidth(spacing: spacing, itemCount: itemCount)
            guard singleSetWidth > 0 else { return }
            
            // The scroll speed is now a simple multiplier for a base speed in points per second.
            // This removes the dependency on the item's content (i.e., displayText).
            let pointsPerSecond = scrollSpeed * 10.0
            
            let frameRate: Double = 60.0
            let increment = pointsPerSecond / frameRate
            let frameDuration = 1.0 / frameRate
            
            while isScrolling.wrappedValue {
                scrollOffset -= increment
                
                if scrollOffset <= -singleSetWidth {
                    scrollOffset += singleSetWidth
                }
                
                do {
                    try await Task.sleep(for: .seconds(frameDuration))
                } catch {
                    isScrolling.wrappedValue = false
                    break
                }
            }
        }
        
        // MARK: - Private Implementation
        
        /// A dictionary to store the measured width of each individual item.
        private var itemWidths: [AnyHashable: CGFloat] = [:]
        
        /// A reference to the asynchronous task that handles resuming the scroll.
        private var resumeTask: Task<Void, Never>?
        
        private func calculateTotalWidth(spacing: CGFloat, itemCount: Int) -> CGFloat {
            guard itemCount > 0, itemCount == itemWidths.count else { return 0 }
            
            let totalTextWidth = itemWidths.values.reduce(0, +)
            let totalSpacing = CGFloat(itemCount) * spacing
            
            return totalTextWidth + totalSpacing
        }
    }
}
