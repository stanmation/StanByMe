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
    
    // Instance variables
    @IBOutlet weak var newMessageTextField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    var ref: FIRDatabaseReference!
    var messages: [FIRDataSnapshot]! = []
    var currentUserData: FIRDataSnapshot!
    var partnerUserData: FIRDataSnapshot!


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
        let userID = FIRAuth.auth()?.currentUser?.uid
        
        // Listen for new messages in the Firebase database

        _userMessageRefHandle = self.ref.child("user-messages").child(userID!).child(partnerUID).observe(.childAdded, with: { [weak self] (snapshot) -> Void in
            guard let strongSelf = self else { return }
            strongSelf.messages.append(snapshot)
            strongSelf.myTableView.insertRows(at: [IndexPath(row: strongSelf.messages.count-1, section: 0)], with: .automatic)
        })
        
        
        _currentUserRefHandle = ref.child("users").observe(.childAdded, with: { [weak self] (snapshot) -> Void in
            
            guard let strongSelf = self else { return }
            
            let dict = snapshot.value as! Dictionary<String, String>
            
            if let uid = dict["uid"] as String! {
                if uid == userID {
                    strongSelf.currentUserData=snapshot
                } else if uid == strongSelf.partnerUID {
                    strongSelf.partnerUserData=snapshot
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
        let nickname = message[Constants.MessageFields.nickname] as String!

        let text = message[Constants.MessageFields.text] as String!
        cell?.textLabel?.text = nickname! + ": " + text!

        return cell!

    }

    // UITextViewDelegate protocol methods
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        // get the current nickname & UID
        
        let dict = currentUserData.value as! Dictionary<String, String>

        let currentUserNickname = dict["nickname"] as String!
        let currentUID = dict["uid"] as String!

        sendMessage(userID: currentUID!, nickname: currentUserNickname!, text: textField.text!)
        textField.text = ""
        
        print(currentUserData)

        return true
    }
    
    func sendMessage(userID: String, nickname: String, text: String) {
        
        var mdata = [String: String]()
        mdata[Constants.MessageFields.nickname] = nickname
        mdata["uid"] = userID
        mdata[Constants.MessageFields.text] = text
        
        // grab the partner data
        let dict = partnerUserData.value as! Dictionary<String, String>

        if let partnerNickname = dict["nickname"] as String! {
            mdata["partnerNickname"] = partnerNickname
        }
        // Push data to Firebase Database
        ref.child("user-messages").child(userID).child(partnerUID).childByAutoId().setValue(mdata)
        ref.child("user-messages").child(partnerUID).child(userID).childByAutoId().setValue(mdata)
        

    }
    


}
