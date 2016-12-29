//
//  UIViewController+ErrorAlert.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 11/12/2016.
//  Copyright © 2016 Stanley Darmawan. All rights reserved.
//

import Foundation

extension UIViewController {
    
    enum errorType {
        case emptyField
        case badCredentials
        case networkError
        case signInError
        case noMatch
    }
    
    func displayErrorAlert(alertType: errorType, message: String) {
        let alert = UIAlertController(title: "Error", message: "", preferredStyle: .alert)
        switch(alertType) {
            
            case .emptyField:
                alert.message = message
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                break
            
            case .badCredentials:
                alert.message = message
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                break
            
            case .networkError:
                alert.message = "Internet connection is lost. Please check your connectivity"
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {(alert: UIAlertAction!) in print("networkError alert dismissed")}))
                break
            
            case .signInError:
                alert.message = message
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                break
            
            case .noMatch:
                alert.message = "No match found. This can be due to no user around your area, no user with the matching keywords or the network connection failing."
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                break
            
        }
        
        present(alert, animated: true, completion: nil)

        

    }
	
	// this function will generate thumbnail
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
    
}
