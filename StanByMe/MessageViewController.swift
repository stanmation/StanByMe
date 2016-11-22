//
//  MessageViewController.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 29/10/2016.
//  Copyright © 2016 Stanley Darmawan. All rights reserved.
//

import UIKit
import Firebase

class MessageViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    @IBOutlet weak var newMessageTextField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    
    var ref: FIRDatabaseReference!
    var messages = [FIRDataSnapshot]()
    var currentUserData = FIRDataSnapshot()
    var partnerUserData = FIRDataSnapshot()

    fileprivate var _userMessageRefHandle: FIRDatabaseHandle!
    fileprivate var _currentUserRefHandle: FIRDatabaseHandle!
    fileprivate var _partnerUserRefHandle: FIRDatabaseHandle!

    var currentUserID: String!
    var partnerUID: String!
    
    var storageRef: FIRStorageReference!
    var remoteConfig: FIRRemoteConfig!
    
    @IBOutlet weak var myTableView: UITableView!


    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureDatabase()
        configureStorage()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        navigationController?.popToRootViewController(animated: false)
    }
    
    deinit {
        self.ref.child("user-messages").removeObserver(withHandle: _userMessageRefHandle)
        self.ref.child("users").removeObserver(withHandle: _currentUserRefHandle)
        self.ref.child("users").removeObserver(withHandle: _partnerUserRefHandle)

    }
    
    func configureDatabase() {
        ref = FIRDatabase.database().reference()
        
        // get the userID
        currentUserID = FIRAuth.auth()?.currentUser?.uid
        
        // get user snapshot
        
        _currentUserRefHandle = ref.child("users").child(currentUserID!).observe(.value, with: { [weak self] (snapshot) -> Void in
            guard let strongSelf = self else { return }
            strongSelf.currentUserData = snapshot
            strongSelf.getPartnerSnapshot()
            })

    }
    
    func getPartnerSnapshot() {
        _partnerUserRefHandle = ref.child("users").child(partnerUID!).observe(.value, with: { [weak self] (snapshot) -> Void in
            guard let strongSelf = self else { return }
            strongSelf.partnerUserData = snapshot
            strongSelf.getMessagesSnapshot()
            })
        
    }
    
    func getMessagesSnapshot() {

        _userMessageRefHandle = self.ref.child("user-messages").child(currentUserID!).child(partnerUID).child("messages").observe(.childAdded, with: { [weak self] (snapshot) -> Void in
            guard let strongSelf = self else { return }
            strongSelf.messages.append(snapshot)
            strongSelf.myTableView.insertRows(at: [IndexPath(row: strongSelf.messages.count-1, section: 0)], with: .automatic)
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
        
        var nickname = String()
        
        print("currentUserData: \(currentUserData), currentMessage: \(messages), partenerData: \(partnerUserData)")

        if let status = message["status"] {
            if status == "sender" {
                let currentUserDict = self.currentUserData.value as! Dictionary<String, String>
                nickname = currentUserDict["nickname"]!
            } else {
                let partnerUserDict = self.partnerUserData.value as! Dictionary<String, String>
                nickname = partnerUserDict["nickname"]!
            }
        }
        
        let text = message[Constants.MessageFields.Text] as String!
        cell?.textLabel?.text = nickname + ": " + text!

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
        let currentUserUID = currentUserDict[Constants.MessageFields.UID] as String!

        var myData = [String: String]()
        myData["status"] = "sender"
        myData[Constants.MessageFields.Text] = text
        
        // set up partner data

        var partnerData = [String: String]()
        partnerData["status"] = "receiver"
        partnerData[Constants.MessageFields.Text] = text

        // setup the date
        let dateformatter = DateFormatter()
        dateformatter.dateFormat = "MM/dd/yy h:mm a Z"
        let now = dateformatter.string(from: Date())

        
        // Push data to Firebase Database
        ref.child("user-messages").child(currentUserUID!).child(partnerUID).child("messages").childByAutoId().setValue(myData)
        ref.child("user-messages").child(partnerUID).child(currentUserUID!).child("messages").childByAutoId().setValue(partnerData)
        
        // set timeStamp
        ref.child("user-messages").child(currentUserUID!).child(partnerUID).child("lastUpdate").setValue(now)
        ref.child("user-messages").child(partnerUID).child(currentUserUID!).child("lastUpdate").setValue(now)
        
        // set the read key to "read" in user-messages
        ref.child("user-messages").child(currentUserID!).child(partnerUID).child("read").setValue("read")
        
        // set partner data in user-messages
        let partnerUserDict = partnerUserData.value as! [String: String]
        let partnerNickname = partnerUserDict["nickname"]!
        ref.child("user-messages").child(currentUserID!).child(partnerUID).child("partnerNickname").setValue(partnerNickname)
        let partnerThumbnailURL = partnerUserDict[Constants.Users.ThumbnailURL]!
        ref.child("user-messages").child(currentUserID!).child(partnerUID).child(Constants.MessageFields.ThumbnailURL).setValue(partnerThumbnailURL)
    }
    


}
