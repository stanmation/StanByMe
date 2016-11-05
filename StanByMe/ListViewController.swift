//
//  ListViewController.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 29/10/2016.
//  Copyright © 2016 Stanley Darmawan. All rights reserved.
//

import UIKit
import Firebase
import MapKit

class ListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // Instance variables
    var ref: FIRDatabaseReference!
    var users = [FIRDataSnapshot] ()

    var closestUsers = [String: CLLocation]()

    var partnerUID: String?
    fileprivate var _refHandle: FIRDatabaseHandle!
    
    var storageRef: FIRStorageReference!
    var remoteConfig: FIRRemoteConfig!
    var geoFire: GeoFire?
    
    let locationManager = CLLocationManager()
    
    @IBOutlet weak var myTableView: UITableView!
    
    @IBOutlet weak var mapView: MKMapView!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        

        configureDatabase()
        configureStorage()
        configureRemoteConfig()
        fetchConfig()
        
        mapView.showsUserLocation = true
        locationManager.requestWhenInUseAuthorization()

    }
    
    
    @IBAction func buttonTestPressed(_ sender: AnyObject) {
        let coordinate0 = CLLocation(latitude: 37.7853889, longitude: -122.4056973)

        var coordinate1 = CLLocation()

        for closestUser in closestUsers {
            coordinate1 = closestUser.value
            let distanceInMeters = coordinate0.distance(from: coordinate1)
            let distanceInKm = distanceInMeters/1000
            print("distance: \(distanceInKm)")
        }
        
    }
    

    func configureDatabase() {
        ref = FIRDatabase.database().reference()

        // Listen for new messages in the Firebase database
//        _refHandle = ref.child("users").observe(.childAdded, with: { [weak self] (snapshot) -> Void in
//            guard let strongSelf = self else { return }
//            //            strongSelf.users.append(snapshot)
//            //            strongSelf.myTableView.insertRows(at: [IndexPath(row: strongSelf.users.count-1, section: 0)], with: .automatic)
//            })
        
        // set current user location
        let userID = FIRAuth.auth()?.currentUser?.uid
        geoFire = GeoFire(firebaseRef: ref.child("locations"))
        geoFire?.setLocation(CLLocation(latitude: 37.7853889, longitude: -122.4056973), forKey: userID!)
        
        // set temp users Locations to test out the location
        setTempUserLocations()
        
        // find closest users
        let center = CLLocation(latitude: 37.7832889, longitude: -122.4056973)
        let circleQuery = geoFire?.query(at: center, withRadius: 1)
        
        
        // current user coordinate
        let coordinate0 = CLLocation(latitude: 37.7853889, longitude: -122.4056973)

        
        circleQuery?.observe(.keyEntered, with: { [weak self] (key, location) in
            guard let strongSelf = self else { return }
            let distanceInMeter = location!.distance(from: coordinate0)
            print("distance for \(key): \(distanceInMeter)")
            strongSelf.closestUsers[key!] = location!
            
        })
        
        _refHandle = ref.child("users").observe(.childAdded, with: { [weak self] (snapshot) -> Void in
            guard let strongSelf = self else { return }
            let key = snapshot.key
            if strongSelf.closestUsers[key] != nil && (snapshot.childSnapshot(forPath: "aboutMe").value! as! String) == "nothing" {
                strongSelf.users.append(snapshot)
                strongSelf.myTableView.insertRows(at: [IndexPath(row: strongSelf.users.count-1, section: 0)], with: .automatic)
            }
        })

    }
    
    func setTempUserLocations() {
        geoFire = GeoFire(firebaseRef: ref.child("locations"))
        geoFire?.setLocation(CLLocation(latitude: 37.7853900, longitude: -122.4056500), forKey: "usLQsZlVv2Nl29Q999aZs6iUqRl2")
    }
    
    func configureStorage() {
        storageRef = FIRStorage.storage().reference(forURL: "gs://stanbyme-2e590.appspot.com")
    }
    
    func configureRemoteConfig() {
        remoteConfig = FIRRemoteConfig.remoteConfig()
        // Create Remote Config Setting to enable developer mode.
        // Fetching configs from the server is normally limited to 5 requests per hour.
        // Enabling developer mode allows many more requests to be made per hour, so developers
        // can test different config values during development.
        let remoteConfigSettings = FIRRemoteConfigSettings(developerModeEnabled: true)
        remoteConfig.configSettings = remoteConfigSettings!
    }
    
    func fetchConfig() {
        var expirationDuration: Double = 3600
        // If in developer mode cacheExpiration is set to 0 so each fetch will retrieve values from
        // the server.
        if (self.remoteConfig.configSettings.isDeveloperModeEnabled) {
            expirationDuration = 0
        }
        
        // cacheExpirationSeconds is set to cacheExpiration here, indicating that any previously
        // fetched and cached config would be considered expired because it would have been fetched
        // more than cacheExpiration seconds ago. Thus the next fetch would go to the server unless
        // throttling is in progress. The default expiration duration is 43200 (12 hours).
//        remoteConfig.fetch(withExpirationDuration: expirationDuration) { (status, error) in
//            if (status == .success) {
//                print("Config fetched!")
//                self.remoteConfig.activateFetched()
//                let friendlyMsgLength = self.remoteConfig["friendly_msg_length"]
//                if (friendlyMsgLength.source != .static) {
//                    self.msglength = friendlyMsgLength.numberValue!
//                    print("Friendly msg length config: \(self.msglength)")
//                }
//            } else {
//                print("Config not fetched")
//                print("Error \(error)")
//            }
//        }
    }
    
    
    // UITableViewDataSource protocol methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // Dequeue cell
        let cell = self.myTableView.dequeueReusableCell(withIdentifier: "tableViewCell") as UITableViewCell!
        // Unpack message from Firebase DataSnapshot
        let userSnapshot: FIRDataSnapshot! = users[indexPath.row]
        let user = userSnapshot.value as! Dictionary<String, String>
        let nickname = user[Constants.Users.nickname] as String!

        cell?.textLabel?.text = nickname
        cell?.detailTextLabel?.text = "distance"

        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let userSnapshot: FIRDataSnapshot! = self.users[indexPath.row]
        let user = userSnapshot.value as! Dictionary<String, String>
        partnerUID = user["uid"]! as String
        
        performSegue(withIdentifier: Constants.Segues.ToChatVC, sender: nil)

    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is ChatViewController {
            let controller = segue.destination as! ChatViewController
            controller.partnerUID = partnerUID
        }
    }
    
    
    @IBAction func signOut(_ sender: UIButton) {
        let firebaseAuth = FIRAuth.auth()
        do {
            try firebaseAuth?.signOut()
            AppState.sharedInstance.signedIn = false
            dismiss(animated: true, completion: nil)
        } catch let signOutError as NSError {
            print ("Error signing out: \(signOutError.localizedDescription)")
        }
        
    }


}

