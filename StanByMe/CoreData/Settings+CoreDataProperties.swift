//
//  Settings+CoreDataProperties.swift
//  
//
//  Created by Stanley Darmawan on 2/12/2016.
//
//

import Foundation
import CoreData


extension Settings {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Settings> {
        return NSFetchRequest<Settings>(entityName: "Settings");
    }

    @NSManaged public var profilePic: Data?
    @NSManaged public var lookingFor: String?
    @NSManaged public var aboutMe: String?
    @NSManaged public var nickname: String?

}
