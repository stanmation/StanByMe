//
//  Chat+CoreDataProperties.swift
//  
//
//  Created by Stanley Darmawan on 2/12/2016.
//
//

import Foundation
import CoreData

extension Chat {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Chat> {
        return NSFetchRequest<Chat>(entityName: "Chat");
    }

    @NSManaged public var currentUserId: String?
    @NSManaged public var lastMessage: String?
    @NSManaged public var lastUpdate: String?
    @NSManaged public var partnerId: String?
    @NSManaged public var partnerNickname: String?
    @NSManaged public var read: String?
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var messages: NSSet?

}

// MARK: Generated accessors for messages
extension Chat {

    @objc(addMessagesObject:)
    @NSManaged public func addToMessages(_ value: Message)

    @objc(removeMessagesObject:)
    @NSManaged public func removeFromMessages(_ value: Message)

    @objc(addMessages:)
    @NSManaged public func addToMessages(_ values: NSSet)

    @objc(removeMessages:)
    @NSManaged public func removeFromMessages(_ values: NSSet)

}
