//
//  Message+CoreDataProperties.swift
//  
//
//  Created by Stanley Darmawan on 26/11/2016.
//
//

import Foundation
import CoreData


extension Message {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Message> {
        return NSFetchRequest<Message>(entityName: "Message");
    }

    @NSManaged public var status: String?
    @NSManaged public var text: String?
    @NSManaged public var id: String?
    @NSManaged public var dateUpdated: NSDate?
    @NSManaged public var chat: Chat?

}
