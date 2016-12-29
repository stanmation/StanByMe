//
//  PictureViewController.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 29/12/2016.
//  Copyright © 2016 Stanley Darmawan. All rights reserved.
//

import UIKit
import Firebase

class PictureViewController: UIViewController {
	
	var thumbnailURL: String!
	@IBOutlet weak var imageView: UIImageView!
	@IBOutlet weak var imageProgressIndicator: UIActivityIndicatorView!
	
    override func viewDidLoad() {
        super.viewDidLoad()

		thumbnailURL.insert(contentsOf:"-fullsize".characters, at: thumbnailURL.index(thumbnailURL.endIndex, offsetBy: -4))
		
		FIRStorage.storage().reference(forURL: thumbnailURL).data(withMaxSize: INT64_MAX){ (data, error) in
			if let error = error {
				print("Error downloading: \(error)")
				self.imageProgressIndicator.stopAnimating()
				self.displayErrorAlert(alertType: .networkError, message: "")
				return
			}
			self.imageProgressIndicator.stopAnimating()
			self.imageView.image = UIImage.init(data: data!)
		}
		
    }
	
	@IBAction func closeButtonTapped(_ sender: AnyObject) {
		dismiss(animated: true, completion: nil)
	}


}
