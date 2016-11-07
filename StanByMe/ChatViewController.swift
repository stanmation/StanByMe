//
//  ChatViewController.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 29/10/2016.
//  Copyright © 2016 Stanley Darmawan. All rights reserved.
//

import UIKit
import Firebase

class ChatViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    @IBOutlet weak var newMessageTextField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    var ref: FIRDatabaseReference!
    var messages = [FIRDataSnapshot]()
    var currentUserData = FIRDataSnapshot()
    var partnerUserData = FIRDataSnapshot()

    fileprivate var _userMessageRefHandle: FIRDatabaseHandle!
    fileprivate var _currentUserRefHandle: FIRDatabaseHandle!

    var partnerUID: String!
    
    var storageRef: FIRStorageReference!
    var remoteConfig: FIRRemoteConfig!
    
    @IBOutlet weak var myTableView: UITableView!


    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureDatabase()
        configureStorage()
    }
    
    deinit {
        self.ref.child("user-messages").removeObserver(withHandle: _userMessageRefHandle)
        self.ref.child("users").removeObserver(withHandle: _currentUserRefHandle)

    }
    
    func configureDatabase() {
        ref = FIRDatabase.database().reference()
        
        // get the userID
        let currentUserID = FIRAuth.auth()?.currentUser?.uid
 
        // Listen for new messages in the Firebase database

        _userMessageRefHandle = self.ref.child("user-messages").child(currentUserID!).child(partnerUID).observe(.childAdded, with: { [weak self] (snapshot) -> Void in
            guard let strongSelf = self else { return }
            strongSelf.messages.append(snapshot)
//            strongSelf.myTableView.insertRows(at: [IndexPath(row: strongSelf.messages.count-1, section: 0)], with: .automatic)
            strongSelf.myTableView.reloadData()
        })
        
        _currentUserRefHandle = ref.child("users").observe(.childAdded, with: { [weak self] (snapshot) -> Void in
            guard let strongSelf = self else { return }
            let dict = snapshot.value as! Dictionary<String, String>
            if let uid = dict[Constants.Users.UID] as String! {
                if uid == currentUserID {
                    strongSelf.currentUserData = snapshot
                } else if uid == strongSelf.partnerUID {
                    strongSelf.partnerUserData = snapshot
                }
            }
            
        })
        
        

    }
    
    func configureStorage() {
        storageRef = FIRStorage.storage().reference(forURL: "gs://stanbyme-2e590.appspot.com")
    }
    
    @IBAction func didSendMessage(_ sender: UIButton) {
        textFieldShouldReturn(newMessageTextField)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Dequeue cell
        let cell = self.myTableView.dequeueReusableCell(withIdentifier: "tableViewCell") as UITableViewCell!
        // Unpack message from Firebase DataSnapshot
        let messageSnapshot: FIRDataSnapshot! = self.messages[indexPath.row]
        let message = messageSnapshot.value as! Dictionary<String, String>
        let nickname = message[Constants.MessageFields.Nickname] as String!

        let text = message[Constants.MessageFields.Text] as String!
        cell?.textLabel?.text = nickname! + ": " + text!

        return cell!

    }

    // UITextViewDelegate protocol methods
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {

        sendMessage(text: textField.text!)
        textField.text = ""
        
        return true
    }
    
    func sendMessage(text: String) {
        
        // set up current user data
        let currentUserDict = self.currentUserData.value as! Dictionary<String, String>
        let currentUserNickname = currentUserDict[Constants.MessageFields.Nickname] as String!
        let currentUserUID = currentUserDict[Constants.MessageFields.UID] as String!

        var myData = [String: String]()
        myData[Constants.MessageFields.Nickname] = currentUserNickname
        myData[Constants.MessageFields.UID] = currentUserUID
        myData[Constants.MessageFields.Text] = text
        
        let partnerDict = partnerUserData.value as! Dictionary<String, String>

        if let partnerNickname = partnerDict[Constants.MessageFields.Nickname] as String! {
            myData[Constants.MessageFields.PartnerNickname] = partnerNickname
        }
        
        // set up partner data

        var partnerData = [String: String]()
        partnerData[Constants.MessageFields.Nickname] = currentUserNickname
            partnerData[Constants.MessageFields.UID] = partnerUID
        partnerData[Constants.MessageFields.Text] = text
        partnerData[Constants.MessageFields.PartnerNickname] = partnerDict[Constants.MessageFields.Nickname]

        
        // Push data to Firebase Database
        ref.child("user-messages").child(currentUserUID!).child(partnerUID).childByAutoId().setValue(myData)
        ref.child("user-messages").child(partnerUID).child(currentUserUID!).childByAutoId().setValue(partnerData)
        

    }
    


}
