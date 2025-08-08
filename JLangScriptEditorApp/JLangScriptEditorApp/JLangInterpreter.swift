//
//  JLangInterpreter.swift
//  JLangScriptEditorApp
//
//  Created by Lilly Aizawa Romo on 07/08/25.
//

import Foundation

class JLangInterpreter {
    private var functions: [String: [String]] = [:]
    private var globalVariables: [String: String] = [:]
    weak var delegate: JLangInterpreterDelegate?

    init(delegate: JLangInterpreterDelegate) {
        self.delegate = delegate
    }

    /// Carga, parsea y ejecuta el contenido de un script JLang de forma secuencial.
        func parse(scriptContent: String) {
            let lines = scriptContent.components(separatedBy: .newlines)
            var i = 0

            while i < lines.count {
                let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)

                // Saltar líneas vacías
                guard !line.isEmpty else {
                    i += 1
                    continue
                }

                if line.hasPrefix("function") {
                    // Parsear una definición de función
                    if let (functionName, functionBody, nextIndex) = parseFunctionDefinition(lines: lines, at: i) {
                        functions[functionName] = functionBody
                        i = nextIndex
                    } else {
                        i += 1
                    }
                } else if line.hasPrefix("call") {
                    // Parsear y ejecutar una llamada a función
                    if let (functionName, args) = parseFunctionCall(line: line) {
                        executeLines(lines: functions[functionName] ?? [], args: args)
                    }
                    i += 1
                } else {
                    // Ejecutar cualquier línea que no sea una definición o llamada a función
                    executeLine(line: line, args: [])
                    i += 1
                }
            }
        }
    
    // --- Funciones auxiliares para el parsing ---
    
    private func parseFunctionDefinition(lines: [String], at startIndex: Int) -> (name: String, body: [String], nextIndex: Int)? {
        let definitionLine = lines[startIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let nameMatch = definitionLine.range(of: "function\\s+(\\w+)", options: .regularExpression) else { return nil }
        let functionName = String(definitionLine[nameMatch].dropFirst("function".count).trimmingCharacters(in: .whitespaces))
        
        guard let _ = lines[startIndex].firstIndex(of: "{") else { return nil }
        
        var functionBody: [String] = []
        var i = startIndex + 1
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if line == "}" {
                return (name: functionName, body: functionBody, nextIndex: i + 1)
            }
            functionBody.append(line)
            i += 1
        }
        
        return nil
    }
    
    private func parseFunctionCall(line: String) -> (name: String, args: [String])? {
        guard let _ = line.range(of: "call\\s+(\\w+)\\[(.*)\\]", options: .regularExpression) else { return nil }

        let components = line.components(separatedBy: ["[", "]"])
        guard components.count == 3 else { return nil }
        
        let functionName = components[0].replacingOccurrences(of: "call", with: "").trimmingCharacters(in: .whitespaces)
        let argsString = components[1]
        
        let args = argsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "") }
        
        return (name: functionName, args: args)
    }

    // --- Funciones para la ejecución ---
    private func executeLine(line: String, args: [String]) {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        let commandComponents = trimmedLine.components(separatedBy: .whitespaces)
        guard let firstCommand = commandComponents.first else { return }

            // Usa un switch para manejar los comandos de forma eficiente
            switch firstCommand {
            case "print":
                handlePrint(line: trimmedLine, commandComponents: commandComponents, args: args)
            case "string":
                        handleStringDefinition(line: line)
            case "@VAL":
                handleVariableDefinition(line: line)
            case "@REM":
                // Ignorar comentarios
                break
            case "@STDO":
                handleStdOutputCommand(commandComponents: commandComponents)
            case "@EXTERNAL":
                handleExternalCommand(commandComponents: commandComponents)
            default:
                delegate?.printOutput("Error: Comando desconocido '\(firstCommand)'")
            }
        }
    // -- Function to handle definition of strings to MEM.
    private func handleStringDefinition(line: String) {
        // 1. Normalizar la línea para usar solo comillas estándar.
        let normalizedLine = line.replacingOccurrences(of: "“", with: "\"")
                                   .replacingOccurrences(of: "”", with: "\"")
                                   .replacingOccurrences(of: "‘", with: "'")
                                   .replacingOccurrences(of: "’", with: "'")
                                   .replacingOccurrences(of: "′", with: "'") // Símbolo prima
                                   .replacingOccurrences(of: "″", with: "\"") // Símbolo doble prima

        // 2. Expresión regular para capturar el nombre de la variable y su valor.
        let regexPattern = "string\\s+(\\w+)\\s*=\\s*\"(.*?)\""
        
        do {
            let regex = try NSRegularExpression(pattern: regexPattern)
            if let match = regex.firstMatch(in: normalizedLine, options: [], range: NSRange(location: 0, length: normalizedLine.utf16.count)) {
                if match.numberOfRanges > 2,
                   let nameRange = Range(match.range(at: 1), in: normalizedLine),
                   let valueRange = Range(match.range(at: 2), in: normalizedLine) {
                    
                    let varName = String(normalizedLine[nameRange])
                    let varValue = String(normalizedLine[valueRange])
                    
                    globalVariables[varName] = varValue
                }
            }
        } catch {
            print("Error en la expresión regular: \(error.localizedDescription)")
        }
    }

    // Corregir `handleStdOutputCommand` para que funcione correctamente.
    private func handleStdOutputCommand(commandComponents: [String]) {
        if commandComponents.count > 1 && commandComponents[1] == "REMOVE" {
            // La línea `@STDO REMOVE “”` ahora funcionará.
            delegate?.clearOutput()
        }
    }
    
    // --- FUNCIÓN REFRACTORIZADA: Ejecuta un bloque de código (body) ---
        private func executeLines(lines: [String], args: [String]) {
            for line in lines {
                executeLine(line: line.trimmingCharacters(in: .whitespacesAndNewlines), args: args)
            }
        }
    // --- Funciones de manejo de comandos ---
    
    // La función ahora acepta la línea completa como argumento
       private func handlePrint(line: String, commandComponents: [String], args: [String]) {
           guard commandComponents.count > 1 else {
               delegate?.printOutput("")
               return
           }

           let argument = commandComponents[1]

           if argument.hasPrefix("@ARGUMENTS.") {
               let parts = argument.components(separatedBy: ".")
               if parts.count == 2, parts[1] == "STRING", let arg = args.first {
                   delegate?.printOutput(arg)
               } else {
                   delegate?.printOutput("Error: Tipo de argumento no compatible o no encontrado.")
               }
           } else if argument.hasPrefix("@") {
               let varName = String(argument.dropFirst())
               if let value = globalVariables[varName] {
                   delegate?.printOutput(value)
               } else {
                   delegate?.printOutput("Error: Variable '@\(varName)' no definida.")
               }
           } else if line.trimmingCharacters(in: .whitespaces).hasPrefix("print \"") {
               // Analiza la cadena literal de la línea completa
               if let startQuote = line.firstIndex(of: "\""),
                  let endQuote = line.lastIndex(of: "\""),
                  startQuote != endQuote {
                   
                   let content = line[line.index(after: startQuote)..<endQuote]
                   delegate?.printOutput(String(content))
               } else {
                   delegate?.printOutput("Error de sintaxis: Cadena literal incompleta.")
               }
           } else {
               delegate?.printOutput("Error de sintaxis: Argumento de 'print' no reconocido.")
           }
       }
    
    private func handleVariableDefinition(line: String) {
        guard let range = line.range(of: "@VAL\\s+(\\w+)\\s*=\\s*(.*)", options: .regularExpression) else { return }
        
        // Aquí es donde corregimos el error
        let components = line[range].components(separatedBy: CharacterSet(charactersIn: "@VAL=;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } // Filtrar componentes vacíos

        guard components.count >= 2 else { return }

        let varName = components[0]
        let varValue = components[1]

        globalVariables[varName] = varValue
    }

    private func handleExternalCommand(commandComponents: [String]) {
        if commandComponents.count > 2 && commandComponents[1] == "RUN" {
            let filePath = commandComponents[2].replacingOccurrences(of: "\"", with: "")
            delegate?.runExternalScript(path: filePath)
        }
    }
}

// --- Definición del Protocolo para la Salida del Script ---
protocol JLangInterpreterDelegate: AnyObject {
    func printOutput(_ message: String);
    func clearOutput();
    func runExternalScript(path: String);
}

extension AppState: JLangInterpreterDelegate {
    func printOutput(_ message: String) {
        DispatchQueue.main.async {
            self.outputText += "\n\(message)"
        }
    }

    func clearOutput() {
        DispatchQueue.main.async {
            self.outputText = ""
        }
    }

    func runExternalScript(path: String) {
        printOutput("Error: El comando '@EXTERNAL RUN <filename.jlsh>' aún no está implementado.")
    }
}
