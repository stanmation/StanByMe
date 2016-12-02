//
//  Settings+CoreDataClass.swift
//  
//
//  Created by Stanley Darmawan on 2/12/2016.
//
//

import Foundation
import CoreData


public class Settings: NSManagedObject {
    convenience init(profilePic: Data?,
                     aboutYou: String,
                     lookingFor: String,
                     nickname: String,
                     context: NSManagedObjectContext) {
        
        // An EntityDescription is an object that has access to all
        // the information you provided in the Entity part of the model
        // you need it to create an instance of this class.
        if let ent = NSEntityDescription.entity(forEntityName: "Settings", in: context) {
            self.init(entity: ent, insertInto: context)
            
        } else {
            fatalError("Unable to find Entity name!")
        }
    }

}
