//: Playground - noun: a place where people can play

import CoreLocation
import UIKit

let ref = FIRDatabase.database().reference()


ref.child("users").child(userID!).observeSingleEvent(of: .value, with: { (snapshot) in
    // Get user value
    let value = snapshot.value as? NSDictionary
    let username = value?["username"] as! String
    let user = User.init(username: username)
    
    // ...
}) { (error) in
    print(error.localizedDescription)
}
