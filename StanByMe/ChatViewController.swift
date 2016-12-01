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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create a fetchrequest
        let fr = NSFetchRequest<NSFetchRequestResult>(entityName: "Chat")
        fr.sortDescriptors = [NSSortDescriptor(key: "lastUpdate", ascending: false)]
        
        // Create the FetchedResultsController
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: stack.context, sectionNameKeyPath: nil, cacheName: nil)
        
        configureDatabase()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is MessageViewController {
            let controller = segue.destination as! MessageViewController
            controller.partnerUID = partnerUID
            
            let indexPath = tableView.indexPathForSelectedRow!
            let chat = fetchedResultsController?.object(at: indexPath) as? Chat
            
            controller.partnerUID = chat?.partnerId
            controller.chat = chat
            
        }
    }
    
    func configureDatabase() {
        ref = FIRDatabase.database().reference()
        
        // get the userID
        let currentUserID = FIRAuth.auth()?.currentUser?.uid

        _refHandle = self.ref.child("user-messages").child(currentUserID!).queryOrdered(byChild: "lastUpdate").observe(.value, with: { [weak self] (snapshot) -> Void in
            guard let strongSelf = self else { return }
            
            var tempUserMessages = [FIRDataSnapshot]()
            
            print("snapshot: \(snapshot)")
            
            if let snapshots = snapshot.children.allObjects as? [FIRDataSnapshot] {
                
                let fr = NSFetchRequest<Chat>(entityName: "Chat")
                for snap in snapshots {

                    let partnerNickname = snap.childSnapshot(forPath: "partnerNickname").value as! String
                    let partnerId = snap.key
                    strongSelf.partnerUID = partnerId
                    let lastUpdate = snap.childSnapshot(forPath: "lastUpdate").value as! String
                    let read = snap.childSnapshot(forPath: "read").value as! String
                    let lastMessage = snap.childSnapshot(forPath: "lastMessage").value as! String
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
                            chat = Chat(currentUserId: currentUserID!, partnerId: partnerId, partnerNickname: partnerNickname, lastUpdate: lastUpdate, read: read, lastMessage: lastMessage, thumbnailData: nil, context: workerContext)
                        }
                        
                        if let thumbnailURL = snap.childSnapshot(forPath: Constants.MessageFields.ThumbnailURL).value as? String, thumbnailURL.hasPrefix("gs://") {
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

    // this will download the image from Firebase storage
    func getImage( imagePath:String, completionHandler: @escaping (_ imageData: Data?, _ errorString: String?) -> Void){
        let session = URLSession.shared
        let imgURL = URL(string: imagePath)
        let request: URLRequest = URLRequest(url: imgURL!)
        
        let task = session.dataTask(with: request) {data, response, downloadError in
            
            if let error = downloadError {
                completionHandler(nil, "Could not download image \(imagePath)")
            } else {
                
                completionHandler(data, nil)
            }
        }
        
        task.resume()
    }
    
    //MARK: Delegate Methods
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        
        // Find the right chat for this indexpath
        let chat = fetchedResultsController!.object(at: indexPath) as! Chat
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "tableViewCell") as! ChatTableViewCell!
        
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


}
