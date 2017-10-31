//
//  RoundedShadowImageView.swift
//  ImageVision
//
//  Created by Justin Erickson on 10/21/17.
//  Copyright © 2017 Justin Erickson. All rights reserved.
//

import UIKit

class RoundedShadowImageView: UIImageView {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.layer.cornerRadius = 5
        
        self.layer.shadowColor = UIColor.darkGray.cgColor
        self.layer.shadowRadius = 15
        self.layer.shadowOpacity = 0.75
    }
}
