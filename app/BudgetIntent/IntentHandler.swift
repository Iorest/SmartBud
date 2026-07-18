//
//  IntentHandler.swift
//  BudgetIntent
//
//  Created by Rafael Soh on 17/8/22.
//

import Intents
import CoreData

class IntentHandler: INExtension, BudgetWidgetConfigurationIntentHandling {

    // Minimal NSPersistentContainer for the BudgetIntent extension.
    // This extension runs in a separate process and must not reference
    // DataController or SwiftData at all.
    private let persistentContainer: NSPersistentContainer = {
        let modelURL = Bundle.main.url(
            forResource: "BudgetIntentModel",
            withExtension: "momd"
        )!
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load BudgetIntentModel")
        }

        let container = NSPersistentContainer(name: "BudgetIntentModel", managedObjectModel: model)

        let description = NSPersistentStoreDescription()

        let groupID = "group.com.rafaelsoh.dime"
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            description.url = url.appendingPathComponent("Main.sqlite")
        }

        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("BudgetIntent: store load error: \(error)")
            }
        }

        return container
    }()

    func provideBudgetOptionsCollection(for _: BudgetWidgetConfigurationIntent, with completion: @escaping (INObjectCollection<WidgetBudget>?, Error?) -> Void) {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Budget")

        let budgets: [NSManagedObject]

        do {
            budgets = try context.fetch(request)
        } catch {
            completion(nil, error)
            return
        }

        let items: [WidgetBudget] = budgets.compactMap { budget in
            guard let uuid = budget.value(forKey: "id") as? UUID else { return nil }

            let category = budget.value(forKey: "category") as? NSManagedObject
            let name = category?.value(forKey: "name") as? String ?? "Budget"

            return WidgetBudget(identifier: uuid.uuidString, display: name)
        }

        let collection = INObjectCollection(items: items)
        completion(collection, nil)
    }

    override func handler(for _: INIntent) -> Any {
        return self
    }
}
