//
//  UserProfileViewController.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 10/11/2016.
//  Copyright © 2016 Stanley Darmawan. All rights reserved.
//

import UIKit
import Firebase

class UserProfileViewController: UIViewController {
    
    var partnerUID: String!
    var ref: FIRDatabaseReference!
    
    @IBOutlet weak var profilePicImageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        ref = FIRDatabase.database().reference()

        getDataFromDB()
    }
    
    
    func getDataFromDB() {
        ref.child("users").child(partnerUID).observeSingleEvent(of: .value, with: { [weak self] (snapshot)  in
            guard let strongSelf = self else { return }
            
            let user = snapshot.value as! Dictionary<String, String>
            if let imageURL = user[Constants.Users.ImageURL] {
                
                if imageURL.hasPrefix("gs://") {
                    
                    FIRStorage.storage().reference(forURL: imageURL).data(withMaxSize: INT64_MAX){ (data, error) in
                        if let error = error {
                            print("Error downloading: \(error)")
                            return
                        }
                        strongSelf.profilePicImageView.image = UIImage.init(data: data!)
                    }
                } else if let URL = URL(string: imageURL), let data = try? Data(contentsOf: URL) {
                    
                    strongSelf.profilePicImageView.image = UIImage.init(data: data)
                }
            } else {
                strongSelf.profilePicImageView.image  = UIImage(named: "NoImage")
                if let photoURL = user[Constants.Users.ImageURL], let URL = URL(string: photoURL), let data = try? Data(contentsOf: URL) {
                    strongSelf.profilePicImageView.image  = UIImage(data: data)
                }
            }
            
        })
        
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is MessageViewController {
            
            let controller = segue.destination as! MessageViewController
            controller.partnerUID = partnerUID
        }
    }

    @IBAction func chatButtonPressed(_ sender: AnyObject) {
        performSegue(withIdentifier: Constants.Segues.ToMessageVC, sender: nil)
    }
    
    
}
