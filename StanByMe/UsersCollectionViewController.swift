//
//  UsersCollectionViewController.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 8/11/2016.
//  Copyright © 2016 Stanley Darmawan. All rights reserved.
//

import UIKit
import Firebase
import ReachabilitySwift

class UsersCollectionViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, CLLocationManagerDelegate {
    
    var ref: FIRDatabaseReference!
    var users:[[String: String]]?
    var closestUsers = [String: CLLocation]()
    
    fileprivate var _refHandle: FIRDatabaseHandle!
    
    var storageRef: FIRStorageReference!
    var remoteConfig: FIRRemoteConfig!
    var geoFire: GeoFire?
    
    var didFindLocation = false
    
    var timerCountdown = 0
    var timer: Timer?
    
    let locationManager = CLLocationManager()
    var currentUserLocation = CLLocation()
    
    let reachability = Reachability()
    var isNetworkConnected = false
    
    @IBOutlet weak var warningMsgTextView: UITextView!
    @IBOutlet weak var myCollectionView: UICollectionView!
    @IBOutlet weak var flowlayout: UICollectionViewFlowLayout!
    @IBOutlet weak var getUsersProgressIndicator: UIActivityIndicatorView!
	

    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: UIControlEvents.valueChanged)
        
        return refreshControl
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //lock orientation
//        let value = UIInterfaceOrientation.portrait.rawValue
//        UIDevice.current.setValue(value, forKey: "orientation")
        
		
        myCollectionView.addSubview(refreshControl)
                
        configureStorage()

        ref = FIRDatabase.database().reference()
        users = [[String: String]]()
        
        // configure location manager
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.stopUpdatingLocation()
        
        // setup CollectionView flow layout
        let space: CGFloat = 0.0
        let dimension = (self.view.frame.size.width - (2 * space)) / 3.0
        flowlayout.minimumInteritemSpacing = space
        flowlayout.minimumLineSpacing = space
        flowlayout.itemSize = CGSize(width: dimension, height: dimension)
		
		self.locationManager.startUpdatingLocation()

    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
		
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
		
		// remove reachability
        reachability?.stopNotifier()
        NotificationCenter.default.removeObserver(self,
                                                            name: ReachabilityChangedNotification,
                                                            object: reachability)
    }
    

    // this function will be called when refresh the page by dragging
    func handleRefresh(_ refreshControl: UIRefreshControl) {
        // Do some refresh
        didFindLocation = false
        locationManager.startUpdatingLocation()
    }
    
    func reachabilityChanged(note: NSNotification) {
        
        let reachability = note.object as! Reachability
        
        if reachability.isReachable {
            self.isNetworkConnected = true

            if reachability.isReachableViaWiFi {
                print("Reachable via WiFi")
            } else {
                print("Reachable via Cellular")
            }
        } else {
            print("Network not reachable")
            DispatchQueue.main.async {
                self.isNetworkConnected = false
                self.displayErrorAlert(alertType: .networkError, message: "")
            }
        }
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
            let distanceInKilometer = round(distanceInMeter) / 1000
            controller.distance = distanceInKilometer
            
            controller.hidesBottomBarWhenPushed = true
        }
    }
    
    func updateTimer() {
        print(timerCountdown)
        timerCountdown += 1

        if timerCountdown > 10 {
            getUsersProgressIndicator.stopAnimating()
            timer?.invalidate()
            timerCountdown = 0
            self.didFindLocation = true
            displayErrorAlert(alertType: .noMatch, message: "")
        }
    }
    
    
    func breakingSentenceIntoKeywords(sentence: String) -> [String]{
        let lowercaseSentence = sentence.lowercased()
        let arrayString = lowercaseSentence.components(separatedBy: " ")
        print("arrayString for \(sentence): \(arrayString)")
        return arrayString
    }
    
//    func testNetworkConnection() {
//        let connectedRef = FIRDatabase.database().reference(withPath: ".info/connected")
//        connectedRef.observe(.value, with: { (connected) in
//            if let boolean = connected.value as? Bool , boolean == true {
//                print("connected")
//                self.configureDatabase()
//            } else {
//                print("disconnected")
//            }
//        })
//    }
    
    func configureDatabase() {
        print("configure database")
        getUsersProgressIndicator.startAnimating()
        
        // set the time out and will throw an error if time's up
        timerCountdown = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
        
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
                
                // if the no of keyword matches are more than 0, we include that users into the list
                if counter > 0 {
                    var user = snapshot.value as! [String: String]
                    // this will disable listing your profile on your list
                    if user["uid"] != currentUserID {
                        user["noMatch"] = String(counter)
                        tempUsers.append(user)
                    }
                }
                
                strongSelf.users = tempUsers
                strongSelf.myCollectionView.reloadData()
                
                if strongSelf.users?.count != 0 {
                    strongSelf.timer?.invalidate()
                    strongSelf.getUsersProgressIndicator.stopAnimating()
                }

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
        
        // still deciding if nickname will be displayed on the users list
//        let nickname = user["nickname"] as String!
        
        let userLocation = closestUsers[user["uid"]!]
        let distanceInMeter = userLocation!.distance(from: currentUserLocation)
        let distanceInKilometer = round(distanceInMeter) / 1000
        
//        cell.textLabel?.text = nickname
        cell.detailTextLabel?.text = String(distanceInKilometer) + " km"
        cell.keywordMatchTextField.text = user["noMatch"]!
        
        if let thumbnailURL = user["thumbnailURL"], thumbnailURL.hasPrefix("gs://") {
            FIRStorage.storage().reference(forURL: thumbnailURL).data(withMaxSize: INT64_MAX){ [weak self] (data, error) in
                guard let strongSelf = self else { return }

                if let error = error {
                    print("Error downloading: \(error)")
                    strongSelf.displayErrorAlert(alertType: .networkError, message: "")
                    cell.imageView?.image = UIImage(named: "NoImage")
                    cell.downloadProgressIndicator.stopAnimating()
                    return
                }
                
                cell.downloadProgressIndicator.stopAnimating()
                cell.imageView?.image = UIImage(data: data!)
            }
        } else {
            cell.imageView?.image = UIImage(named: "NoImage")
            if let photoURL = user["imageURL"], let URL = URL(string: photoURL), let data = try? Data(contentsOf: URL) {
                cell.downloadProgressIndicator.stopAnimating()
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
        
        if refreshControl.isRefreshing {
            refreshControl.endRefreshing()
        }

        if didFindLocation == false {
            if isNetworkConnected {
                configureDatabase()
                didFindLocation = true
            } else {
                getUsersProgressIndicator.stopAnimating()
                displayErrorAlert(alertType: .networkError, message: "")
            }


        }
    }
    
}
