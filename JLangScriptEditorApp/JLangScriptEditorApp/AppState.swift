//
//  AppState.swift
//  JLangScriptEditorApp
//
//  Created by Lilly Aizawa Romo on 07/08/25.
//

import Foundation

class AppState: ObservableObject {
    @Published var workspaceURL: URL? {
        didSet {
            fetchFilesInWorkspace()
        }
    }
    @Published var currentScriptURL: URL?
    @Published var scriptContent: String = ""
    @Published var outputText: String = "Salida del Script..."
    
    @Published var workspaceFiles: [URL] = []
    
    // Agrega una instancia del intérprete aquí
    private var interpreter: JLangInterpreter!

    init() {
        self.interpreter = JLangInterpreter(delegate: self)
    }
    
    // Nueva función para ejecutar el script
    func runCurrentScript() {
        interpreter.parse(scriptContent: scriptContent)
    }

    // Función para obtener los archivos
        func fetchFilesInWorkspace() {
            guard let url = workspaceURL else {
                workspaceFiles = []
                return
            }
            
            let fileManager = FileManager.default
            do {
                let files = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                // Filtra solo los archivos con la extensión .jlsh
                workspaceFiles = files.filter { $0.pathExtension == "jlsh" }
                print("Archivos encontrados en el espacio de trabajo: \(workspaceFiles.count)")
            } catch {
                print("Error al listar archivos: \(error.localizedDescription)")
                workspaceFiles = []
            }
        }
}
