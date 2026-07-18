//
//  Category+CoreDataProperties.swift
//  
//
//  Created by alvin on 2026/7/18.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias CategoryCoreDataPropertiesSet = NSSet

extension Category {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Category> {
        return NSFetchRequest<Category>(entityName: "Category")
    }

    @NSManaged public var colour: String?
    @NSManaged public var dateCreated: Date?
    @NSManaged public var emoji: String?
    @NSManaged public var id: UUID?
    @NSManaged public var income: Bool
    @NSManaged public var name: String?
    @NSManaged public var order: Int64
    @NSManaged public var budget: Budget?
    @NSManaged public var templates: NSSet?
    @NSManaged public var transactions: NSSet?

}

// MARK: Generated accessors for templates
extension Category {

    @objc(addTemplatesObject:)
    @NSManaged public func addToTemplates(_ value: TemplateTransaction)

    @objc(removeTemplatesObject:)
    @NSManaged public func removeFromTemplates(_ value: TemplateTransaction)

    @objc(addTemplates:)
    @NSManaged public func addToTemplates(_ values: NSSet)

    @objc(removeTemplates:)
    @NSManaged public func removeFromTemplates(_ values: NSSet)

}

// MARK: Generated accessors for transactions
extension Category {

    @objc(addTransactionsObject:)
    @NSManaged public func addToTransactions(_ value: Transaction)

    @objc(removeTransactionsObject:)
    @NSManaged public func removeFromTransactions(_ value: Transaction)

    @objc(addTransactions:)
    @NSManaged public func addToTransactions(_ values: NSSet)

    @objc(removeTransactions:)
    @NSManaged public func removeFromTransactions(_ values: NSSet)

}

extension Category : Identifiable {

}
