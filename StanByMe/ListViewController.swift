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

class ListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate {
    
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
    
    @IBOutlet weak var myTableView: UITableView!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let currentUserEmail = FIRAuth.auth()?.currentUser?.email
        title = currentUserEmail
        
        configureStorage()
        configureRemoteConfig()
        fetchConfig()
        ref = FIRDatabase.database().reference()
        users = [FIRDataSnapshot]()
        
        // configure location manager
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.stopUpdatingLocation()
        
//        closestUsers ["usLQsZlVv2Nl29Q999aZs6iUqRl2"] = CLLocation(latitude: -34.863399999999999, longitude: 150.21100000000001)
//        closestUsers ["YZRqyFnrNATMvcvl1F3bcQMSxwk1"] = CLLocation(latitude: -34.863399999999999, longitude: 150.21100000000001)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        locationManager.startUpdatingLocation()
    }
    
    
    @IBAction func buttonTestPressed(_ sender: AnyObject) {

    }

    func configureDatabase() {
        
        // set your user location
        let currentUserID = FIRAuth.auth()?.currentUser?.uid
        geoFire = GeoFire(firebaseRef: ref.child("locations"))
        geoFire?.setLocation(currentUserLocation, forKey: currentUserID!)
        
        // set temp users Locations to test out the location
//        setTempUserLocations()
        
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
                strongSelf.myTableView.reloadData()

            }) { (error) in
                print(error.localizedDescription)
            }
        })

    }
    
    func setTempUserLocations() {
        geoFire = GeoFire(firebaseRef: ref.child("locations"))
        geoFire?.setLocation(CLLocation(latitude: -34.863399999999999, longitude: 150.21100000000001), forKey: "usLQsZlVv2Nl29Q999aZs6iUqRl2")
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
    
    // MARK: data source and delegate methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users!.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Dequeue cell
        let cell = self.myTableView.dequeueReusableCell(withIdentifier: "tableViewCell") as UITableViewCell!
        
        // Unpack users from Firebase DataSnapshot
        let userSnapshot: FIRDataSnapshot! = users![indexPath.row]
        let user = userSnapshot.value as! Dictionary<String, String>
        print("users: \(users)")

        let nickname = user[Constants.Users.Nickname] as String!
        
        let userLocation = closestUsers[userSnapshot.key]
        let distanceInMeter = userLocation!.distance(from: currentUserLocation)
        let distanceInKilometer = distanceInMeter / 1000
        
        cell?.textLabel?.text = nickname
        cell?.detailTextLabel?.text = String(distanceInKilometer) + " km"
        

        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        let userSnapshot: FIRDataSnapshot! = self.users![indexPath.row]
        let user = userSnapshot.value as! Dictionary<String, String>
        partnerUID = user["uid"]! as String
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        performSegue(withIdentifier: Constants.Segues.ToChatVC, sender: nil)

    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [
        CLLocation]) {
        currentUserLocation = locations[0] as CLLocation
        locationManager.stopUpdatingLocation()
        configureDatabase()
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is ChatViewController {
            let controller = segue.destination as! ChatViewController
            controller.partnerUID = partnerUID
        }
    }

}

