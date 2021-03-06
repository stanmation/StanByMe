//
//  AppDelegate.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 29/10/2016.
//  Copyright © 2016 Stanley Darmawan. All rights reserved.
//

import UIKit
import Firebase
import ReachabilitySwift


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	
	var ref: FIRDatabaseReference!


    var window: UIWindow?
    let stack = CoreDataStack(modelName: "Model")!
	
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        print("Doc path: \(paths[0])")
        
        stack.autoSave(30)
        
        // clear the data in db
//        do {
//            try stack.dropAllData()
//        } catch {
//            print("can't drop the data")
//        }

        FIRApp.configure()
		
		registerForPushNotifications(application: application)
		
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
	
	// push notification functions
	
	func registerForPushNotifications(application: UIApplication) {
		let notificationSettings = UIUserNotificationSettings(types: [.badge, .sound, .alert], categories: nil)
		application.registerUserNotificationSettings(notificationSettings)
	}
	
	func application(_ application: UIApplication, didRegister notificationSettings: UIUserNotificationSettings) {
		if notificationSettings.types != .none {
			application.registerForRemoteNotifications()
		}
	}
	
	func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
		
		deviceToken.withUnsafeBytes { (bytes: UnsafePointer<CChar>) -> Void in
			let tokenChars = UnsafePointer<CChar>(bytes)
			
			var tokenString = ""
			
			for i in 0..<deviceToken.count {
				tokenString += String(format: "%02.2hhx", arguments: [tokenChars[i]])
			}
			
			print("Device Token:", tokenString)
			
			UserDefaults.standard.setValue(tokenString, forKey: "push_notif_token")
			
			if AppState.sharedInstance.signedIn {
				let currentUserID = FIRAuth.auth()?.currentUser?.uid
				ref = FIRDatabase.database().reference()
			ref.child("users").child(currentUserID!).child("pushNotifToken").setValue(tokenString)
			}

		}



	}
	
 
	func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
		print("Failed to register:", error)
	}
	

}

