//
//  UIImage+Extras.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 28/12/2016.
//  Copyright © 2016 Stanley Darmawan. All rights reserved.
//

import UIKit

extension UIImage {
	func resizeWith(width: CGFloat) -> UIImage? {
		let imageView = UIImageView(frame: CGRect(origin: .zero, size: CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))))
		imageView.contentMode = .scaleAspectFit
		imageView.image = self
		UIGraphicsBeginImageContextWithOptions(imageView.bounds.size, false, scale)
		guard let context = UIGraphicsGetCurrentContext() else { return nil }
		imageView.layer.render(in: context)
		guard let result = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
		UIGraphicsEndImageContext()
		return result
	}
}
