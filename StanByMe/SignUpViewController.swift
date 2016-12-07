//
//  SignUpViewController.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 7/11/2016.
//  Copyright © 2016 Stanley Darmawan. All rights reserved.
//

import UIKit
import Firebase


class SignUpViewController: UIViewController, UIAlertViewDelegate {
    
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var nicknameField: UITextField!
    @IBOutlet weak var aboutMeField: UITextField!
    @IBOutlet weak var lookingForField: UITextField!
    
    var ref: FIRDatabaseReference!

    override func viewDidLoad() {
        super.viewDidLoad()

    }

    @IBAction func signUpTapped(_ sender: AnyObject) {
        if ((emailField.text == "") || (passwordField.text == "") || (nicknameField.text == "") || (aboutMeField.text == "") || (lookingForField.text) == "") {
            displayAlert(alertType: "emptyField", message: "Please fill in all the fields")
        } else {
            guard let email = emailField.text, let password = passwordField.text else {return}
            FIRAuth.auth()?.createUser(withEmail: email, password: password, completion: { (user, error) in
                if let error = error {
                    print(error.localizedDescription)
                    self.displayAlert(alertType: "badCredentials", message: error.localizedDescription)
                    return
                } else {
                    print(user)
                }
                self.signedIn(FIRAuth.auth()?.currentUser)
            })
        }
        
    }
    
    @IBAction func closeButtonTapped(_ sender: AnyObject) {
        dismiss(animated: true, completion: nil)    
    }
    
    
    func signedIn(_ user: FIRUser?) {
        
        AppState.sharedInstance.displayName = user?.displayName ?? user?.email
        AppState.sharedInstance.photoURL = user?.photoURL
        AppState.sharedInstance.signedIn = true
        let notificationName = Notification.Name(rawValue: Constants.NotificationKeys.SignedIn)
        NotificationCenter.default.post(name: notificationName, object: nil, userInfo: nil)
        pushUserDataToDB()
        dismiss(animated: true, completion: nil)
    }
    
    func pushUserDataToDB() {
        ref = FIRDatabase.database().reference()
        
        // get the userID
        let currentUserID = FIRAuth.auth()?.currentUser?.uid
        
        var currentUserData = [String: String]()
        currentUserData[Constants.Users.Nickname] = nicknameField.text
        currentUserData[Constants.Users.LookingFor] = lookingForField.text
        currentUserData[Constants.Users.UID] = currentUserID
        currentUserData[Constants.Users.AboutMe] = aboutMeField.text
        
        ref.child("users").child(currentUserID!).setValue(currentUserData)
    }
    
    func displayAlert(alertType: String, message: String) {
        let alert = UIAlertController(title: "", message: "", preferredStyle: .alert)
        if alertType == "emptyField" {
            alert.title = "Error"
            alert.message = message
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        } else if alertType == "badCredentials" {
            alert.title = "Error"
            alert.message = message
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        }
        present(alert, animated: true, completion: nil)
    }

}
