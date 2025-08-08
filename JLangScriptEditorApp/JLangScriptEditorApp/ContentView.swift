//
//  ContentView.swift
//  JLangScriptEditorApp
//
//  Created by Lilly Aizawa Romo on 07/08/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } content: {
            VStack(spacing: 0) {
                // Aquí pasamos la propiedad scriptContent del AppState
                TextEditorView(scriptText: $appState.scriptContent)
                    .frame(minHeight: 200)

                Divider()

                ScriptOutputView()
                    .frame(height: 150)
            }
        } detail: {
            Text("Selecciona un script o crea uno nuevo.")
                .opacity(appState.currentScriptURL == nil ? 1.0 : 0.0)
        }
        .toolbar {
            ToolbarItem {
                Button(action: {
                    appState.runCurrentScript()
                }) {
                    Label("Ejecutar Script", systemImage: "play.fill")
                }
            }
        }
    }
}

// Vista de la barra lateral (por ahora solo un texto)
struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Explorador de Archivos")
                .font(.headline)
                .padding(.bottom, 5)
            
            // Muestra la lista de archivos del estado de la aplicación
            if appState.workspaceURL != nil {
                List(appState.workspaceFiles, id: \.self) { fileURL in
                    Button(action: {
                        // Al hacer clic, abre el archivo
                        openScript(url: fileURL)
                    }) {
                        Label(fileURL.lastPathComponent, systemImage: "doc.text")
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        // Aquí va el menú contextual del clic derecho
                        contextualMenu(for: fileURL)
                    }
                }
                .onAppear {
                    // Llama a la función para cargar archivos cuando la vista aparece
                    appState.fetchFilesInWorkspace()
                }
            } else {
                Text("Selecciona un espacio de trabajo para empezar.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 200)
    }
    
    func deleteScript(url: URL) {
        let alert = NSAlert()
        alert.messageText = "¿Estás seguro de que quieres eliminar este script?"
        alert.informativeText = "Esta acción no se puede deshacer. Se eliminará el archivo: \(url.lastPathComponent)"
        alert.addButton(withTitle: "Eliminar")
        alert.addButton(withTitle: "Cancelar")

        if alert.runModal() == .alertFirstButtonReturn {
            let fileManager = FileManager.default
            do {
                try fileManager.removeItem(at: url)
                // Actualizamos la lista de archivos después de la eliminación
                appState.fetchFilesInWorkspace()
                print("Archivo eliminado: \(url.lastPathComponent)")
            } catch {
                print("Error al eliminar el archivo: \(error.localizedDescription)")
            }
        }
    }
    
    func openInVSCode(url: URL) {
        let vscodeURL = URL(fileURLWithPath: "/Applications/Visual Studio Code.app")
        
        // Verifica si la aplicación de VS Code existe
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") != nil {
            do {
                try NSWorkspace.shared.open([url], withApplicationAt: vscodeURL, options: [], configuration: [:])
                print("Abriendo \(url.lastPathComponent) en Visual Studio Code")
            } catch {
                print("Error al abrir en VS Code: \(error.localizedDescription)")
            }
        } else {
            // Mensaje de error si VS Code no se encuentra
            let alert = NSAlert()
            alert.messageText = "Visual Studio Code no se encuentra"
            alert.informativeText = "Por favor, asegúrate de que Visual Studio Code está instalado en la carpeta /Applications."
            alert.runModal()
        }
    }
    
    func openScript(url: URL) {
            appState.currentScriptURL = url
            do {
                appState.scriptContent = try String(contentsOf: url, encoding: .utf8)
                print("Script abierto: \(url.lastPathComponent)")
            } catch {
                print("Error al abrir el script: \(error.localizedDescription)")
            }
        }

        @ViewBuilder
        func contextualMenu(for fileURL: URL) -> some View {
            Button("Editar Script") {
                openScript(url: fileURL)
            }
            Button("Renombrar") {
                renameScript(url: fileURL, appState: appState)
                    }
                    .keyboardShortcut("r", modifiers: [.command, .shift])

            Divider()

            Button("Eliminar") {
                // Lógica para eliminar el archivo
                print("Eliminar archivo: \(fileURL.lastPathComponent)")
                deleteScript(url: fileURL)
                }

            Button("Abrir en Visual Studio Code") {
                // Lógica para abrir en VS Code
                print("Abriendo en VS Code: \(fileURL.lastPathComponent)")
                openInVSCode(url: fileURL)
            }
        }
}

struct TextEditorView: View {
    // Cambiamos @State por @Binding
    @Binding var scriptText: String
    
    var body: some View {
        TextEditor(text: $scriptText)
            .padding()
            .font(.system(.body, design: .monospaced)) // Fuente retro/monoespaciada
            .border(Color.gray, width: 1) // Borde para simular una UI retro
    }
}

// Vista de la salida del script (por ahora solo un texto)
struct ScriptOutputView: View {
    @EnvironmentObject private var appState: AppState
    @State private var outputText: String = "Salida del Script..."
    
    var body: some View {
        ScrollView {
            Text(appState.outputText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .font(.system(.body, design: .monospaced))
        }
        .background(Color.black.opacity(0.8)) // Fondo oscuro para la salida
        .foregroundColor(.green) // Texto verde para un efecto retro
    }
}

func renameScript(url: URL, appState: AppState) {
let alert = NSAlert()
alert.messageText = "Renombrar Script"
alert.informativeText = "Introduce el nuevo nombre del archivo:"
alert.addButton(withTitle: "Renombrar")
alert.addButton(withTitle: "Cancelar")

let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
inputTextField.stringValue = url.deletingPathExtension().lastPathComponent
alert.accessoryView = inputTextField

let response = alert.runModal()

if response == .alertFirstButtonReturn {
let newFileName = inputTextField.stringValue
if !newFileName.isEmpty {
let newURL = url.deletingLastPathComponent().appendingPathComponent("\(newFileName).jlsh")
let fileManager = FileManager.default

do {
    try fileManager.moveItem(at: url, to: newURL)
    appState.fetchFilesInWorkspace() // Recargar la lista
    print("Archivo renombrado a: \(newURL.path)")
} catch {
    print("Error al renombrar el archivo: \(error.localizedDescription)")
}
}
}
}
// Previsualización para Xcode
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
    
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
