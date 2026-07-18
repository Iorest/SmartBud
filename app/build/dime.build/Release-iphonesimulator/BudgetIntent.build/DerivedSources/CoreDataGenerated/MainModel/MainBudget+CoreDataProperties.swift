//
//  MainBudget+CoreDataProperties.swift
//  
//
//  Created by alvin on 2026/7/18.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias MainBudgetCoreDataPropertiesSet = NSSet

extension MainBudget {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MainBudget> {
        return NSFetchRequest<MainBudget>(entityName: "MainBudget")
    }

    @NSManaged public var amount: Double
    @NSManaged public var dateCreated: Date?
    @NSManaged public var green: Bool
    @NSManaged public var startDate: Date?
    @NSManaged public var type: Int16

}

extension MainBudget : Identifiable {

}
