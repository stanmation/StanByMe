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
import ReachabilitySwift


class MessageViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIAlertViewDelegate {
    
    var fr: NSFetchRequest<Message>!
    var fetchedResultsController: NSFetchedResultsController<Message>?

    let stack = (UIApplication.shared.delegate as! AppDelegate).stack

    var chat : Chat?
	
	let reachability = Reachability()

    @IBOutlet weak var newMessageTextField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
	@IBOutlet weak var cameraButton: UIButton!
	
    
    var ref: FIRDatabaseReference!
//    var messages = [FIRDataSnapshot]()
    var currentUserData = FIRDataSnapshot()
    var partnerUserData = FIRDataSnapshot()
    
    let cellIdentifier = "tableViewCell"
	let cellIdentifier2 = "imageTableViewCell"


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
		
		// set the camera button
		let origImage = UIImage(named: "Icon-Camera");
		let tintedImage = origImage?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
		cameraButton.setImage(tintedImage, for: .normal)
		
        newMessageTextField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        
        // configure tableView
        myTableView.register(MessageTableViewCell.self, forCellReuseIdentifier: cellIdentifier)
		myTableView.register(ImageMessageTableViewCell.self, forCellReuseIdentifier: cellIdentifier2)

        myTableView.estimatedRowHeight = 44
        
        // get the userID
        currentUserID = FIRAuth.auth()?.currentUser?.uid
        
        executeSearch()
        
        configureCoreData()
        
        configureDatabase()
        configureStorage()
        
        // add gesture recognizer when view is tapped, in this case it will hide the keyboard
        let tap = UITapGestureRecognizer(target: self, action: #selector(viewIsTapped))
        view.addGestureRecognizer(tap)
    }
    
    deinit {
        if _userMessageRefHandle != nil {
            self.ref.child("user-messages").removeObserver(withHandle: _userMessageRefHandle)
        }
        if _currentUserRefHandle != nil {
            self.ref.child("users").removeObserver(withHandle: _currentUserRefHandle)
        }
        if _partnerUserRefHandle != nil {
            self.ref.child("users").removeObserver(withHandle: _partnerUserRefHandle)
        }
    }
    
    // method called when view is tapped
    func viewIsTapped() {
        newMessageTextField.resignFirstResponder()
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        disableSendButton()
        subscribeToKeyboardNotifications()
		
		// setup reachability
		NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: ReachabilityChangedNotification, object: nil)
		do {
			try reachability?.startNotifier()
		} catch {
			print("Unable to start notifier")
		}
		
    }
	
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        unsubscribeToKeyboardNotifications()
		
		// remove reachability
		reachability?.stopNotifier()
		NotificationCenter.default.removeObserver(self,
		                                          name: ReachabilityChangedNotification,
		                                          object: reachability)
    }
	
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if (fetchedResultsController?.fetchedObjects?.count)! > 0 {
            scrollToTheBottom()
        }
    }
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		
		if segue.destination is PictureViewController {
			
			let controller = segue.destination as! PictureViewController
			controller.thumbnailURL = sender as! String

		}
	}
	
	func reachabilityChanged(note: NSNotification) {
		
		let reachability = note.object as! Reachability
		
		if reachability.isReachable {
			self.cameraButton.tintColor = UIColor.purple
			self.cameraButton.isEnabled = true

			if reachability.isReachableViaWiFi {
				print("Reachable via WiFi")
			} else {
				print("Reachable via Cellular")
			}
		} else {
			print("Network not reachable")
			DispatchQueue.main.async {
				self.cameraButton.tintColor = UIColor.gray
				self.cameraButton.isEnabled = false
			}
		}
	}
	
    func configureCoreData() {
		
        // Create a fetchrequest
        fr = NSFetchRequest<Message>(entityName: "Message")
        fr.sortDescriptors = [NSSortDescriptor(key: "dateUpdated", ascending: true)]
        
        if chat != nil {
            let predicate = NSPredicate(format: "chat == %@", chat!)
            fr.predicate = predicate
        } else {
            let pred = NSPredicate(format: "chat == %@", 0)
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
    }
    
    func configureDatabase() {
        
        ref = FIRDatabase.database().reference()
        
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
//            strongSelf.messages.append(snapshot)
            
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
            
            if strongSelf.chat == nil {
                
                // setup the date
                let dateformatter = DateFormatter()
                dateformatter.dateFormat = "MM/dd/yy h:mm a Z"
                let now = dateformatter.string(from: Date())
                
                // create chat
                let chat = Chat(currentUserId: strongSelf.currentUserID, partnerId: strongSelf.partnerUID, partnerNickname: nickname, lastUpdate: now, read: "read", lastMessage: message["text"]!, thumbnailData: nil, context: strongSelf.stack.context)
                strongSelf.chat = chat
            }
            
            let predicate = NSPredicate(format: "id == %@ && chat == %@", snapshot.key, strongSelf.chat ?? 0)
            strongSelf.fr.predicate = predicate
            
            guard let messagesFound = try? strongSelf.stack.context.fetch(strongSelf.fr) else {
                print("An error occurred while retrieving messages")
                return
            }
            
            if messagesFound == [] {
                let newMessage = Message(messageId: snapshot.key, status: message["status"]!, text: message["text"], thumbnailURL: message["imageMessage"], thumbnailData: nil, context: strongSelf.stack.context)

                newMessage.chat = strongSelf.chat
				
				if let thumbnailURL = message["imageMessage"], thumbnailURL.hasPrefix("gs://") {
					FIRStorage.storage().reference(forURL: thumbnailURL).data(withMaxSize: INT64_MAX){ (data, error) in
						if let error = error {
							print("Error downloading: \(error)")
							return
						}
						newMessage.thumbnailData = data!
					}
				}
            }
			
		})

    }
	
    func disableSendButton() {
        sendButton.isEnabled = false
        sendButton.isUserInteractionEnabled = false
        sendButton.backgroundColor = UIColor.gray
    }
	
    func scrollToTheBottom() {
        // scroll to the bottom of tableView
        let indexPath = IndexPath(row: (fetchedResultsController?.fetchedObjects?.count)! - 1, section: 0)
        myTableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
    
    
    func configureStorage() {
        storageRef = FIRStorage.storage().reference(forURL: "gs://stanbyme-2e590.appspot.com")
    }
    
    @IBAction func didSendMessage(_ sender: UIButton) {
        textFieldShouldReturn(newMessageTextField)
    }
	
	
	@IBAction func cameraButtonTapped(_ sender: Any) {
		displayAlert(alertType: "pickPhoto")
	}
	
    // MARK: Keyboard manipulation
    
    func keyboardWillShow(notification:NSNotification) {
        
        if (newMessageTextField.isFirstResponder){
            self.view.frame.origin.y = getKeyboardHeight(notification: notification) * (-1)
            self.navigationController!.navigationBar.frame.origin.y = getKeyboardHeight(notification: notification) * (-1)
        }
    }
    
    func keyboardWillHide(notification:NSNotification) {
        self.view.frame.origin.y = 0
        self.navigationController!.navigationBar.frame.origin.y = 0
    }
    
    func getKeyboardHeight(notification:NSNotification) -> CGFloat {
        let userInfo = notification.userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue // of CGRect
        return keyboardSize.cgRectValue.height
    }
    
    func subscribeToKeyboardNotifications(){
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    func unsubscribeToKeyboardNotifications(){
        NotificationCenter.default.removeObserver(self, name:  NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name:  NSNotification.Name.UIKeyboardWillHide, object:nil)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController?.sections?.count ?? 0
    }
    
    
    func textChanged() {
        if newMessageTextField.text != "" {
            sendButton.isEnabled = true
            sendButton.isUserInteractionEnabled = true
            sendButton.backgroundColor = UIColor.purple
        } else {
            disableSendButton()
        }
    }
	
	func addPhoto(source: UIImagePickerControllerSourceType) {
		let picker = UIImagePickerController()
		picker.delegate = self
		picker.sourceType = source
		
		present(picker, animated: true, completion:nil)
	}
	
	func picTapped(sender: UITapGestureRecognizer) {
		let location = sender.location(in: myTableView)
		let indexPath = myTableView.indexPathForRow(at: location)
		let cell = myTableView.cellForRow(at: indexPath!) as! ImageMessageTableViewCell
		
		performSegue(withIdentifier: "toPictureVC", sender: cell.thumbnailURL)

	}
	
	func displayAlert(alertType: String) {
		let alert = UIAlertController(title: "", message: "", preferredStyle: .alert)
		if alertType == "pickPhoto" {
			alert.title = "Do you want to send a picture?"
			alert.addAction(UIAlertAction(title: "Select a picture from camera roll", style: .default, handler: { (handler) in
				self.addPhoto(source: .photoLibrary)
			}))
			
			if UIImagePickerController.isSourceTypeAvailable(.camera) {
				alert.addAction(UIAlertAction(title: "Take a picture", style: .default, handler: { (handler) in
					self.addPhoto(source: .camera)
				}))
			}
			
			alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
		}
		present(alert, animated: true, completion: nil)
	}
	
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController?.sections![section]
        return sectionInfo!.numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Coredata
        let message = fetchedResultsController?.object(at: indexPath)
		
		//setup ImageMessage and Message cells
		if let imageURL = message?.thumbnailURL {
			let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier2, for: indexPath) as! ImageMessageTableViewCell
			if let thumbnailData = message?.thumbnailData {
				let singleTap = UITapGestureRecognizer(target: self, action: #selector(picTapped(sender:)))
				singleTap.numberOfTapsRequired = 1
				cell.addGestureRecognizer(singleTap)
				cell.thumbnailURL = (message?.thumbnailURL)!
				cell.messageImageView.image = UIImage(data: thumbnailData)
			}
			if message?.status == "sender" {
				cell.incoming(incoming: false)
			} else {
				cell.incoming(incoming: true)
			}
			return cell
		} else {
			let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! MessageTableViewCell
			let text = message?.text
			cell.messageLabel.text = text
			if message?.status == "sender" {
				cell.incoming(incoming: false)
			} else {
				cell.incoming(incoming: true)
			}
			return cell
		}
		

    }
	
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    

    // MARK: UITextViewDelegate protocol methods
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		
        sendMessage(text: textField.text!)
        textField.text = ""
        disableSendButton()
        newMessageTextField.resignFirstResponder()
        
        return true
    }
    
    
    func sendMessage(text: String) {
        
        // setup the date
        let dateformatter = DateFormatter()
        dateformatter.dateFormat = "MM/dd/yy h:mm a Z"
        let now = dateformatter.string(from: Date())
        
        // set up current user data
        let currentUserDict = self.currentUserData.value as! Dictionary<String, String>
        let currentUserUID = currentUserDict["uid"] as String!
        let currentUserNickname = currentUserDict["nickname"] as String!

        // set partner data in user-messages
        let partnerUserDict = partnerUserData.value as! [String: String]
        let partnerNickname = partnerUserDict["nickname"]!
		let partnerPushNotifToken = partnerUserDict["pushNotifToken"]
        
        var myData = [String: String]()
        myData["status"] = "sender"
        myData["text"] = text
        
        let currentUserThumbnailURL = currentUserDict["thumbnailURL"]!
        let partnerThumbnailURL = partnerUserDict["thumbnailURL"]!

        var myChatData = [String: String]()
        myChatData["lastUpdate"] = now
        myChatData["lastMessage"] = text
        myChatData["partnerNickname"] = partnerNickname
        myChatData["read"] = "read"
        myChatData["thumbnailURL"] = partnerThumbnailURL

        // set up partner data
        var partnerData = [String: String]()
        partnerData["status"] = "receiver"
        partnerData["text"] = text
        
        var partnerChatData = [String: String]()
        partnerChatData["lastUpdate"] = now
        partnerChatData["lastMessage"] = text
        partnerChatData["partnerNickname"] = currentUserNickname
        partnerChatData["read"] = "unread"
        partnerChatData["thumbnailURL"] = currentUserThumbnailURL
        
        // Push data to Firebase Database
        
        ref.child("user-messages").child(currentUserUID!).child(partnerUID).child("info").setValue(myChatData)
        ref.child("user-messages").child(partnerUID).child(currentUserUID!).child("info").setValue(partnerChatData)
        
        ref.child("user-messages").child(currentUserUID!).child(partnerUID).child("lastUpdate").setValue(now)
        ref.child("user-messages").child(partnerUID).child(currentUserUID!).child("lastUpdate").setValue(now)
        
        ref.child("user-messages").child(currentUserUID!).child(partnerUID).child("messages").childByAutoId().setValue(myData)
        ref.child("user-messages").child(partnerUID).child(currentUserUID!).child("messages").childByAutoId().setValue(partnerData)
        
        // create chat
        if chat == nil {
            let chat = Chat(currentUserId: currentUserUID!, partnerId: partnerUID, partnerNickname: partnerNickname, lastUpdate: now, read: "read", lastMessage: text, thumbnailData: nil, context: stack.context)
            self.chat = chat
        }
		
		if partnerPushNotifToken != nil {
			// send push notification
			let url: URL = URL(string: "http://localhost/stanbyme/messagepush.php")!
			let request: NSMutableURLRequest = NSMutableURLRequest(url: url)
			request.httpMethod = "POST"
			let bodyData = "token=\(partnerPushNotifToken!)"
			request.httpBody = bodyData.data(using: String.Encoding.utf8)
			URLSession.shared.dataTask(with: request as URLRequest) { (data, response, error) in
				print("response: \(response!)")
				print("data: \(	String(data: data!, encoding: String.Encoding.utf8))")
				print("error: \(error)")
				
				}.resume()
		}

		
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
        scrollToTheBottom()
    }
	
	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
		
		picker.dismiss(animated: true, completion:nil)
		
		var thumbnail: UIImage!

		if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
			
			let squareImage = cropImageToSquare(image: pickedImage)
			thumbnail = squareImage.resizeWith(width: 100)
			
		}
		
		guard let image = info[UIImagePickerControllerOriginalImage] as! UIImage? else { return }

		let imageName = Date.timeIntervalSinceReferenceDate * 1000
		let imageData = UIImageJPEGRepresentation(image, 0.8)
		let thumbnailData = UIImageJPEGRepresentation(thumbnail!, 0.6)
		let imagePath = "\(currentUserID!)/Messages/\(Int(imageName))-fullsize.jpg"
		let thumbnailPath = "\(currentUserID!)/Messages/\(Int(imageName)).jpg"

		// load into firebase
		let metadata = FIRStorageMetadata()
		metadata.contentType = "image/jpeg"
		self.storageRef.child(imagePath)
			.put(imageData!, metadata: metadata) { [weak self] (metadata, error) in
				guard let strongSelf = self else {return}
				if let error = error {
					print("Error uploading: \(error)")
//					strongSelf.imageUploadProgressIndicator.stopAnimating()
					strongSelf.displayErrorAlert(alertType: .networkError, message: "")
					return
				}
//				strongSelf.imageUploadProgressIndicator.stopAnimating()

		}
		
		self.storageRef.child(thumbnailPath)
			.put(thumbnailData!, metadata: metadata) { [weak self] (metadata, error) in
				guard let strongSelf = self else {return}
				if let error = error {
					print("Error uploading: \(error)")
					//					strongSelf.imageUploadProgressIndicator.stopAnimating()
					strongSelf.displayErrorAlert(alertType: .networkError, message: "")
					return
				}
				//				strongSelf.imageUploadProgressIndicator.stopAnimating()
				//				strongSelf.setImageURL(withData: strongSelf.storageRef.child((metadata?.path)!).description)
				
				var myData = [String: String]()
				myData["imageMessage"] = strongSelf.storageRef.child((metadata?.path)!).description
				myData["status"] = "sender"
				
				var partnerData = [String: String]()
				partnerData["imageMessage"] = strongSelf.storageRef.child((metadata?.path)!).description
				partnerData["status"] = "receiver"
				
				strongSelf.ref.child("user-messages").child(strongSelf.currentUserID!).child(strongSelf.partnerUID).child("messages").childByAutoId().setValue(myData)
				strongSelf.ref.child("user-messages").child(strongSelf.partnerUID).child(strongSelf.currentUserID!).child("messages").childByAutoId().setValue(partnerData)
		}
		
	}
	
	func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
		picker.dismiss(animated: true, completion:nil)
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
