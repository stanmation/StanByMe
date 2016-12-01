//
//  Chat+CoreDataClass.swift
//  
//
//  Created by Stanley Darmawan on 28/11/2016.
//
//

import Foundation
import CoreData


public class Chat: NSManagedObject {
    
    convenience init(currentUserId: String,
                     partnerId: String,
                     partnerNickname: String,
                     lastUpdate: String,
                     read: String,
                     lastMessage: String,
                     //                     imageUrl: String,
        //                     thumbnailUrl: String,
                    thumbnailData: Data?,
        context: NSManagedObjectContext) {
        
        // An EntityDescription is an object that has access to all
        // the information you provided in the Entity part of the model
        // you need it to create an instance of this class.
        if let ent = NSEntityDescription.entity(forEntityName: "Chat", in: context) {
            self.init(entity: ent, insertInto: context)
            self.currentUserId = currentUserId
            //            self.imageUrl = imageUrl
            self.lastUpdate = lastUpdate
            self.partnerId = partnerId
            self.partnerNickname = partnerNickname
            self.read = read
            self.lastMessage = lastMessage
            
            //            self.thumbnailUrl = thumbnailUrl
            self.thumbnailData = thumbnailData
        } else {
            fatalError("Unable to find Entity name!")
        }
    }

}
