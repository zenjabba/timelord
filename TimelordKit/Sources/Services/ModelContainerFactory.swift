import Foundation
import SwiftData

public enum ModelContainerFactory {
    public static func create(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            Client.self,
            Project.self,
            TimeEntry.self,
            Invoice.self,
            InvoiceLineItem.self
        ])

        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
        }

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    public static func preview() throws -> ModelContainer {
        try create(inMemory: true)
    }
}
