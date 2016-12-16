//
//  ChatViewController.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 19/11/2016.
//  Copyright © 2016 Stanley Darmawan. All rights reserved.
//

import UIKit
import Firebase
import CoreData

class ChatViewController: CoreDataTableViewController {
    
    var ref: FIRDatabaseReference!
    fileprivate var _refHandle: FIRDatabaseHandle!
    var userMessages = [FIRDataSnapshot]()
    var partnerUID: String?
    let stack = (UIApplication.shared.delegate as! AppDelegate).stack
    let currentUserID = FIRAuth.auth()?.currentUser?.uid

    @IBOutlet weak var editButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Create a fetchrequest
        let fr = NSFetchRequest<NSFetchRequestResult>(entityName: "Chat")
        fr.sortDescriptors = [NSSortDescriptor(key: "lastUpdate", ascending: false)]
        let pred = NSPredicate(format: "currentUserId == %@ && partnerId != %@", currentUserID!, currentUserID!)

        fr.predicate = pred
        
        // Create the FetchedResultsController
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: stack.context, sectionNameKeyPath: nil, cacheName: nil)
        configureDatabase()
    }
    
    deinit {
        if _refHandle != nil {
            self.ref.child("user-messages").removeObserver(withHandle: _refHandle)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is MessageViewController {
            let controller = segue.destination as! MessageViewController
            controller.partnerUID = partnerUID
            
            let indexPath = tableView.indexPathForSelectedRow!
            let chat = fetchedResultsController?.object(at: indexPath) as? Chat
            chat?.read = "read"
            
            controller.partnerUID = chat?.partnerId
            controller.chat = chat
            
            ref.child("user-messages").child(currentUserID!).child((chat?.partnerId!)!).child("info").child("read").setValue("read")

            controller.hidesBottomBarWhenPushed = true
            
        }
    }
    
    
    func configureDatabase() {
        ref = FIRDatabase.database().reference()

        _refHandle = self.ref.child("user-messages").child(currentUserID!).queryOrdered(byChild: "lastUpdate").observe(.value, with: { [weak self] (snapshot) -> Void in
            guard let strongSelf = self else { return }
            
            if let snapshots = snapshot.children.allObjects as? [FIRDataSnapshot] {
                
                let fr = NSFetchRequest<Chat>(entityName: "Chat")
                for snap in snapshots {
                    let partnerNickname = snap.childSnapshot(forPath: "info/partnerNickname").value as! String
                    let partnerId = snap.key
                    strongSelf.partnerUID = partnerId
                    let lastUpdate = snap.childSnapshot(forPath: "info/lastUpdate").value as! String
                    let read = snap.childSnapshot(forPath: "info/read").value as! String
                    let lastMessage = snap.childSnapshot(forPath: "info/lastMessage").value as! String
                    let predicate = NSPredicate(format: "partnerId == %@", partnerId)
                    fr.predicate = predicate
                    guard let chatsFound = try? strongSelf.stack.context.fetch(fr) else {
                        print("An error occurred while retrieving chats")
                        return
                    }
                    
                    strongSelf.stack.performBackgroundBatchOperation({ (workerContext) in
                        let chat: Chat?
                        if chatsFound !=  [] {
                            print("chat exists")
                            chat = chatsFound[0]
                            chat?.read = read
                            chat?.lastUpdate = lastUpdate
                            chat?.lastMessage = lastMessage
                        } else {
                            print("chat doesn't exist")
                            chat = Chat(currentUserId: strongSelf.currentUserID!, partnerId: partnerId, partnerNickname: partnerNickname, lastUpdate: lastUpdate, read: read, lastMessage: lastMessage, thumbnailData: nil, context: workerContext)
                        }
                        
                        if let thumbnailURL = snap.childSnapshot(forPath: "info/thumbnailURL").value as? String, thumbnailURL.hasPrefix("gs://") {
                            FIRStorage.storage().reference(forURL: thumbnailURL).data(withMaxSize: INT64_MAX){ (data, error) in
                                if let error = error {
                                    print("Error downloading: \(error)")
                                    return
                                }
                                chat?.thumbnailData = data!
                            }
                        }
                    })
                }
            }
            
            strongSelf.stack.save()
        })
  
    }

    //MARK: Delegate Methods
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Find the right chat for this indexpath
        let chat = fetchedResultsController!.object(at: indexPath) as! Chat
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "tableViewCell") as! ChatTableViewCell!
        
        if chat.read == "unread" {
            cell?.backgroundColor = UIColor.init(colorLiteralRed: 220/255, green: 220/255, blue: 225/255, alpha: 1.0)
        } else {
            cell?.backgroundColor = UIColor.clear
        }
        
        if let thumbnailData = chat.thumbnailData {
            cell?.profileImageView?.image = UIImage(data: thumbnailData)
        } else {
            cell?.profileImageView?.image = UIImage(named: "NoImage")
        }
                
        cell?.nicknameLabel?.text = chat.partnerNickname
        cell?.messageTextField?.text = chat.lastMessage

        return cell!
        
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: Constants.Segues.ToMessageVC, sender: nil)
        tableView.deselectRow(at: indexPath, animated: false)
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if let context = fetchedResultsController?.managedObjectContext, let chat = fetchedResultsController?.object(at: indexPath) as? Chat, editingStyle == .delete {
            
            let fr = NSFetchRequest<Message>(entityName: "Message")
            fr.sortDescriptors = [NSSortDescriptor(key: "dateUpdated", ascending: true)]
            
            let predicate = NSPredicate(format: "chat == %@", chat)
            fr.predicate = predicate
            
            guard let messagesFound = try? context.fetch(fr) else {
                print("An error occurred while retrieving messages")
                return
            }
            
            ref.child("user-messages").child(currentUserID!).child(chat.partnerId!).removeValue()
            ref.child("user-messages").child(chat.partnerId!).child(currentUserID!).removeValue()

            context.delete(chat)
            
            for message in messagesFound {
                context.delete(message)
            }
            

        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 55
    }
    


}
