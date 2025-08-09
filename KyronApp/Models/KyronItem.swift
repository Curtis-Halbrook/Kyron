//
//  KyronItem.swift
//  Kyron
//
//  Created by Curtis Halbrook on 6/27/25.
//

import Foundation

public struct KyronItem<NavigationValue: Equatable>: Identifiable, Equatable {
    public let id = UUID()
    public let displayText: String
    public let navigation: NavigationValue
    
    public init(displayText: String, navigation: NavigationValue) {
        self.displayText = displayText
        self.navigation = navigation
    }
}
