//
//  MessageViewController.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 29/10/2016.
//  Copyright © 2016 Stanley Darmawan. All rights reserved.
//

import UIKit
import Firebase
import CoreData

class MessageViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate {
    
    var fr: NSFetchRequest<Message>!
    var fetchedResultsController: NSFetchedResultsController<Message>?

    let stack = (UIApplication.shared.delegate as! AppDelegate).stack

    var chat : Chat?

    @IBOutlet weak var newMessageTextField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    
    var ref: FIRDatabaseReference!
    var messages = [FIRDataSnapshot]()
    var currentUserData = FIRDataSnapshot()
    var partnerUserData = FIRDataSnapshot()
    var partnerNickname: String?

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
        
        executeSearch()
    
        // Create a fetchrequest
        fr = NSFetchRequest<Message>(entityName: "Message")
        fr.sortDescriptors = [NSSortDescriptor(key: "dateUpdated", ascending: true)]
        
        if chat != nil {
            let pred = NSPredicate(format: "chat == %@", chat!)
            fr.predicate = pred
        }

        // Create the FetchedResultsController
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: stack.context, sectionNameKeyPath: nil, cacheName: nil)
        
        do {
            try fetchedResultsController!.performFetch()
        } catch let e as NSError {
            print("Error while trying to perform a search: \n\(e)\n\(fetchedResultsController)")
        }
        
        fetchedResultsController?.delegate = self
        
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
//            strongSelf.myTableView.insertRows(at: [IndexPath(row: strongSelf.messages.count-1, section: 0)], with: .automatic)
            
            let message = snapshot.value as! [String: String]
            var nickname = String()

            if let status = message["status"] {
                if status == "sender" {
                    let currentUserDict = strongSelf.currentUserData.value as! [String: String]
                    nickname = currentUserDict["nickname"]!
                } else {
                    let partnerUserDict = strongSelf.partnerUserData.value as! [String: String]
                    nickname = partnerUserDict["nickname"]!
                }
            }
            
            let chatFr = NSFetchRequest<Chat>(entityName: "Chat")
            let chatPred = NSPredicate(format: "currentUserId == %@ && partnerId == %@", strongSelf.currentUserID, strongSelf.partnerUID)
            chatFr.predicate = chatPred
            
            guard let chatsFound = try? strongSelf.stack.context.fetch(chatFr) else {
                print("An error occurred while retrieving chats")
                return
            }
            
            if chatsFound == [] {
                let partnerUserDict = strongSelf.partnerUserData.value as! [String: String]
                let thumbnailData = Data()
                let chat = Chat(currentUserId: strongSelf.currentUserID, partnerId: strongSelf.partnerUID, partnerNickname: partnerUserDict["nickname"]!, lastUpdate: "", read: "read", lastMessage: message["text"]!, thumbnailData: thumbnailData, context: strongSelf.stack.context)
                strongSelf.chat = chat
            } else {
                strongSelf.chat = chatsFound[0]
            }
            
            let predicate = NSPredicate(format: "id == %@ && chat == %@", snapshot.key, strongSelf.chat!)
            
            
            strongSelf.fr.predicate = predicate
            
            guard let messagesFound = try? strongSelf.stack.context.fetch(strongSelf.fr) else {
                print("An error occurred while retrieving messages")
                return
            }
            
            if messagesFound == [] {
                let newMessage = Message(messageId: snapshot.key, status: message["status"]!, text: message["text"]!, context: strongSelf.stack.context)
                
                newMessage.chat = strongSelf.chat
            
            }
            
            print("end of message closure")
        })

    }
    
    
    func configureStorage() {
        storageRef = FIRStorage.storage().reference(forURL: "gs://stanbyme-2e590.appspot.com")
    }
    
    @IBAction func didSendMessage(_ sender: UIButton) {
        textFieldShouldReturn(newMessageTextField)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController?.sections?.count ?? 0

    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        return messages.count
        let sectionInfo = fetchedResultsController?.sections![section]
        return sectionInfo!.numberOfObjects

    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Coredata
        
        let message = fetchedResultsController?.object(at: indexPath)
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "tableViewCell", for: indexPath) as UITableViewCell
        
        cell.textLabel?.text = message?.text

        return cell

    }

    

    // UITextViewDelegate protocol methods
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {

        sendMessage(text: textField.text!)
        textField.text = ""
        
        return true
    }
    
    
    func sendMessage(text: String) {
        
        // setup the date
        let dateformatter = DateFormatter()
        dateformatter.dateFormat = "MM/dd/yy h:mm a Z"
        let now = dateformatter.string(from: Date())
        
        // set up current user data
        let currentUserDict = self.currentUserData.value as! Dictionary<String, String>
        let currentUserUID = currentUserDict[Constants.MessageFields.UID] as String!
        let currentUserNickname = currentUserDict["nickname"] as String!

        // set partner data in user-messages
        let partnerUserDict = partnerUserData.value as! [String: String]
        let partnerNickname = partnerUserDict["nickname"]!
        
        var myData = [String: String]()
        myData["status"] = "sender"
        myData[Constants.MessageFields.Text] = text
        
        let currentUserThumbnailURL = currentUserDict[Constants.Users.ThumbnailURL]!
        let partnerThumbnailURL = partnerUserDict[Constants.Users.ThumbnailURL]!

        var myChatData = [String: String]()
        myChatData["lastUpdate"] = now
        myChatData["lastMessage"] = text
        myChatData["partnerNickname"] = partnerNickname
        myChatData["read"] = "read"
        myChatData[Constants.MessageFields.ThumbnailURL] = partnerThumbnailURL

        // set up partner data
        var partnerData = [String: String]()
        partnerData["status"] = "receiver"
        partnerData[Constants.MessageFields.Text] = text
        
        var partnerChatData = [String: String]()
        partnerChatData["lastUpdate"] = now
        partnerChatData["lastMessage"] = text
        partnerChatData["partnerNickname"] = currentUserNickname
        partnerChatData[Constants.MessageFields.ThumbnailURL] = currentUserThumbnailURL

        // Push data to Firebase Database
        
        ref.child("user-messages").child(currentUserUID!).child(partnerUID).setValue(myChatData)
        ref.child("user-messages").child(partnerUID).child(currentUserUID!).setValue(partnerChatData)
        
        ref.child("user-messages").child(currentUserUID!).child(partnerUID).child("messages").childByAutoId().setValue(myData)
        ref.child("user-messages").child(partnerUID).child(currentUserUID!).child("messages").childByAutoId().setValue(partnerData)
        
    
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        myTableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        
        let set = IndexSet(integer: sectionIndex)
        
        switch (type) {
        case .insert:
            myTableView.insertSections(set, with: .fade)
        case .delete:
            myTableView.deleteSections(set, with: .fade)
        default:
            // irrelevant in our case
            break
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch(type) {
        case .insert:
            myTableView.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            myTableView.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            myTableView.reloadRows(at: [indexPath!], with: .fade)
        case .move:
            myTableView.deleteRows(at: [indexPath!], with: .fade)
            myTableView.insertRows(at: [newIndexPath!], with: .fade)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        myTableView.endUpdates()
    }

}

extension MessageViewController {
    
    func executeSearch() {
        do {
            try fetchedResultsController?.performFetch()
        } catch let e as NSError {
            print("Error while trying to perform a search: \n\(e)\n\(fetchedResultsController)")
        }
    }
}
