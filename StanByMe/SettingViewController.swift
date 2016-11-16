//
//  SettingViewController.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 8/11/2016.
//  Copyright © 2016 Stanley Darmawan. All rights reserved.
//

import UIKit
import Firebase
import Photos

class SettingViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIAlertViewDelegate {
    
    var storageRef: FIRStorageReference!
    fileprivate var _refHandle: FIRDatabaseHandle!
    var ref: FIRDatabaseReference!
    var currentUserData = FIRDataSnapshot()
    var oldPhotoRef = ""
    let currentUserUID = FIRAuth.auth()?.currentUser?.uid
    
    @IBOutlet weak var profilePic: UIImageView!
    @IBOutlet weak var nicknameField: UITextField!
    @IBOutlet weak var aboutMeField: UITextField!
    @IBOutlet weak var lookingForField: UITextField!


    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureDatabase()
        configureStorage()

    }
    
    func configureDatabase() {
        ref = FIRDatabase.database().reference()
        
        // Listen for new messages in the Firebase database
        _refHandle = self.ref.child("users").child(currentUserUID!).observe(.value, with: { [weak self] (snapshot) -> Void in
            guard let strongSelf = self else { return }
            strongSelf.currentUserData = snapshot
            strongSelf.prefillData()
        })
    }
    
    func configureStorage() {
        storageRef = FIRStorage.storage().reference(forURL: "gs://stanbyme-2e590.appspot.com")
    }
    
    func prefillData() {
        nicknameField.text = (currentUserData.childSnapshot(forPath: Constants.Users.Nickname).value as? String) ?? ""
        aboutMeField.text = (currentUserData.childSnapshot(forPath: Constants.Users.AboutMe).value as? String) ?? ""
        lookingForField.text = (currentUserData.childSnapshot(forPath: Constants.Users.LookingFor).value as? String) ?? ""
        if let imageURL = (currentUserData.childSnapshot(forPath: Constants.Users.ImageURL).value as? String) {
            if imageURL.hasPrefix("gs://") {
                FIRStorage.storage().reference(forURL: imageURL).data(withMaxSize: INT64_MAX){ (data, error) in
                    if let error = error {
                        print("Error downloading: \(error)")
                        return
                    }
                    self.profilePic.image = UIImage.init(data: data!)
                }
            } else if let URL = URL(string: imageURL), let data = try? Data(contentsOf: URL) {
                self.profilePic.image = UIImage.init(data: data)
            }
        } else {
            print("imageURL not available")
            self.profilePic.image = UIImage(named: "NoImage")
        }
    }
    
    @IBAction func profilePicTapped(_ sender: AnyObject) {
        displayAlert(alertType: "profilePic")

    }

    func addPhoto() {
        let picker = UIImagePickerController()
        picker.delegate = self
        if (UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera)) {
            picker.sourceType = UIImagePickerControllerSourceType.camera
        } else {
            picker.sourceType = UIImagePickerControllerSourceType.photoLibrary
        }
        present(picker, animated: true, completion:nil)

    }
    
    @IBAction func saveButtonPressed(_ sender: AnyObject) {
        let path = ref.child("users").child(currentUserUID!)
        path.child(Constants.Users.Nickname).setValue(nicknameField.text)
        path.child(Constants.Users.AboutMe).setValue(aboutMeField.text)
        path.child(Constants.Users.LookingFor).setValue(lookingForField.text)
    }
    
    
    @IBAction func LogOutButtonPressed(_ sender: AnyObject) {
        let firebaseAuth = FIRAuth.auth()
        do {
            try firebaseAuth?.signOut()
            AppState.sharedInstance.signedIn = false
            dismiss(animated: true, completion: nil)
        } catch let signOutError as NSError {
            print ("Error signing out: \(signOutError.localizedDescription)")
        }
    }
    
    func setImage(withData data: String) {
        
        // Push data to Firebase Database
        self.ref.child("users").child(currentUserUID!).child(Constants.Users.ImageURL).setValue(data)
    }
    
    
    // MARK: delegate methods
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true, completion:nil)
        
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            profilePic.contentMode = .scaleAspectFit
            profilePic.image = pickedImage
        }
        
        
        // if it's a photo from the library, not an image from the camera
        if #available(iOS 8.0, *), let referenceURL = info[UIImagePickerControllerReferenceURL] {
            let assets = PHAsset.fetchAssets(withALAssetURLs: [referenceURL as! URL], options: nil)
            let asset = assets.firstObject
            asset?.requestContentEditingInput(with: nil, completionHandler: { [weak self] (contentEditingInput, info) in
                guard let strongSelf = self else { return }
                let imageFile = contentEditingInput?.fullSizeImageURL
                let filePath = "\(strongSelf.currentUserUID!)/Profile/\((referenceURL as AnyObject).lastPathComponent!)"

                strongSelf.oldPhotoRef = filePath
                strongSelf.storageRef.child(filePath)
                    .putFile(imageFile!, metadata: nil) { (metadata, error) in
                        if let error = error {
                            let nsError = error as NSError
                            print("Error uploading: \(nsError.localizedDescription)")
                            return
                        }
                        strongSelf.setImage(withData: strongSelf.storageRef.child((metadata?.path)!).description)
                    }
                })
        } else {
            guard let image = info[UIImagePickerControllerOriginalImage] as! UIImage? else { return }
            let imageData = UIImageJPEGRepresentation(image, 0.8)
            let imagePath = "\(currentUserUID!)/\(Int(Date.timeIntervalSinceReferenceDate * 1000)).jpg"
            let metadata = FIRStorageMetadata()
            metadata.contentType = "image/jpeg"
            self.storageRef.child(imagePath)
                .put(imageData!, metadata: metadata) { [weak self] (metadata, error) in
                    if let error = error {
                        print("Error uploading: \(error)")
                        return
                    }
                guard let strongSelf = self else {return}
                strongSelf.setImage(withData: strongSelf.storageRef.child((metadata?.path)!).description)
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion:nil)
    }
    
    func displayAlert(alertType: String) {
        let alert = UIAlertController(title: "", message: "", preferredStyle: .alert)
        if alertType == "profilePic" {
            alert.addAction(UIAlertAction(title: "Select from camera roll", style: .default, handler: { (handler) in
                self.addPhoto()
            }))
            alert.addAction(UIAlertAction(title: "Delete", style: .default, handler: { (handler) in
                self.profilePic.image = UIImage(named: "NoImage")
                self.ref.child("users").child(self.currentUserUID!).child(Constants.Users.ImageURL).setValue("")
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        }
        present(alert, animated: true, completion: nil)

    }

}
