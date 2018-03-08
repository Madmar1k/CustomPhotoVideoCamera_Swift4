//
//  MainVC.swift
//  CustomCamera
//
//  Created by Michil Khodulov on 03.03.18.
//  Copyright © 2018 Mad. All rights reserved.
//

import UIKit
import Photos

class MainVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    var images = [PHAsset]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        getImages()
        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(_ animated: Bool) {
        //request access to library
        let photos = PHPhotoLibrary.authorizationStatus()
        if photos == .notDetermined {
            PHPhotoLibrary.requestAuthorization({status in
                if status == .authorized{
                    print("ACCESS GRANTED")
                    DispatchQueue.main.async {
                        self.getImages()
                    }
                } else {
                    print("DENIED")
                }
            })
        }
    }
    
    func getImages() {
        let assets = PHAsset.fetchAssets(with: PHAssetMediaType.image, options: nil)
        assets.enumerateObjects({ (object, count, stop) in
            self.images.append(object)
        })
        
        //In order to get latest image first, we just reverse the array
        self.images.reverse()
        
        // To show photos, I have taken a UICollectionView
        self.collectionView.reloadData()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! PhotoCVC
        let asset = images[indexPath.row]
        let manager = PHImageManager.default()
        if cell.tag != 0 {
            manager.cancelImageRequest(PHImageRequestID(cell.tag))
        }
        cell.tag = Int(manager.requestImage(for: asset,
                                            targetSize: CGSize(width: 100.0, height: 100.0),
                                            contentMode: .aspectFill,
                                            options: nil) { (result, _) in
                                                cell.photoImageView?.image = result
        })
        return cell
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 2.0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 1, left: 0, bottom: 10, right: 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var size : CGFloat
        switch UIDevice.current.orientation{
        case .portrait:
            size = collectionView.frame.width / 3 - 1
        case .landscapeLeft:
            size = collectionView.frame.width / 5 - 1
        case .landscapeRight:
            size = collectionView.frame.width / 5 - 1
        default:
            size = collectionView.frame.width / 2 - 1
        }
        return CGSize(width: size, height: size)
    }
    
    /*
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "ShowPicture" {
            
            let photoVC = segue.destination as! PhotoVC
            
            if let _ = self.collectionView!.indexPathsForSelectedItems {
                
                paintingVC.index = self.index //self.goods[indexPath.first!.row] //May it found nil please re - check array values
                paintingVC.paintings = self.paintings
            }
            
        }
    }
     */
}


