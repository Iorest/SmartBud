//
//  Budget+CoreDataProperties.swift
//  
//
//  Created by alvin on 2026/7/18.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias BudgetCoreDataPropertiesSet = NSSet

extension Budget {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Budget> {
        return NSFetchRequest<Budget>(entityName: "Budget")
    }

    @NSManaged public var amount: Double
    @NSManaged public var dateCreated: Date?
    @NSManaged public var green: Bool
    @NSManaged public var id: UUID?
    @NSManaged public var startDate: Date?
    @NSManaged public var type: Int16
    @NSManaged public var category: Category?

}

extension Budget : Identifiable {

}
