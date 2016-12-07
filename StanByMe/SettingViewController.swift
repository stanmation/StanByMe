//
//  SettingViewController.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 8/11/2016.
//  Copyright © 2016 Stanley Darmawan. All rights reserved.
//

import UIKit
import Firebase
import CoreData

class SettingViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIAlertViewDelegate {
    
    var storageRef: FIRStorageReference!
    fileprivate var _refHandle: FIRDatabaseHandle!
    var ref: FIRDatabaseReference!
    var currentUserData = FIRDataSnapshot()
    var oldPhotoRef = ""
    let currentUserUID = FIRAuth.auth()?.currentUser?.uid
    var settings: Settings?
    
    let stack = (UIApplication.shared.delegate as! AppDelegate).stack

    
    @IBOutlet weak var profilePic: UIImageView!
    @IBOutlet weak var nicknameField: UITextField!
    @IBOutlet weak var aboutMeField: UITextField!
    @IBOutlet weak var lookingForField: UITextField!


    override func viewDidLoad() {
        super.viewDidLoad()
    
        configureCoreData()
        configureDatabase()
        configureStorage()

    }
    
    deinit {
        if _refHandle != nil {
            self.ref.child("users").removeObserver(withHandle: _refHandle)
        }
    }
    
    func configureCoreData() {
        let fr = NSFetchRequest<NSFetchRequestResult>(entityName: "Settings")
        fr.sortDescriptors = []
        
        // Create the FetchedResultsController
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: stack.context, sectionNameKeyPath: nil, cacheName: nil)
        
        do {
            try fetchedResultsController.performFetch()
        } catch let e as NSError {
            print("Error while trying to perform a search: \n\(e)\n\(fetchedResultsController)")
        }
        
        guard let settingsFound = try? stack.context.fetch(fr) as! [Settings] else {
            print("An error occurred while retrieving settings")
            return
        }
        
        if settingsFound != [] {
            settings = settingsFound[0]
        }
        
        if let settings = self.settings {
            nicknameField.text = settings.nickname
            aboutMeField.text = settings.aboutMe
            lookingForField.text = settings.lookingFor
            profilePic.image = UIImage(data: settings.profilePic!)
        } else {
            self.settings = Settings(profilePic: nil, aboutYou: "", lookingFor: "", nickname: "", context: stack.context)
        }
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
    

    func prefillData() {
        nicknameField.text = (currentUserData.childSnapshot(forPath: Constants.Users.Nickname).value as? String) ?? ""
        aboutMeField.text = (currentUserData.childSnapshot(forPath: Constants.Users.AboutMe).value as? String) ?? ""
        lookingForField.text = (currentUserData.childSnapshot(forPath: Constants.Users.LookingFor).value as? String) ?? ""
        if let thumbnailURL = currentUserData.childSnapshot(forPath: Constants.Users.ThumbnailURL).value as? String, thumbnailURL.hasPrefix("gs://") {
            FIRStorage.storage().reference(forURL: thumbnailURL).data(withMaxSize: INT64_MAX){ (data, error) in
                if let error = error {
                    print("Error downloading: \(error)")
                    return
                }
                self.profilePic.image = UIImage.init(data: data!)
                self.settings?.profilePic = data

            }
        } else {
            print("imageURL not available")
            self.profilePic.image = UIImage(named: "NoImage")
        }
        
        self.settings?.nickname = nicknameField.text
        self.settings?.aboutMe = aboutMeField.text
        self.settings?.lookingFor = lookingForField.text

        
    }
    
    func configureStorage() {
        storageRef = FIRStorage.storage().reference(forURL: "gs://stanbyme-2e590.appspot.com")
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
        path.child(Constants.Users.Nickname).setValue(nicknameField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
        path.child(Constants.Users.AboutMe).setValue(aboutMeField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
        path.child(Constants.Users.LookingFor).setValue(lookingForField.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
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
    
    func setImageURL(withData data: String) {
        // Push data to Firebase Database
        self.ref.child("users").child(currentUserUID!).child(Constants.Users.ImageURL).setValue(data)
    }
    
    func setThumbnailURL(withData data: String) {
        // Push data to Firebase Database
        self.ref.child("users").child(currentUserUID!).child(Constants.Users.ThumbnailURL).setValue(data)
    }
    

    // this function will generate thumbnail of profile pic
    func cropImageToSquare(image: UIImage) -> UIImage {

        let contextImage: UIImage = UIImage(cgImage: image.cgImage!)
        
        let contextSize: CGSize = contextImage.size
        
        var posX: CGFloat = 0.0
        var posY: CGFloat = 0.0
        var cgwidth: CGFloat = 0.0
        var cgheight: CGFloat = 0.0
        
        // see what size is longer and create the center off of that
        if contextSize.width > contextSize.height {
            posX = ((contextSize.width - contextSize.height) / 2)
            posY = 0
            cgwidth = contextSize.height
            cgheight = contextSize.height
        } else {
            posX = 0
            posY = ((contextSize.height - contextSize.width) / 2)
            cgwidth = contextSize.width
            cgheight = contextSize.width
        }
        
        let rect: CGRect = CGRect(x: posX, y: posY, width: cgwidth, height: cgheight)
        
        // create bitmap image from context using the rect
        let imageRef: CGImage = (contextImage.cgImage?.cropping(to: rect))!
        let resultedImage: UIImage = UIImage(cgImage: imageRef, scale: image.scale, orientation: image.imageOrientation)
        
        return resultedImage
    }
    
    // this function will crop the landscape profile pic
    func cropLandscapeImage(image: UIImage) -> UIImage {
        
        let contextImage: UIImage = UIImage(cgImage: image.cgImage!)
        let contextSize: CGSize = contextImage.size
        
        var posX: CGFloat = 0.0
        var posY: CGFloat = 0.0
        var cgwidth: CGFloat = 0.0
        var cgheight: CGFloat = 0.0
        
        posX = ((contextSize.width - (contextSize.height * 1.7778)) / 2)
        posY = 0
        cgwidth = contextSize.width / 1.7778
        cgheight = contextSize.height
        
        let rect: CGRect = CGRect(x: posX, y: posY, width: cgwidth, height: cgheight)
        
        // create bitmap image from context using the rect
        let imageRef: CGImage = (contextImage.cgImage?.cropping(to: rect))!
        let resultedImage: UIImage = UIImage(cgImage: imageRef, scale: image.scale, orientation: image.imageOrientation)
        
        return resultedImage
    }
    
    
    // MARK: delegate methods
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true, completion:nil)
        var portraitImage: UIImage!
        var thumbnail: UIImage!

        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            if pickedImage.size.width > pickedImage.size.height {
                portraitImage = cropLandscapeImage(image: pickedImage)
            } else {
                portraitImage = pickedImage
            }
            
            let squareImage = cropImageToSquare(image: pickedImage)
            thumbnail = squareImage.resizeWith(width: 100)

            profilePic.contentMode = .scaleAspectFill
            profilePic.image = thumbnail
            
        }
        
        // if it's a photo from the library, not an image from the camera
        if #available(iOS 8.0, *), let referenceURL = info[UIImagePickerControllerReferenceURL] {
//            let assets = PHAsset.fetchAssets(withALAssetURLs: [referenceURL as! URL], options: nil)
//            let asset = assets.firstObject
//            asset?.requestContentEditingInput(with: nil, completionHandler: { [weak self] (contentEditingInput, info) in
//                guard let strongSelf = self else { return }
//                let imageFile = contentEditingInput?.fullSizeImageURL
//
//                let filePath = "\(strongSelf.currentUserUID!)/Profile/\((referenceURL as AnyObject).lastPathComponent!)"
//
//                strongSelf.oldPhotoRef = filePath
//                strongSelf.storageRef.child(filePath)
//                    .putFile(imageFile!, metadata: nil) { (metadata, error) in
//                        if let error = error {
//                            let nsError = error as NSError
//                            print("Error uploading: \(nsError.localizedDescription)")
//                            return
//                        }
//                        strongSelf.setImage(withData: strongSelf.storageRef.child((metadata?.path)!).description)
//                    }
//                })
            
            let imageData = UIImageJPEGRepresentation(portraitImage!, 0.8)
            let thumbnailData = UIImageJPEGRepresentation(thumbnail!, 0.6)
            let imagePath = "\(currentUserUID!)/Profile/asset.jpg"
            let thumbnailPath = "\(currentUserUID!)/Thumbnail/asset.jpg"

            let metadata = FIRStorageMetadata()
            metadata.contentType = "image/jpeg"
            self.storageRef.child(imagePath)
                .put(imageData!, metadata: metadata) { [weak self] (metadata, error) in
                    if let error = error {
                        print("Error uploading: \(error)")
                        return
                    }
                    guard let strongSelf = self else {return}
                    strongSelf.setImageURL(withData: strongSelf.storageRef.child((metadata?.path)!).description)
            }
            
            self.storageRef.child(thumbnailPath)
                .put(thumbnailData!, metadata: metadata) { [weak self] (metadata, error) in
                    if let error = error {
                        print("Error uploading: \(error)")
                        return
                    }
                    guard let strongSelf = self else {return}
                    strongSelf.setThumbnailURL(withData: strongSelf.storageRef.child((metadata?.path)!).description)
            }
            
            
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
                strongSelf.setImageURL(withData: strongSelf.storageRef.child((metadata?.path)!).description)
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion:nil)
    }
    
    func displayAlert(alertType: String) {
        let alert = UIAlertController(title: "", message: "", preferredStyle: .alert)
        if alertType == "profilePic" {
            alert.title = "Choose your profile picture"
            alert.addAction(UIAlertAction(title: "Select a picture from camera roll", style: .default, handler: { (handler) in
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


extension UIImage {
    func resizeWith(width: CGFloat) -> UIImage? {
        let imageView = UIImageView(frame: CGRect(origin: .zero, size: CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))))
        imageView.contentMode = .scaleAspectFit
        imageView.image = self
        UIGraphicsBeginImageContextWithOptions(imageView.bounds.size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        imageView.layer.render(in: context)
        guard let result = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        UIGraphicsEndImageContext()
        return result
    }
}
