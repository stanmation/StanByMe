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
    var partnerUID: String?
    
    @IBOutlet weak var myTableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureDatabase()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is MessageViewController {
            let controller = segue.destination as! MessageViewController
            controller.partnerUID = partnerUID
        }
    }
    
    func configureDatabase() {
        ref = FIRDatabase.database().reference()
        
        // get the userID
        let currentUserID = FIRAuth.auth()?.currentUser?.uid

        _refHandle = self.ref.child("user-messages").child(currentUserID!).queryOrdered(byChild: "lastUpdate").observe(.value, with: { [weak self] (snapshot) -> Void in
            guard let strongSelf = self else { return }
            
            var tempUserMessages = [FIRDataSnapshot]()
            
            if let snapshots = snapshot.children.allObjects as? [FIRDataSnapshot] {
                for snap in snapshots {
                    tempUserMessages.append(snap)
                }
            }
            
            strongSelf.userMessages = tempUserMessages
            strongSelf.myTableView.reloadData()
            strongSelf.userMessages = strongSelf.userMessages.reversed()
        })
  
    }

    
    //MARK: Delegate Methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return userMessages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.myTableView.dequeueReusableCell(withIdentifier: "tableViewCell") as! ChatTableViewCell!
        
        // get message data
        let userMessagesSnapshot = userMessages[indexPath.row]
        let messages = userMessagesSnapshot.childSnapshot(forPath: "messages").children.allObjects as! [FIRDataSnapshot]
        let message = messages.last?.value as! [String: String]
        let messageText = message["text"]
        
        let isRead = userMessagesSnapshot.childSnapshot(forPath: "read").value as! String
        
        if isRead == "unread" {
            cell?.backgroundColor = UIColor.red
        } else {
            cell?.backgroundColor = UIColor.clear
        }
        
        // get user data
        let nickname = userMessagesSnapshot.childSnapshot(forPath: "partnerNickname").value as! String

        cell?.nicknameLabel?.text = nickname
        cell?.messageTextField?.text = messageText
        
        if let imageURL = userMessagesSnapshot.childSnapshot(forPath: "imageURL").value as? String, imageURL.hasPrefix("gs://") {
            FIRStorage.storage().reference(forURL: imageURL).data(withMaxSize: INT64_MAX){ (data, error) in
                if let error = error {
                    print("Error downloading: \(error)")
                    return
                }
                cell?.profileImageView?.image = UIImage(data: data!)
            }
        } else {
            cell?.profileImageView?.image = UIImage(named: "NoImage")
        }

        return cell!
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let userMessagesSnapshot = userMessages[indexPath.row]
        partnerUID = userMessagesSnapshot.key
        tableView.deselectRow(at: indexPath, animated: false)
        performSegue(withIdentifier: Constants.Segues.ToMessageVC, sender: nil)
    }
    
    
    


}
