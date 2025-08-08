//
//  MemoryControl.swift
//  JLangScriptEditorApp
//
//  Created by Lilly Aizawa Romo on 08/08/25.
//

import Foundation

class MemoryController {
    // Presupuesto de memoria en bytes
    private let maxBudget: Int
    // Uso actual de memoria
    private var currentUsage: Int = 0

    init(maxBudget: Int) {
        self.maxBudget = maxBudget
        print("Controlador de memoria inicializado con un presupuesto de \(maxBudget) bytes.")
    }

    /// Intenta asignar memoria. Devuelve `false` si excede el presupuesto.
    func allocate(bytes: Int) -> Bool {
        if currentUsage + bytes > maxBudget {
            // No imprimir aquí, solo devolver el resultado
            print("Surpassed Memory Heap: ", maxBudget);
            return false
        }
        currentUsage += bytes
        // No imprimir aquí, solo devolver el resultado
        return true
    }

    func deallocate(bytes: Int) {
        currentUsage -= bytes
    }
}
