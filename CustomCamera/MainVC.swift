//
//  MainVC.swift
//  CustomCamera
//
//  Created by Michil Khodulov on 03.03.18.
//  Copyright © 2018 Mad. All rights reserved.
//

import UIKit
import Photos

class MainVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    var images = [PHAsset]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        getPhotosAndVideos()
        collectionView.delegate = self
        collectionView.dataSource = self
    }

    
    
    override func viewDidAppear(_ animated: Bool) {
        requestAuthorization()
    }
    
    fileprivate func requestAuthorization() {
        //request access to library
        let photos = PHPhotoLibrary.authorizationStatus()
        if photos == .notDetermined {
            PHPhotoLibrary.requestAuthorization({status in
                if status == .authorized{
                    print("ACCESS GRANTED")
                    DispatchQueue.main.async {
                        self.getPhotosAndVideos()
                    }
                } else {
                    print("DENIED")
                }
            })
        }
    }
    

    //MARK: - Fetch photos and videos from library
    fileprivate func getPhotosAndVideos(){
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate",ascending: true)]
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d || mediaType = %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        let imagesAndVideos = PHAsset.fetchAssets(with: fetchOptions)
        print(imagesAndVideos.count)
        
        imagesAndVideos.enumerateObjects { (object, count, stop) in
            self.images.append(object)
        }
        self.collectionView.reloadData()
    }
    
    
    
    //MARK: - UICollectionViewDataSource
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
    
    //MARK: - UICollectionViewDelegateFlowLayout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 2.0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 1, left: 0, bottom: 3, right: 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var size : CGFloat
        switch UIDevice.current.orientation{
        case .portrait:
            size = collectionView.frame.width / 5 - 1
        case .landscapeLeft:
            size = collectionView.frame.width / 6 - 1
        case .landscapeRight:
            size = collectionView.frame.width / 6 - 1
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


