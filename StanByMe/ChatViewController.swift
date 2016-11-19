//
//  ChatViewController.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 19/11/2016.
//  Copyright © 2016 Stanley Darmawan. All rights reserved.
//

import UIKit
import Firebase

class ChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var ref: FIRDatabaseReference!
    fileprivate var _refHandle: FIRDatabaseHandle!
    
    var userMessages = [FIRDataSnapshot]()
    var users = [FIRDataSnapshot]()
    
    @IBOutlet weak var myTableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        configureDatabase()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    
    func configureDatabase() {
        ref = FIRDatabase.database().reference()
        
        // get the userID
        let currentUserID = FIRAuth.auth()?.currentUser?.uid

        _refHandle = self.ref.child("user-messages").child(currentUserID!).queryOrdered(byChild: "lastUpdate").observe(.value, with: { [weak self] (snapshot) -> Void in
            guard let strongSelf = self else { return }
            
            var tempUserMessages = [FIRDataSnapshot]()
            var tempUsers = [FIRDataSnapshot]()
            
            if let snapshots = snapshot.children.allObjects as? [FIRDataSnapshot] {
                for snap in snapshots {
                    strongSelf.ref.child("users").child(snap.key).observeSingleEvent(of: .value, with: { (userSnapshot) -> Void in
                        tempUserMessages.append(snap)
                        tempUsers.append(userSnapshot)
                        strongSelf.userMessages = tempUserMessages
                        strongSelf.users = tempUsers
                        strongSelf.myTableView.reloadData()
                        if snap == snapshots.last { strongSelf.reverseArray()}
                    })
                }
            }


        })
  
    }

    func reverseArray() {
        userMessages = userMessages.reversed()
        users = users.reversed()

    }
    
    //MARK: Delegate Methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return userMessages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.myTableView.dequeueReusableCell(withIdentifier: "tableViewCell") as UITableViewCell!
        
        // get message data
        let userMessagesSnapshot = userMessages[indexPath.row]
        let messages = userMessagesSnapshot.childSnapshot(forPath: "messages").children.allObjects as! [FIRDataSnapshot]
        let message = messages.last?.value as! [String: String]
        
        let messageText = message["text"]
        
        // get user data
        let userSnapshot = users[indexPath.row].value as! [String: String]
        let nickname = userSnapshot["nickname"]

        cell?.detailTextLabel?.text = messageText
        cell?.textLabel?.text = nickname
        
        return cell!
        
    }


}
