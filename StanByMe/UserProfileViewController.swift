//
//  UserProfileViewController.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 10/11/2016.
//  Copyright © 2016 Stanley Darmawan. All rights reserved.
//

import UIKit
import Firebase
import CoreData

class UserProfileViewController: UIViewController {
    
    var chat: Chat?
    var user: [String: String]!
    var distance: Double!
    
    @IBOutlet weak var nicknameLabel: UILabel!
    @IBOutlet weak var distanceTextField: UITextField!
    @IBOutlet weak var aboutMeTextView: UITextView!
    @IBOutlet weak var lookingForTextView: UITextView!
    @IBOutlet weak var profilePicImageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let currentUserID = FIRAuth.auth()?.currentUser?.uid
        
        let stack = (UIApplication.shared.delegate as! AppDelegate).stack

        let fr = NSFetchRequest<Chat>(entityName: "Chat")
        fr.sortDescriptors = []
        let pred = NSPredicate(format: "currentUserId == %@ && partnerId == %@", currentUserID!, user["uid"]!)
        fr.predicate = pred
        
        guard let chatsFound = try? stack.context.fetch(fr) else {
            print("An error occurred while retrieving chats")
            return
        }
        
        if chatsFound != [] {
            chat = chatsFound[0]
        }
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: stack.context, sectionNameKeyPath: nil, cacheName: nil)
        
        do {
            try fetchedResultsController.performFetch()
        } catch let e as NSError {
            print("Error while trying to perform a search: \n\(e)\n\(fetchedResultsController)")
        }
        
        
        getDataFromDB()
        fetchUserInfo()
        
        title = user["nickname"]
    }
    
    
    func getDataFromDB() {
        if let imageURL = user[Constants.Users.ImageURL] {
            if imageURL.hasPrefix("gs://") {
                FIRStorage.storage().reference(forURL: imageURL).data(withMaxSize: INT64_MAX){ (data, error) in
                    if let error = error {
                        print("Error downloading: \(error)")
                        return
                    }
                    self.profilePicImageView.image = UIImage.init(data: data!)
                }
            } else if let URL = URL(string: imageURL), let data = try? Data(contentsOf: URL) {
                
                self.profilePicImageView.image = UIImage.init(data: data)
            }
        } else {
            self.profilePicImageView.image  = UIImage(named: "NoImage")
            if let photoURL = user[Constants.Users.ImageURL], let URL = URL(string: photoURL), let data = try? Data(contentsOf: URL) {
                self.profilePicImageView.image  = UIImage(data: data)
            }
        }
        
    }
    
    func fetchUserInfo() {
        nicknameLabel.text = user["nickname"]
        
        let aboutMeArray = breakingSentenceIntoKeywords(sentence: user["aboutMe"]!)
        aboutMeTextView.text = "About Me:"
        for aboutMe in aboutMeArray {
            aboutMeTextView.text.append("\n\(aboutMe)")
        }
        
        let lookingForArray = breakingSentenceIntoKeywords(sentence: user["lookingFor"]!)
        lookingForTextView.text = "Looking For:"
        for lookingFor in lookingForArray {
            lookingForTextView.text.append("\n\(lookingFor)")
        }
        
        distanceTextField.text = String(distance) + " km"

    }
    
    func breakingSentenceIntoKeywords(sentence: String) -> [String]{
        let lowercaseSentence = sentence.lowercased()
        let arrayString = lowercaseSentence.components(separatedBy: " ")
        print("arrayString for \(sentence): \(arrayString)")
        return arrayString
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is MessageViewController {
            let controller = segue.destination as! MessageViewController
            controller.partnerUID = user["uid"]
            controller.chat = chat
        }
    }

    @IBAction func chatButtonPressed(_ sender: AnyObject) {
        performSegue(withIdentifier: Constants.Segues.ToMessageVC, sender: nil)
    }
    
    
}
