//
//  JLangScriptEditorAppApp.swift
//  JLangScriptEditorApp
//
//  Created by Lilly Aizawa Romo on 07/08/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension UTType {
    static var jlsh: UTType {
        UTType(exportedAs: "com.lds.jlsh")
    }
}

@main
struct JLangScriptEditorApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
            WindowGroup {
                ContentView()
                    .environmentObject(appState) // Inyecta el estado en el entorno
                    .frame(minWidth: 800, minHeight: 600)
            }
            .commands {
                        CommandGroup(replacing: .newItem) {
                            Button("Nuevo Script Vacío") {
                                createNewScript(appState: appState)
                            }
                            .keyboardShortcut("n", modifiers: .command)

                            Button("Abrir Espacio de Trabajo...") {
                                openWorkspace(appState: appState)
                            }
                            .keyboardShortcut("o", modifiers: .command)
                            Button("Limpiar Salida") {
                                appState.clearOutput()
                            }
                        .keyboardShortcut("k", modifiers: .command)
                    }
                        CommandGroup(after: .newItem) {
                            Button("Guardar") {
                                saveScript(appState: appState)
                            }
                            .keyboardShortcut("s", modifiers: .command)
                            .disabled(appState.currentScriptURL == nil) // Deshabilita el botón si no hay script abierto

                            Button("Guardar Como...") {
                                saveScriptAs(appState: appState)
                            }
                            .keyboardShortcut("s", modifiers: [.command, .shift])
                                }
                        }
                    }
                
                // --- Funciones de manejo de archivos ---
                
                func openWorkspace(appState: AppState) {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    
                    if panel.runModal() == .OK {
                        if let url = panel.url {
                            appState.workspaceURL = url
                            appState.currentScriptURL = nil
                            appState.scriptContent = ""
                            print("Espacio de trabajo abierto: \(url.path)")
                        }
                    }
                }
                
                func createNewScript(appState: AppState) {
                    guard let workspaceURL = appState.workspaceURL else {
                        // Manejar error si no hay un espacio de trabajo abierto
                        print("No hay un espacio de trabajo abierto para crear un nuevo script.")
                        return
                    }
                    
                    let alert = NSAlert()
                    alert.messageText = "Nombre del nuevo script:"
                    alert.informativeText = "Por favor, introduce el nombre del archivo (ej. mi_script)."
                    alert.addButton(withTitle: "Crear")
                    alert.addButton(withTitle: "Cancelar")
                    
                    let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
                    alert.accessoryView = inputTextField
                    
                    let response = alert.runModal()
                    
                    if response == .alertFirstButtonReturn {
                            let fileName = inputTextField.stringValue
                            if !fileName.isEmpty {
                                let fileURL = workspaceURL.appendingPathComponent("\(fileName).jlsh")
                                do {
                                    try "".write(to: fileURL, atomically: true, encoding: .utf8)
                                    appState.currentScriptURL = fileURL
                                    appState.scriptContent = ""
                                    
                                    // --- Línea agregada ---
                                    // Llama a la función para recargar los archivos de la barra lateral
                                    appState.fetchFilesInWorkspace()
                                    
                                    print("Nuevo script creado: \(fileURL.path)")
                                } catch {
                                    print("Error al crear el archivo: \(error.localizedDescription)")
                                }
                            }
                        }
                }
                
                func saveScript(appState: AppState) {
                    guard let url = appState.currentScriptURL else {
                        // Si no hay un script abierto, llama a "Guardar Como"
                        saveScriptAs(appState: appState)
                        return
                    }
                    
                    do {
                        try appState.scriptContent.write(to: url, atomically: true, encoding: .utf8)
                        print("Script guardado: \(url.path)")
                    } catch {
                        print("Error al guardar el archivo: \(error.localizedDescription)")
                    }
                }
                
    func saveScriptAs(appState: AppState) {
        let panel = NSSavePanel()
        // Ya no necesitamos .jlsh, ya que el sistema lo infiere
        panel.allowedContentTypes = [UTType("public.text")!]
        if let workspaceURL = appState.workspaceURL {
            panel.directoryURL = workspaceURL
        } else {
            panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        }
        
        // Aquí es donde se establece la extensión predeterminada
        panel.nameFieldStringValue = "nuevo_script.jlsh"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                do {
                    try appState.scriptContent.write(to: url, atomically: true, encoding: .utf8)
                    appState.currentScriptURL = url
                    appState.fetchFilesInWorkspace() // Recargar la lista de archivos
                    print("Script guardado como: \(url.path)")
                } catch {
                    print("Error al guardar como: \(error.localizedDescription)")
                }
            }
        }
    }
}

