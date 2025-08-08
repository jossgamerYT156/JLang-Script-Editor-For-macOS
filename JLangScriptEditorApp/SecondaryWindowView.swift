//
//  SecondaryWindowView.swift
//  JLangScriptEditorApp
//
//  Created by Lilly Aizawa Romo on 08/08/25.
//
// Required By: JL.Graphics.API

import Foundation
import SwiftUI

class SecondaryWindowState: ObservableObject, Identifiable {
    let id = UUID()

    @Published var title: String
    @Published var content: String
    @Published var button: SecondaryWindowButton?

    init(title: String, content: String, button: SecondaryWindowButton?) {
        self.title = title
        self.content = content
        self.button = button
    }
}
