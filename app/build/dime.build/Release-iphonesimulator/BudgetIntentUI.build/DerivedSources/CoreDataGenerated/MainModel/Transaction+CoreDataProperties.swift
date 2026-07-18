//
//  Transaction+CoreDataProperties.swift
//  
//
//  Created by alvin on 2026/7/18.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias TransactionCoreDataPropertiesSet = NSSet

extension Transaction {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Transaction> {
        return NSFetchRequest<Transaction>(entityName: "Transaction")
    }

    @NSManaged public var amount: Double
    @NSManaged public var date: Date?
    @NSManaged public var day: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var income: Bool
    @NSManaged public var month: Date?
    @NSManaged public var note: String?
    @NSManaged public var onceRecurring: Bool
    @NSManaged public var recurringCoefficient: Int16
    @NSManaged public var recurringType: Int16
    @NSManaged public var category: Category?

}

extension Transaction : Identifiable {

}
