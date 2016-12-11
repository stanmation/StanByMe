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
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                break
            
            case .signInError:
                alert.message = message
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                break
            
            
        }
        
        present(alert, animated: true, completion: nil)

        

    }
    
}
