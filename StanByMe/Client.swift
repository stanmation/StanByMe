//
//  Client.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 21/01/2017.
//  Copyright © 2017 Stanley Darmawan. All rights reserved.
//

import UIKit

class Client: NSObject {
	
	func sendMessagePushNotification(token: String){
		let url: URL = URL(string: "http://localhost/stanbyme/messagepush.php")!
		let request: NSMutableURLRequest = NSMutableURLRequest(url: url)
		request.httpMethod = "POST"
		let bodyData = "token=\(token)"
		request.httpBody = bodyData.data(using: String.Encoding.utf8)
		URLSession.shared.dataTask(with: request as URLRequest) { (data, response, error) in
			if (error != nil) {
				print("There was an error with your request: \(error)")
				return
			} else {
				print("response: \(response)")
				print("data: \(	String(data: data!, encoding: String.Encoding.utf8))")
			}
			
		}.resume()
	}
	
	// MARK: Shared Instance
	
	class func sharedInstance() -> Client {
		struct Singleton {
			static var sharedInstance = Client()
		}
		return Singleton.sharedInstance
	}

}
