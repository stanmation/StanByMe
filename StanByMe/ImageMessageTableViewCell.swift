//
//  ImageMessageTableViewCell.swift
//  StanByMe
//
//  Created by Stanley Darmawan on 29/12/2016.
//  Copyright © 2016 Stanley Darmawan. All rights reserved.
//

import UIKit

class ImageMessageTableViewCell: UITableViewCell {

	let messageImageView = UIImageView()
	var thumbnailURL: String!
	
	private var outgoingConstraints: [NSLayoutConstraint]!
	private var incomingConstraints: [NSLayoutConstraint]!
	
	override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		
		messageImageView.translatesAutoresizingMaskIntoConstraints = false
		
		contentView.addSubview(messageImageView)
		
		outgoingConstraints = [
			messageImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
//			messageImageView.leadingAnchor.constraint(equalTo: contentView.centerXAnchor)
		]
		
		incomingConstraints = [
			messageImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
//			messageImageView.trailingAnchor.constraint(equalTo: contentView.centerXAnchor)
		]
		
		messageImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true
		messageImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10).isActive = true
		
		messageImageView.widthAnchor.constraint(equalToConstant: 100).isActive = true
		messageImageView.heightAnchor.constraint(equalToConstant: 100).isActive = true

		
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func incoming(incoming: Bool) {
		if incoming {
			NSLayoutConstraint.deactivate(outgoingConstraints)
			NSLayoutConstraint.activate(incomingConstraints)
		} else {
			NSLayoutConstraint.deactivate(incomingConstraints)
			NSLayoutConstraint.activate(outgoingConstraints)
		}
	}

}
