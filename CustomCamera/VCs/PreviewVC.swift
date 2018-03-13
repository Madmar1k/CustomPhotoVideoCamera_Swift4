//
//  PreviewVC.swift
//  CustomCamera
//
//  Created by Michil Khodulov on 07.03.18.
//  Copyright © 2018 Mad. All rights reserved.
//

import UIKit
import AVKit
import Photos

class PreviewVC: UIViewController {

    
    @IBOutlet weak var playerView: PlayerView!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var playerStatusImg: UIImageView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var removeButton: UIButton!
    
    
    @objc dynamic let player = AVPlayer()
    var alertView: UIAlertController?
    var progress: Float = 0.0
    
    var fileLocation: URL? {
        didSet {
            self.asset = AVURLAsset(url: self.fileLocation!)
        }
    }
    var asset: AVURLAsset? {
        didSet {
            guard let newAsset = asset else { return }
            loadURLAsset(newAsset)
        }
    }
    
    var playerLayer: AVPlayerLayer {
        return playerView.playerLayer
    }
    
    var playerItem: AVPlayerItem? {
        didSet {
            player.replaceCurrentItem(with: self.playerItem)
            player.actionAtItemEnd = .none
        }
    }
    static let assetKeysRequiredToPlay = ["playable"]
    
    
    //MARK: - Overriding methods
    override func viewDidLoad() {
        super.viewDidLoad()
        playerView.playerLayer.player = player
        playerView.contentMode = .scaleToFill
        progressView.setProgress(0.0, animated: true)
        
        player.volume = 10.0
        player.play()
        
        addObserver(self, forKeyPath: "player.currentItem.status", options: .new, context: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerReachedEnd(notification:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        
        playerTrackProgress()
    }
    
    // MARK: - Player observers
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "player.currentItem.status" {
            playButton.isHidden = false
        }
    }
    
    @objc func playerReachedEnd(notification: NSNotification) {
        self.asset = AVURLAsset(url: self.fileLocation!)
        self.player.pause()
    }
    
    //MARK: - UI updates
    fileprivate func updatePlayBtn() {
        if player.rate > 0 {
            player.pause()
            playerStatusImg.image = #imageLiteral(resourceName: "icons8-pause")
            playButton.setImage(#imageLiteral(resourceName: "icons8-play-1"), for: .normal)
            UIView.animate(withDuration: 0.2, animations: {
                self.playerStatusImg.alpha = 1.0
            }, completion: { finished in
                UIView.animate(withDuration: 0.8) {
                    self.playerStatusImg.alpha = 0.0
                }
            })
        }
        else {
            player.play()
            playerStatusImg.image = #imageLiteral(resourceName: "icons8-play")
            playButton.setImage(#imageLiteral(resourceName: "icons8-pause-1"), for: .normal)
            UIView.animate(withDuration: 0.2, animations: {
                self.playerStatusImg.alpha = 1.0
            }, completion: {  finished in
                UIView.animate(withDuration: 0.8) {
                    self.playerStatusImg.alpha = 0.0
                }
            })
        }
    }
    
    fileprivate func playerTrackProgress() {
        let interval: CMTime = CMTimeMake(1, 2)
        player.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main, using: { (progressTime) in
            let seconds = CMTimeGetSeconds(progressTime)
            
            if let duration = self.player.currentItem?.duration {
                let durationSeconds = CMTimeGetSeconds(duration)
                self.progressView.progress = Float(seconds / durationSeconds)
            }
        })
    }
    // MARK: - URL Asset load
    func loadURLAsset(_ asset: AVURLAsset) {
        asset.loadValuesAsynchronously(forKeys: PreviewVC.assetKeysRequiredToPlay) {
            DispatchQueue.main.async {
                guard asset == self.asset else { return }
                for key in PreviewVC.assetKeysRequiredToPlay {
                    var error: NSError?
                    if !asset.isPlayable || asset.hasProtectedContent {
                        print("Video is not playable.")
                        return
                    }
                    
                    if asset.statusOfValue(forKey: key, error: &error) == .failed {
                        print("Failed to load")
                        return
                    }
                }
                self.playerItem = AVPlayerItem(asset: asset)
            }
        }
    }
    
    //MARK: - Video save
    fileprivate func saveVideo() {
        guard let data = NSData(contentsOf: self.fileLocation!) else {
            return
        }
        
        print("File size before compression: \(Double(data.length / 1048576)) mb")
        let compressedURL = NSURL.fileURL(withPath: NSTemporaryDirectory() + NSUUID().uuidString + ".m4v")
        compressVideoAndSave(inputURL: self.fileLocation!, outputURL: compressedURL) { (exportSession) in
            guard let session = exportSession else {
                return
            }
            
            switch session.status {
            case .unknown: break
            case .waiting: break
            case .exporting: break
            case .completed:
                guard let compressedData = NSData(contentsOf: compressedURL) else {
                    return
                }
                print("File size after compression: \(Double(compressedData.length / 1048576)) mb")
                
            case .failed: break
            case .cancelled: break
            }
        }
    }
    
    fileprivate func compressVideoAndSave(inputURL: URL, outputURL: URL, handler: @escaping (_ exportSession: AVAssetExportSession?)-> Void) {
        let urlAsset = AVURLAsset(url: inputURL, options: nil)
        guard let exportSession = AVAssetExportSession(asset: urlAsset, presetName: AVAssetExportPresetMediumQuality) else {
            handler(nil)
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mov
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.exportAsynchronously(completionHandler: {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
            }) { saved, error in
                if saved {
                    print("Saved")
                }
            }
        })
    }
    
    
    //MARK: - Terminate
    fileprivate func terminateView() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        playerView.removeFromSuperview()
    }
    
    //MARK: - IBActions
    @IBAction func playAction() {
        self.updatePlayBtn()
    }
    
    @IBAction func saveAction() {
        self.saveVideo()
    }
    
    
    @IBAction func dismissBtnAct(_ sender: Any) {
        self.terminateView()
        if let destinationVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MainVC") as? MainVC {
            self.present(destinationVC, animated: false, completion: nil)
        }
    }

}
