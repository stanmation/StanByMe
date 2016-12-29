//
//  Message+CoreDataClass.swift
//  
//
//  Created by Stanley Darmawan on 28/12/2016.
//
//

import Foundation
import CoreData


public class Message: NSManagedObject {
	convenience init(messageId: String,
	                 status: String = "sender",
	                 text: String?,
	                 thumbnailURL: String?,
	                 thumbnailData: Data?,
	                 context: NSManagedObjectContext) {
		
		// An EntityDescription is an object that has access to all
		// the information you provided in the Entity part of the model
		// you need it to create an instance of this class.
		if let ent = NSEntityDescription.entity(forEntityName: "Message", in: context) {
			self.init(entity: ent, insertInto: context)
			self.dateUpdated = NSDate()
			self.id = messageId
			self.status = status
			self.text = text
			self.thumbnailURL = thumbnailURL
			self.thumbnailData = thumbnailData
		} else {
			fatalError("Unable to find Entity name!")
		}
	}
}
