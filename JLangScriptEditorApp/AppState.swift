import Foundation
import SwiftUI // Make sure SwiftUI is importe

// Struct definido para use on JL.Graphics.API
// Struct para representar un botón en la ventana
// Struct para representar un botón en la ventana
struct SecondaryWindowButton {
    let label: String
    let action: () -> Void // La acción es ahora una closure sin argumentos
}

// Struct para definir el estado de la ventana secundaria
struct SecondaryWindowView: View {
    @ObservedObject var windowState: SecondaryWindowState

    var body: some View {
        VStack {
            Text(windowState.title).font(.headline)
            Text(windowState.content).padding()
            if let button = windowState.button {
                Button(button.label, action: button.action)
            }
        }
        .frame(minWidth: 300, minHeight: 200)
        .padding()
    }
}


// - End Of Required Struct By: JL.Graphics.API

class AppState: ObservableObject {
    @Published var workspaceURL: URL? {
        didSet {
            fetchFilesInWorkspace()
        }
    }
    @Published var currentScriptURL: URL?
    @Published var scriptContent: String = ""
    @Published var outputText: String = "Salida del Script..."
    @Published var debugLog: String = "Log de Depuración..."
    
    @Published var workspaceFiles: [URL] = []
    
    // -- JL.Graphics.API
    @Published var secondaryWindowState: SecondaryWindowState? = nil

    // Agrega una instancia del intérprete aquí
    private var interpreter: JLangInterpreter!

    init() {
        self.interpreter = JLangInterpreter(delegate: self)
    }
    
    // Nueva función para ejecutar el script
    func runCurrentScript() {
        guard let url = currentScriptURL else {
            outputText += "\nError: No hay un script abierto para ejecutar."
            return
        }
        let directoryURL = url.deletingLastPathComponent()
        
        do {
            let scriptContent = try String(contentsOf: url)
            // Aquí pasamos la URL a la función `parse`
            interpreter.parse(scriptContent: scriptContent, at: directoryURL)
        } catch {
            outputText += "\nError: No se pudo leer el archivo de script. \(error.localizedDescription)"
        }
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

// Extensión del delegado
extension AppState: JLangInterpreterDelegate {
    
    func runExternalScript(path: String, from scriptDirectoryURL: URL) {
        // Construye la URL completa del archivo externo
        let externalScriptURL = scriptDirectoryURL.appendingPathComponent(path)

        do {
            let scriptContent = try String(contentsOf: externalScriptURL, encoding: .utf8)
            printOutput("\n--- Ejecutando script externo: \(path) ---")
            
            // Llama al intérprete para que ejecute el nuevo script,
            // pasando la nueva URL de su carpeta.
            interpreter.parse(scriptContent: scriptContent, at: scriptDirectoryURL)

            printOutput("--- Fin de la ejecución de \(path) ---")
            
        } catch {
            printOutput("Error: No se pudo leer el archivo \(path).")
            printOutput("Verifica que el archivo exista en la ruta: \(externalScriptURL.path)")
        }
    }
    
    func printOutput(_ message: String) {
        DispatchQueue.main.async {
            self.outputText += "\n\(message)"
        }
    }

    func printDebug(_ message: String) {
            DispatchQueue.main.async {
                self.debugLog += "\n\(message)"
            }
        }
    func clearDebug() {
            DispatchQueue.main.async {
                self.debugLog = ""
            }
        }
    
    func clearOutput() {
        DispatchQueue.main.async {
            self.outputText = ""
        }
    }
    
    // -- JL.Graphics.API
    func openNewWindow(title: String, content: String, button: SecondaryWindowButton?) {
        DispatchQueue.main.async {
            self.secondaryWindowState = SecondaryWindowState(title: title, content: content, button: button)
            self.printDebug("Solicitud de nueva ventana recibida: '\(title)'")
            self.secondaryWindowState = SecondaryWindowState(
                title: title,
                content: content,
                button: button
            )
        }
    }
    func updateSecondaryWindowContent(with newContent: String) {
        if let currentState = self.secondaryWindowState {
            currentState.content += "\n\(newContent)" // Will now trigger UI update
        }
    }
}
