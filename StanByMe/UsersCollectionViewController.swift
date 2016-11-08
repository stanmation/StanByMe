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
    var users:[FIRDataSnapshot]?
    var closestUsers = [String: CLLocation]()
    
    var partnerUID: String?
    fileprivate var _refHandle: FIRDatabaseHandle!
    
    var storageRef: FIRStorageReference!
    var remoteConfig: FIRRemoteConfig!
    var geoFire: GeoFire?
    
    let locationManager = CLLocationManager()
    var currentUserLocation = CLLocation()
    
    @IBOutlet weak var myCollectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let currentUserEmail = FIRAuth.auth()?.currentUser?.email
        title = currentUserEmail
        
        configureStorage()

        ref = FIRDatabase.database().reference()
        users = [FIRDataSnapshot]()
        
        // configure location manager
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.stopUpdatingLocation()

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        locationManager.startUpdatingLocation()
    }
    
    func configureDatabase() {
        
        // set your user location
        let currentUserID = FIRAuth.auth()?.currentUser?.uid
        geoFire = GeoFire(firebaseRef: ref.child("locations"))
        geoFire?.setLocation(currentUserLocation, forKey: currentUserID!)

        
        // find closest users
        let circleQuery = geoFire?.query(at: currentUserLocation, withRadius: 1000)
        
        var tempClosestUsers = [String: CLLocation]()
        var tempUsers = [FIRDataSnapshot]()
        
        // observe for the closest users within the database
        circleQuery?.observe(.keyEntered, with: { [weak self] (key, location) in
            guard let strongSelf = self else { return }
            tempClosestUsers[key!] = location!
            strongSelf.closestUsers = tempClosestUsers
            strongSelf.ref.child("users").child(key!).observeSingleEvent(of: .value, with: {  (snapshot) in
                //                //ref for using hashtag
                //                if (snapshot.childSnapshot(forPath: "aboutMe").value! as! String) == "test" {
                //                    tempUsers.append(snapshot)
                //
                //                }
                tempUsers.append(snapshot) // this line will be deleted if we use hashtag
                
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
    
    
    @IBAction func signOutButtonPressed(_ sender: AnyObject) {
        let firebaseAuth = FIRAuth.auth()
        do {
            try firebaseAuth?.signOut()
            AppState.sharedInstance.signedIn = false
            locationManager.stopUpdatingLocation()
            dismiss(animated: true, completion: nil)
        } catch let signOutError as NSError {
            print ("Error signing out: \(signOutError.localizedDescription)")
        }
    }

    
    // MARK: Delegate methods

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return users!.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "collectionViewCell", for: indexPath) as! UsersCollectionViewCell
        
        // Unpack users from Firebase DataSnapshot
        let userSnapshot: FIRDataSnapshot! = users![indexPath.row]
        let user = userSnapshot.value as! Dictionary<String, String>
        
        let nickname = user[Constants.Users.Nickname] as String!
        
        let userLocation = closestUsers[userSnapshot.key]
        let distanceInMeter = userLocation!.distance(from: currentUserLocation)
        let distanceInKilometer = distanceInMeter / 1000
        
        cell.textLabel?.text = nickname
        cell.detailTextLabel?.text = String(distanceInKilometer) + " km"
        
        if let imageURL = user[Constants.Users.ImageURL] {
            if imageURL.hasPrefix("gs://") {
                FIRStorage.storage().reference(forURL: imageURL).data(withMaxSize: INT64_MAX){ (data, error) in
                    if let error = error {
                        print("Error downloading: \(error)")
                        return
                    }
                    cell.imageView?.image = UIImage.init(data: data!)
                }
            } else if let URL = URL(string: imageURL), let data = try? Data(contentsOf: URL) {
                cell.imageView?.image = UIImage.init(data: data)
            }
        } else {
            cell.imageView?.image = UIImage(named: "ic_account_circle")
            if let photoURL = user[Constants.Users.ImageURL], let URL = URL(string: photoURL), let data = try? Data(contentsOf: URL) {
                cell.imageView?.image = UIImage(data: data)
            }
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let userSnapshot: FIRDataSnapshot! = self.users![indexPath.row]
        let user = userSnapshot.value as! Dictionary<String, String>
        partnerUID = user["uid"]! as String
        performSegue(withIdentifier: Constants.Segues.ToMessageVC, sender: nil)

    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [
        CLLocation]) {
        currentUserLocation = locations[0] as CLLocation
        locationManager.stopUpdatingLocation()
        configureDatabase()
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is MessageViewController {
            
            let controller = segue.destination as! MessageViewController
            controller.partnerUID = partnerUID
        }
    }

}
