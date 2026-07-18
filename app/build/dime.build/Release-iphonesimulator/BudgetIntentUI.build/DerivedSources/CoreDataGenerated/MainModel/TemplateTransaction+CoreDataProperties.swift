//
//  TemplateTransaction+CoreDataProperties.swift
//  
//
//  Created by alvin on 2026/7/18.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias TemplateTransactionCoreDataPropertiesSet = NSSet

extension TemplateTransaction {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TemplateTransaction> {
        return NSFetchRequest<TemplateTransaction>(entityName: "TemplateTransaction")
    }

    @NSManaged public var amount: Double
    @NSManaged public var id: UUID?
    @NSManaged public var income: Bool
    @NSManaged public var note: String?
    @NSManaged public var order: Int16
    @NSManaged public var recurringCoefficient: Int16
    @NSManaged public var recurringType: Int16
    @NSManaged public var category: Category?

}

extension TemplateTransaction : Identifiable {

}
