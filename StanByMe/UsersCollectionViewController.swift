//
//  UsersCollectionViewController.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 8/11/2016.
//  Copyright © 2016 Stanley Darmawan. All rights reserved.
//

import UIKit
import Firebase

class UsersCollectionViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, CLLocationManagerDelegate {
    
    var ref: FIRDatabaseReference!
    var users:[[String: String]]?
    var closestUsers = [String: CLLocation]()
    
    fileprivate var _refHandle: FIRDatabaseHandle!
    
    var storageRef: FIRStorageReference!
    var remoteConfig: FIRRemoteConfig!
    var geoFire: GeoFire?
    
    let locationManager = CLLocationManager()
    var currentUserLocation = CLLocation()
    
    @IBOutlet weak var warningMsgTextView: UITextView!
    @IBOutlet weak var myCollectionView: UICollectionView!
    @IBOutlet weak var flowlayout: UICollectionViewFlowLayout!

    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: UIControlEvents.valueChanged)
        
        return refreshControl
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.startUpdatingLocation()
        
        myCollectionView.addSubview(refreshControl)
        
        let currentUserEmail = FIRAuth.auth()?.currentUser?.email
        navigationItem.title = currentUserEmail
        
        configureStorage()

        ref = FIRDatabase.database().reference()
        users = [[String: String]]()
        
        // configure location manager
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.stopUpdatingLocation()
        
        // setup CollectionView flow layout
        let space: CGFloat = 5.0
        let dimension = (self.view.frame.size.width - (2 * space)) / 3.0
        flowlayout.minimumInteritemSpacing = space
        flowlayout.minimumLineSpacing = space
        flowlayout.itemSize = CGSize(width: dimension, height: dimension)
    }
    

    // this function will be called when refresh the page by dragging
    func handleRefresh(_ refreshControl: UIRefreshControl) {
        // Do some refresh
        locationManager.startUpdatingLocation()
        refreshControl.endRefreshing()
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is UserProfileViewController {
            
            let controller = segue.destination as! UserProfileViewController
            let indexPath = myCollectionView.indexPathsForSelectedItems?[0]
            let user = (users?[(indexPath?.row)!])! as [String: String]
            controller.user = user
            
            // finding the distance of the selected user
            let userLocation = closestUsers[user["uid"]!]
            let distanceInMeter = userLocation!.distance(from: currentUserLocation)
            let distanceInKilometer = distanceInMeter / 1000
            controller.distance = distanceInKilometer
            
            controller.hidesBottomBarWhenPushed = true
        }
    }
    
    func breakingSentenceIntoKeywords(sentence: String) -> [String]{
        let lowercaseSentence = sentence.lowercased()
        let arrayString = lowercaseSentence.components(separatedBy: " ")
        print("arrayString for \(sentence): \(arrayString)")
        return arrayString
    }
    
    func configureDatabase() {
        
        // set your user location
        let currentUserID = FIRAuth.auth()?.currentUser?.uid
        geoFire = GeoFire(firebaseRef: ref.child("locations"))
        geoFire?.setLocation(currentUserLocation, forKey: currentUserID!)
        
        var myLookingForArray = [String]()
        ref.child("users").child(currentUserID!).child("lookingFor").observeSingleEvent(of: .value, with: { [weak self] (snapshot) in
            guard let strongSelf = self else { return }

            let myLookingForSentence = snapshot.value as! String?
            myLookingForArray = strongSelf.breakingSentenceIntoKeywords(sentence: myLookingForSentence!)
        })
        
        // find closest users
        let circleQuery = geoFire?.query(at: currentUserLocation, withRadius: 1000)
        
        var tempClosestUsers = [String: CLLocation]()
        var tempUsers = [[String: String]]()
        
        // observe for the closest users within the database
        circleQuery?.observe(.keyEntered, with: { [weak self] (key, location) in
            guard let strongSelf = self else { return }
            tempClosestUsers[key!] = location!
            strongSelf.closestUsers = tempClosestUsers
            strongSelf.ref.child("users").child(key!).observeSingleEvent(of: .value, with: {  (snapshot) in

                let yourAboutMeSentence = snapshot.childSnapshot(forPath: "aboutMe").value as! String
                let yourAboutMeArray = strongSelf.breakingSentenceIntoKeywords(sentence: yourAboutMeSentence)
                
                var counter = 0
                for keyword in myLookingForArray {
                    if yourAboutMeArray.contains(keyword) {
                        counter += 1
                    }
                }
                
                if counter > 0 {
                    var user = snapshot.value as! [String: String]
                    user["noMatch"] = String(counter)
                    tempUsers.append(user)
                }
                
                strongSelf.users = tempUsers
                strongSelf.myCollectionView.reloadData()
                
            }) { (error) in
                print(error.localizedDescription)
            }

        })
        
    }
    
    func configureStorage() {
        storageRef = FIRStorage.storage().reference(forURL: "gs://stanbyme-2e590.appspot.com")
    }
    
    // MARK: Delegate methods

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        if users!.count == 0 {
            UIView.animate(withDuration: 1, animations: {
                self.warningMsgTextView.alpha = 1
            })
        } else {
            warningMsgTextView.alpha = 0
        }
        
        return users!.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "collectionViewCell", for: indexPath) as! UsersCollectionViewCell
        
        // Unpack users from Firebase DataSnapshot
        let user: [String: String] = users![indexPath.row]
        
        let nickname = user[Constants.Users.Nickname] as String!
        
        let userLocation = closestUsers[user["uid"]!]
        let distanceInMeter = userLocation!.distance(from: currentUserLocation)
        let distanceInKilometer = distanceInMeter / 1000
        
        cell.textLabel?.text = nickname
        cell.detailTextLabel?.text = String(distanceInKilometer) + " km"
        cell.keywordMatchTextField.text = user["noMatch"]! + " matches"
        
        if let thumbnailURL = user[Constants.Users.ThumbnailURL], thumbnailURL.hasPrefix("gs://") {
            FIRStorage.storage().reference(forURL: thumbnailURL).data(withMaxSize: INT64_MAX){ (data, error) in
                if let error = error {
                    print("Error downloading: \(error)")
                    return
                }
                cell.imageView?.image = UIImage(data: data!)
            }
        } else {
            cell.imageView?.image = UIImage(named: "NoImage")
            if let photoURL = user[Constants.Users.ImageURL], let URL = URL(string: photoURL), let data = try? Data(contentsOf: URL) {
                cell.imageView?.image = UIImage(data: data)
            }
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        performSegue(withIdentifier: Constants.Segues.ToProfileVC, sender: nil)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [
        CLLocation]) {
        currentUserLocation = locations[0] as CLLocation
        locationManager.stopUpdatingLocation()
        configureDatabase()
    }
    
    
    // TEMP
    
    func getImageName() {
        let myIndexPaths = myCollectionView.indexPathsForVisibleItems
        for myIndexPath in myIndexPaths {
            let cell = myCollectionView.cellForItem(at: myIndexPath) as! UsersCollectionViewCell
            print("Image for \(myIndexPath): \(cell.imageView.image)")
            
            
        }
    }
    
    @IBAction func testButtonTapped(_ sender: AnyObject) {
        getImageName()
    }
    

}
