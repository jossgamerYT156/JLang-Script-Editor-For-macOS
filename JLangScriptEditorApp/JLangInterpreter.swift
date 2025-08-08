//
// JLangInterpreter.swift
// JLangScriptEditorApp
//
// Created by Lilly Aizawa Romo on 07/08/25.
//

import Foundation

class JLangInterpreter {
    private var functions: [String: [String]] = [:]
    private var globalVariables: [String: String] = [:]
    weak var delegate: JLangInterpreterDelegate?
    
    // important MemoryManagement.
    private var memoryController: MemoryController?
    
    init(delegate: JLangInterpreterDelegate) {
        self.delegate = delegate
    }
    
    /// Carga, parsea y ejecuta el contenido de un script JLang de forma secuencial.
    func parse(scriptContent: String, at directoryURL: URL) {
        let lines = scriptContent.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var topLevelLines: [String] = []
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            
            if line.hasPrefix("function") {
                if let (functionName, functionBody, nextIndex) = parseFunctionDefinition(lines: lines, at: i) {
                    functions[functionName] = functionBody
                    i = nextIndex
                } else {
                    i += 1
                }
            } else if line.hasPrefix("@NEW WINDOW") {
                if let (windowBody, nextIndex) = parseWindowDefinition(lines: lines, at: i) {
                    // Pass the array of lines to the handler
                    handleNewWindowCommand(windowInfo: windowBody, at: directoryURL)
                    i = nextIndex
                } else {
                    i += 1
                }
            } else {
                topLevelLines.append(line)
                i += 1
            }
        }
        
        delegate?.printDebug("--- Ejecutando script principal ---")
        executeLines(lines: topLevelLines, args: [], at: directoryURL)
    }
    
    // --- Funciones auxiliares para el parsing ---
    
    private func parseFunctionDefinition(lines: [String], at startIndex: Int) -> (name: String, body: [String], nextIndex: Int)? {
        let definitionLine = lines[startIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let nameMatch = definitionLine.range(of: "function\\s+(\\w+)", options: .regularExpression) else { return nil }
        let functionName = String(definitionLine[nameMatch].dropFirst("function".count).trimmingCharacters(in: .whitespaces))
        
        guard definitionLine.contains("{") else {
            delegate?.printDebug("Error de sintaxis: Falta '{' en la definición de la función '\(functionName)'.")
            return nil
        }
        
        var functionBody: [String] = []
        var i = startIndex + 1
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            
            if line == "}" {
                return (name: functionName, body: functionBody, nextIndex: i + 1)
            }
            
            if !line.isEmpty {
                functionBody.append(line)
            }
            i += 1
        }
        delegate?.printDebug("Error de sintaxis: Se esperaba '}' para cerrar la función '\(functionName)'.")
        return nil
    }
    
    private func parseFunctionCall(line: String) -> (name: String, args: [String])? {
        // Regex para capturar el nombre y los argumentos de la función
        let regexPattern = "call\\s+(\\w+)(?:\\[(.*)\\])?"
        
        do {
            let regex = try NSRegularExpression(pattern: regexPattern, options: .caseInsensitive)
            guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) else { return nil }
            
            guard match.numberOfRanges > 1, let nameRange = Range(match.range(at: 1), in: line) else { return nil }
            
            let functionName = String(line[nameRange])
            var args: [String] = []
            
            if match.numberOfRanges > 2, let argsRange = Range(match.range(at: 2), in: line) {
                let argsString = String(line[argsRange])
                args = argsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            
            return (name: functionName, args: args)
        } catch {
            return nil
        }
    }
    
    private func parseWindowDefinition(lines: [String], at startIndex: Int) -> (body: [String], nextIndex: Int)? {
        let definitionLine = lines[startIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for the opening `{`
        guard definitionLine.hasSuffix("{") else {
            delegate?.printDebug("Error de sintaxis: Se esperaba '{' para abrir el comando @NEW WINDOW.")
            return nil
        }
        
        var windowBody: [String] = []
        var i = startIndex + 1
        var braceCount = 1
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            
            if line == "}" {
                braceCount -= 1
                if braceCount == 0 {
                    return (body: windowBody, nextIndex: i + 1)
                }
            } else if line.hasSuffix("{") {
                braceCount += 1
            }
            
            if !line.isEmpty {
                windowBody.append(line)
            }
            i += 1
        }
        
        delegate?.printDebug("Error de sintaxis: Se esperaba '}' para cerrar el comando @NEW WINDOW.")
        return nil
    }
    
    // --- Funciones para la ejecución ---
    
    private func executeLines(lines: [String], args: [String], at directoryURL: URL) {
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            delegate?.printDebug("> EJECUTANDO: \(trimmedLine)")
            // Llamamos a `executeLine` y le pasamos la URL
            executeLine(line: trimmedLine, args: args, at: directoryURL)
        }
    }
    
    private func executeLine(line: String, args: [String], at directoryURL: URL) {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        let commandComponents = trimmedLine.components(separatedBy: .whitespaces)
        guard let firstCommand = commandComponents.first else { return }
        
        switch firstCommand {
        case "print":
            handlePrint(line: trimmedLine, commandComponents: commandComponents, args: args)
        case "string":
            handleStringDefinition(line: line)
        case "MAX_MEM":
            handleMemoryCommand(line: trimmedLine)
        case "@VAL":
            handleVariableDefinition(line: line)
        case "@REM":
            break
        case "@STDO":
            handleStdOutputCommand(commandComponents: commandComponents)
        case "@EXTERNAL":
            // Pasamos la URL a la función `handleExternalCommand`
            handleExternalCommand(commandComponents: commandComponents, at: directoryURL)
            
            // -- JL.Graphics.API
        case "@NEW":
            // 👇 Nuevo: Maneja el comando @NEW WINDOW
            if trimmedLine.contains("WINDOW") {
                // The new handler is called by the parser, so this is not needed here.
            }
        case "call":
            if let (functionName, args) = parseFunctionCall(line: trimmedLine) {
                // Pasamos la URL a la función `executeLines`
                executeLines(lines: functions[functionName] ?? [], args: args, at: directoryURL)
            }
        default:
            delegate?.printDebug("Error: Comando desconocido '\(firstCommand)'")
        }
    }
    
    // -- Memory Handling
    private func handleMemoryCommand(line: String) {
        let components = line.components(separatedBy: .whitespacesAndNewlines)
        
        // Asegúrate de que al menos haya un comando y un valor.
        guard components.count >= 2 else {
            delegate?.printDebug("Error de sintaxis: Uso de MAX_MEM: `MAX_MEM <bytes>;`.")
            return
        }
        
        // Filtra la línea para obtener solo los dígitos.
        let byteValueString = components.dropFirst().joined().filter("0123456789".contains)
        
        // Intenta convertir la cadena filtrada a un entero.
        if let bytes = Int(byteValueString) {
            self.memoryController = MemoryController(maxBudget: bytes)
            delegate?.printDebug("Presupuesto de memoria establecido en \(bytes) bytes.")
        } else {
            delegate?.printDebug("Error de sintaxis: El valor de memoria debe ser un número entero válido.")
        }
    }
    
    private func handleStringDefinition(line: String) {
        let normalizedLine = line.replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "′", with: "'")
            .replacingOccurrences(of: "″", with: "\"")
        
        let regexPattern = "string\\s+(\\w+)\\s*=\\s*\"(.*?)\""
        
        do {
            let regex = try NSRegularExpression(pattern: regexPattern)
            
            // 3. Find a match in the line of code.
            if let match = regex.firstMatch(in: normalizedLine, options: [], range: NSRange(location: 0, length: normalizedLine.utf16.count)) {
                
                // 4. Ensure both the name and value groups were captured.
                guard match.numberOfRanges > 2,
                      let nameRange = Range(match.range(at: 1), in: normalizedLine),
                      let valueRange = Range(match.range(at: 2), in: normalizedLine) else {
                    delegate?.printDebug("Error de sintaxis: Uso de 'string': `string <nombre> = \"<valor>\";`")
                    return
                }
                
                // 5. Extract the name and the value.
                let varName = String(normalizedLine[nameRange])
                var varValue = String(normalizedLine[valueRange])
                
                // 6. Check for and remove a trailing semicolon from the value.
                if varValue.hasSuffix(";") {
                    varValue.removeLast()
                }
                
                // 7. Proceed with memory allocation and storage.
                let size = MemoryLayout.size(ofValue: varValue) + varValue.utf8.count
                if memoryController?.allocate(bytes: size) ?? true {
                    globalVariables[varName] = varValue
                    delegate?.printDebug("Variable de cadena '\(varName)' definida con valor '\(varValue)'.")
                } else {
                    delegate?.printDebug("Error de ejecución: Presupuesto de memoria excedido al crear la variable '\(varName)'.")
                }
                
            } else {
                delegate?.printDebug("Error de sintaxis: Uso de 'string': `string <nombre> = \"<valor>\";`")
            }
        } catch {
            delegate?.printDebug("Error interno del intérprete (regex): \(error.localizedDescription)")
        }
    }
    
    private func handleVariableDefinition(line: String) {
        // 1. Define la expresión regular para capturar el nombre y el valor.
        // Usamos `matches.range(at: 1)` para el nombre y `matches.range(at: 2)` para el valor.
        let regexPattern = "@VAL\\s+(\\w+)\\s*=\\s*(.*)"
        
        do {
            let regex = try NSRegularExpression(pattern: regexPattern)
            
            // 2. Busca una coincidencia en la línea de código.
            if let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)) {
                
                // 3. Asegúrate de que se hayan capturado los dos grupos (nombre y valor).
                guard match.numberOfRanges > 2,
                      let nameRange = Range(match.range(at: 1), in: line),
                      let valueRange = Range(match.range(at: 2), in: line) else {
                    delegate?.printDebug("Error de sintaxis: Uso de @VAL: `@VAL <nombre> = <valor>;`")
                    return
                }
                
                // 4. Extrae el nombre y el valor de la variable de las capturas.
                let varName = String(line[nameRange])
                var varValue = String(line[valueRange]).trimmingCharacters(in: .whitespaces)
                
                // 5. Elimina el posible punto y coma al final si existe.
                if varValue.hasSuffix(";") {
                    varValue.removeLast()
                }
                
                // 6. Verifica la sintaxis para el valor entre comillas si es necesario.
                // Si el valor está entre comillas, elimina las comillas.
                if varValue.hasPrefix("\"") && varValue.hasSuffix("\"") {
                    varValue = String(varValue.dropFirst().dropLast())
                }
                
                // 7. Continúa con la lógica de gestión de memoria y almacenamiento.
                let size = MemoryLayout.size(ofValue: varValue) + varValue.utf8.count
                if memoryController?.allocate(bytes: size) ?? true {
                    globalVariables[varName] = varValue
                    delegate?.printDebug("Variable '\(varName)' definida con valor '\(varValue)'.")
                } else {
                    delegate?.printDebug("Error de ejecución: Presupuesto de memoria excedido al crear la variable '\(varName)'.")
                }
                
            } else {
                delegate?.printDebug("Error de sintaxis: Uso de @VAL: `@VAL <nombre> = <valor>;`")
            }
        } catch {
            delegate?.printDebug("Error interno del intérprete (regex): \(error.localizedDescription)")
        }
    }
    
    private func deallocateVariable(name: String) {
        if let value = globalVariables.removeValue(forKey: name) {
            let size = MemoryLayout.size(ofValue: value)
            memoryController?.deallocate(bytes: size)
        }
    }
    
    private func handleStdOutputCommand(commandComponents: [String]) {
        if commandComponents.count > 1 && commandComponents[1] == "REMOVE" {
            delegate?.clearOutput()
        }
    }
    
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
                delegate?.printDebug("Error: Tipo de argumento no compatible o no encontrado.")
            }
        } else if argument.hasPrefix("@") {
            let varName = String(argument.dropFirst())
            if let value = globalVariables[varName] {
                delegate?.printOutput(value)
            } else {
                delegate?.printDebug("Error: Variable '@\(varName)' no definida.")
            }
        } else if line.trimmingCharacters(in: .whitespaces).hasPrefix("print \"") {
            if let startQuote = line.firstIndex(of: "\""),
               let endQuote = line.lastIndex(of: "\""),
               startQuote != endQuote {
                
                let content = line[line.index(after: startQuote)..<endQuote]
                delegate?.printOutput(String(content))
            } else {
                delegate?.printDebug("Error de sintaxis: Cadena literal incompleta.")
            }
        } else {
            delegate?.printDebug("Error de sintaxis: Argumento de 'print' no reconocido.")
        }
    }
    
    // -- Handling External Scripts
    private func handleExternalCommand(commandComponents: [String], at directoryURL: URL) {
        // 1. Verificar la sintaxis del comando.
        guard commandComponents.count == 3, commandComponents[1] == "RUN" else {
            delegate?.printDebug("Error de sintaxis: Uso de @EXTERNAL: `@EXTERNAL RUN \"<filename.jlsh>\"`.")
            return
        }
        
        // 2. Extraer la ruta del archivo.
        let filePath = commandComponents[2].replacingOccurrences(of: "\"", with: "")
        
        // 3. Llamar al delegado, pasando el path y la URL de la carpeta.
        delegate?.runExternalScript(path: filePath, from: directoryURL)
    }
    
    // -- Graphics API for ChildWindows.
    // This is the correct implementation of the handler.
    private func handleNewWindowCommand(windowInfo: [String], at directoryURL: URL) {
            var title: String = "Ventana"
            var content: String = ""
            var buttonInfo: SecondaryWindowButton?
             // Unir todas las líneas en una sola cadena para el regex
            let fullCommand = windowInfo.joined(separator: "\n")
             // 1. Extraer el título
             if let titleMatch = fullCommand.range(of: "@Title\\s*=\\s*\"(.*?)\"", options: .regularExpression) {
                 title = String(fullCommand[titleMatch]).replacingOccurrences(of: "@Title =", with: "")
                 .replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespaces)
            }
             // 2. Extraer el contenido principal y el botón
            if let contentMatch = fullCommand.range(of: "@Content\\s*=\\s*\\{", options: .regularExpression) {
                 let contentBlock = String(fullCommand[contentMatch.upperBound...])
                 if let blockEnd = contentBlock.range(of: "}") {
                let innerContent = String(contentBlock[..<blockEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                // Regex para el texto
                if let textMatch = innerContent.range(of: "TEXT\\s*=\\s*\"(.*?)\"", options: .regularExpression) {
                    let textContent = String(innerContent[textMatch]).replacingOccurrences(of: "TEXT =", with: "")
                    .replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespaces)
                    content = textContent
                }
                    // Regex for the button
                    // Use NSRegularExpression to get ranges of captured groups
                    let buttonPattern = "BUTTON\\s*=\\s*\"(.*?)\"\\s*:\\s*\\{(.*?)\\}"
                    do {
                        let regex = try NSRegularExpression(pattern: buttonPattern, options: .dotMatchesLineSeparators)
                        if let buttonMatch = regex.firstMatch(in: fullCommand, range: NSRange(fullCommand.startIndex..<fullCommand.endIndex, in: fullCommand)) {
                         // Extract the label using the captured group
                         if let labelRange = Range(buttonMatch.range(at: 1), in: fullCommand) {
                         let label = String(fullCommand[labelRange]).trimmingCharacters(in: .whitespaces)
                        // Extract the action string using the captured group
                        if let actionRange = Range(buttonMatch.range(at: 2), in: fullCommand) {
                            let actionString = String(fullCommand[actionRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                                // Create the closure to execute the action
                                let actionClosure: () -> Void = {
                                    self.executeLines(lines: [actionString], args: [], at: directoryURL)
                                }
                                    // Create the SecondaryWindowButton object
                                    buttonInfo = SecondaryWindowButton(label: label, action: actionClosure)
                             }
                        }
                }
                } catch {
                    delegate?.printDebug("Error interno del intérprete (regex de botón): \(error.localizedDescription)")
                }
            }
            }
            // Llamar al delegado con el nuevo struct de datos
            delegate?.openNewWindow(title: title, content: content, button: buttonInfo)
        }

    
    private func handleContentUpdate(windowInfo: [String]) {
        // Join the array of lines into a single string to parse with regex
        let fullContent = windowInfo.joined(separator: "\n")
        
        // Use regex to find the new TEXT value
        let textPattern = "TEXT\\s*=\\s*\"(.*?)\""
        if let textMatch = fullContent.range(of: textPattern, options: .regularExpression) {
            let newTextContent = String(fullContent[textMatch]).replacingOccurrences(of: "TEXT =", with: "")
                .replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespaces)
            
            // Pass the single, extracted string to the delegate
            self.delegate?.updateSecondaryWindowContent(with: newTextContent)
        }
    }
}
// --- Definición del Protocolo para la Salida del Script ---
protocol JLangInterpreterDelegate: AnyObject {
    func printOutput(_ message: String)
    func printDebug(_ message: String)
    func clearOutput()
    func clearDebug()
    func runExternalScript(path: String, from scriptDirectoryURL: URL)
    
    // -- JL.Graphics.API
    func openNewWindow(title: String, content: String, button: SecondaryWindowButton?)
    // This is the new method we need to add to the delegate
    func updateSecondaryWindowContent(with newContent: String)
}
