//
//  PhotoVC.swift
//  CustomCamera
//
//  Created by Michil Khodulov on 12.03.18.
//  Copyright © 2018 Mad. All rights reserved.
//

import UIKit

class PhotoVC: UIViewController {

    var takenPhoto:UIImage?
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.contentMode = .scaleAspectFit
        if let availableImage = takenPhoto {
            imageView.image = availableImage
        }
    }
    
    
    @IBAction func goBack(_ sender: Any) {
        
        self.dismiss(animated: true, completion: nil)
        
    }

}
