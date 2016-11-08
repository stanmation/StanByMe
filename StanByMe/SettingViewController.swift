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

class SettingViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var storageRef: FIRStorageReference!
    fileprivate var _refHandle: FIRDatabaseHandle!
    var ref: FIRDatabaseReference!
    var currentUserData = FIRDataSnapshot()
    var oldPhotoRef = ""
    let currentUserUID = FIRAuth.auth()?.currentUser?.uid
    
    @IBOutlet weak var profilePic: UIImageView!


    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureDatabase()
        configureStorage()

    }
    
    func configureDatabase() {
        ref = FIRDatabase.database().reference()
        
        // Listen for new messages in the Firebase database
        _refHandle = self.ref.child("users").child(currentUserUID!).observe(.childAdded, with: { [weak self] (snapshot) -> Void in
            guard let strongSelf = self else { return }
            strongSelf.currentUserData = snapshot
        })
    }
    
    func configureStorage() {
        storageRef = FIRStorage.storage().reference(forURL: "gs://stanbyme-2e590.appspot.com")
    }
    

    @IBAction func addPhotoButtonPressed(_ sender: AnyObject) {
        let picker = UIImagePickerController()
        picker.delegate = self
        if (UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera)) {
            picker.sourceType = UIImagePickerControllerSourceType.camera
        } else {
            picker.sourceType = UIImagePickerControllerSourceType.photoLibrary
        }
        present(picker, animated: true, completion:nil)

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

}
