//
//  CameraVC.swift
//  CustomCamera
//
//  Created by Michil Khodulov on 03.03.18.
//  Copyright © 2018 Mad. All rights reserved.
//

import UIKit
import AVFoundation

class CameraVC: UIViewController, AVCaptureFileOutputRecordingDelegate

{
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var shootButton: UIButton!
    @IBOutlet weak var toggleButton: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    @IBOutlet weak var takenImage: UIImageView!
    @IBOutlet weak var takePhotoButton: UIButton!
    
    let captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    var movieFileOutput = AVCaptureMovieFileOutput()
    var frontCaptureDeviceInput : AVCaptureDeviceInput!
    var backCaptureDeviceInput : AVCaptureDeviceInput!
    let videoMaxDuration = 30
    var capturePrgsTimer: Timer?
    var outputFileLocation: URL?
    var videoClipsDevicePosition = [AVCaptureDevice.Position]()
    var videoClipsPath = [URL]()
    var videoClipsDuration = [Double]()
    var stopBtnPrsd = true
    var isClosed = false
    let screen = UIScreen.main.bounds
    var screenWidth : CGFloat = 0
    var screenHeight : CGFloat = 0
    
    var imagePicker: UIImagePickerController!
    
    var takePhoto = false
    
    //MARK: - Overriding methods
    override func viewDidLoad() {
        super.viewDidLoad()

        indicatorViewConfigure()
        progressViewConfigure()
        recBtnConfigure(type: "default")
        
        screenWidth = screen.width
        screenHeight = screen.height
    }
    
    override func viewDidAppear(_ animated: Bool) {
        isClosed = false
        recBtnConfigure(type: "default")
        recBtnInteraction(isEnabled: true)
        DispatchQueue.main.async {
            self.captureSession.startRunning()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkCameraAccess()
        recBtnConfigure(type: "default")
        // Hide the navigation bar on the this view controller
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Show the navigation bar on other view controllers
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isClosed = true
        indicatorView.stopAnimating()
        progressView.isHidden = false
        captureSession.stopRunning()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    //MARK: - Views configure
    fileprivate func indicatorViewConfigure() {
        indicatorView.hidesWhenStopped = true
        indicatorView.stopAnimating()
        indicatorView.isHidden = true
        indicatorView.tintColor = .white
        indicatorView.color = .white
    }
    fileprivate func progressViewConfigure() {
        progressView.setProgress(0, animated: true)
        progressView.progressViewStyle = .default
        progressView.trackTintColor = UIColor.black.withAlphaComponent(0.25)
    }
    fileprivate func recBtnConfigure(type: String) {
        switch type {
        case "press":
            UIView.animate(withDuration: 0.2, animations: {
                self.shootButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                self.shootButton.alpha = 0.5
            }, completion: { _ in
                UIView.animate(withDuration: 0.2) {
                    self.shootButton.setTitle("Taking shot...", for: .normal)
                }
            })
        case "release":
            UIView.animate(withDuration: 0.5, animations: {
                self.shootButton.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                self.shootButton.alpha = 1.0
            }, completion: { _ in
                UIView.animate(withDuration: 0.2) {
                    self.shootButton.setTitle("Record video", for: .normal)
                }
            })
        case "minimalDelayReached":
            UIView.animate(withDuration: 0.5, animations: {
                self.shootButton.alpha = 1.0
                self.shootButton.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            }, completion: { _ in
                UIView.animate(withDuration: 0.2) {
                    self.shootButton.setTitle("Stop", for: .normal)
                    self.shootButton.setTitleColor(.white, for: .normal)
                }
            })
        case "loading":
            shootButton.setTitle("", for: .normal)
            indicatorView.isHidden = false
            indicatorView.startAnimating()
        default:
            self.shootButton.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            self.shootButton.alpha = 1.0
        }
    }
    
    // MARK: - AVFondation Delegate & DataSource methods
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        for input in captureSession.inputs {
            let captureDeviceInput = input as! AVCaptureDeviceInput
            if captureDeviceInput.device.hasMediaType(AVMediaType.video) {
                videoClipsDevicePosition.append(captureDeviceInput.device.position)
            }
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        videoClipsPath.append(outputFileURL)
        videoClipsDuration.append(output.recordedDuration.seconds)
        
        if stopBtnPrsd || maxRecordDuration().seconds <= 1 {
            mergeVideoClips()
        }
        else {
            print("CameraVC: file location ", videoFileLocation())
            movieFileOutput.maxRecordedDuration = maxRecordDuration()
            movieFileOutput.startRecording(to: URL(fileURLWithPath: videoFileLocation()), recordingDelegate: self)
        }
    }
    
    
    //MARK: - Video clip merge and save
    fileprivate func mergeVideoClips() {
        let composition = AVMutableComposition()
        let videoTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        var time: Double = 0.0
        
        stopCaptureTimer()
        stopBtnPrsd = true
        recBtnConfigure(type: "loading")
        
        for duration in self.videoClipsDuration {
            print("CameraVC: duration", duration)
        }
        
        for video in self.videoClipsPath {
            let asset = AVAsset(url: video)
            
            if let videoAssetTrack = asset.tracks(withMediaType: AVMediaType.video).first {
                let audioAssetTrack = asset.tracks(withMediaType: AVMediaType.audio).first!
                let atTime = CMTime(seconds: time, preferredTimescale:0)
                
                do {
                    try videoTrack?.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration) , of: videoAssetTrack, at: atTime)
                    try audioTrack?.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration) , of: audioAssetTrack, at: atTime)
                } catch let error {
                    print(error.localizedDescription)
                }
                
                time +=  asset.duration.seconds
            }
        }
        
        videoTrack!.preferredTransform = (videoTrack?.preferredTransform.rotated(by: .pi / 2))!
        
        var needMirroring = true
        for position in videoClipsDevicePosition {
            if position == .back {
                needMirroring = false
                break
            }
        }
        
        if needMirroring {
            videoTrack!.preferredTransform = videoTrack!.preferredTransform.scaledBy(x: 1, y: -1)
        }
        
        let url = URL(fileURLWithPath: NSTemporaryDirectory().appending("video").appending(".mov"))
        let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        
        exporter?.outputURL = url
        exporter?.shouldOptimizeForNetworkUse = true
        exporter?.outputFileType = AVFileType.mov
        exporter?.exportAsynchronously(completionHandler: { () -> Void in
            DispatchQueue.main.async(execute: { () -> Void in
                if self.isClosed == false {
                    self.outputFileLocation = exporter?.outputURL
                    if let destinationVC = UIStoryboard(name: "PreviewVC", bundle: nil).instantiateViewController(withIdentifier: "PreviewVC") as? PreviewVC {
                        destinationVC.fileLocation = self.outputFileLocation
                        self.present(destinationVC, animated: false, completion: nil)
                    }
                }
            })
        })
    }
    
    
    //MARK: - Video configure
    fileprivate func maxRecordDuration() -> CMTime {
        var current = 0.0
        for duration in videoClipsDuration {
            current += duration
        }
        let seconds = max(videoMaxDuration - Int(current),0)
        let preferredTimeScale: Int32 = 1
        return CMTimeMake(Int64(seconds), preferredTimeScale)
    }
    fileprivate func videoFileLocation() -> String {
        return NSTemporaryDirectory().appending("mediafile").appending(String(videoClipsPath.count)).appending(".mov")
    }
    func startCaptureTimer() {
        if capturePrgsTimer == nil {
            capturePrgsTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(CameraVC.updateProgressView), userInfo: nil, repeats: true)
        }
    }
    func stopCaptureTimer() {
        if capturePrgsTimer != nil {
            capturePrgsTimer?.invalidate()
            capturePrgsTimer = nil
            progressView.progress = 0.0
        }
    }
    
    @objc func updateProgressView() {
        if progressView.progress >= 0.03 {
            recBtnInteraction(isEnabled: true)
            recBtnConfigure(type: "minimalDelayReached")
        } else {
            recBtnInteraction(isEnabled: false)
            takePhoto = false
        }
        progressView.progress += 0.00017
    }
    fileprivate func recBtnInteraction(isEnabled: Bool) {
        shootButton.isUserInteractionEnabled = isEnabled
        shootButton.isEnabled = isEnabled
    }
    
    fileprivate func cameraWithPosition(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified) as AVCaptureDevice.DiscoverySession
        
        for device in discovery.devices as [AVCaptureDevice] {
            if device.position == position {
                return device
            }
        }
        return nil
    }
    
    //MARK: - Camera initialization
    fileprivate func initCamera() {
        do {
            try frontCaptureDeviceInput = AVCaptureDeviceInput(device: cameraWithPosition(position : .front)!)
        } catch {
            print(error.localizedDescription)
        }
        do {
            try backCaptureDeviceInput = AVCaptureDeviceInput(device: cameraWithPosition(position : .back)!)
        } catch {
            print(error.localizedDescription)
        }
        
        //remove loaded inputs to prevent app crush
        if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                captureSession.removeInput(input)
            }
        }
        
        captureSession.sessionPreset = AVCaptureSession.Preset.high
        self.captureSession.addInput(self.frontCaptureDeviceInput)
        if let audioInput = AVCaptureDevice.default(for: AVMediaType.audio) {
            do {
                
                try self.captureSession.addInput(AVCaptureDeviceInput(device: audioInput))
            } catch {
                print(error.localizedDescription)
            }
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        self.cameraView.frame = CGRect(x: 0, y: 0, width: self.screenWidth, height: self.screenHeight)
        self.previewLayer?.frame = self.cameraView.frame
        self.cameraView.layer.addSublayer(self.previewLayer!)
        setDeviceOrientation()
        captureSession.addOutput(self.movieFileOutput)
    }
    fileprivate func checkCameraAccess() {
        var isCameraAuthStatusIsAuthorized = (AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == AVAuthorizationStatus.authorized)
        var isMicAuthStatusIsAuthorized = (AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) == AVAuthorizationStatus.authorized)
        
        if isCameraAuthStatusIsAuthorized && isMicAuthStatusIsAuthorized {
            initCamera()
        } else {
            
            var camSelected = false
            var micSelected = false
            
            AVCaptureDevice.requestAccess(for: AVMediaType.video) { response in
                camSelected = true
                if response {
                    isCameraAuthStatusIsAuthorized = true
                }
                
                if micSelected {
                   DispatchQueue.main.async {
                        self.accessAlert(isCameraAuthStatusIsAuthorized, isMicAuthStatusIsAuthorized)
                    }
                }
            }
            
            AVCaptureDevice.requestAccess(for: AVMediaType.audio) { response in
                micSelected = true
                if response {
                    isMicAuthStatusIsAuthorized = true
                }
                
                if camSelected {
                   DispatchQueue.main.async {
                        self.accessAlert(isCameraAuthStatusIsAuthorized, isMicAuthStatusIsAuthorized)
                   }
                }
            }
        }
    }
    
    fileprivate func accessAlert(_ isCameraAuthStatusIsAuthorized: Bool, _ isMicAuthStatusIsAuthorized: Bool) {
        var alertDescription = ""
        
        if isCameraAuthStatusIsAuthorized && isMicAuthStatusIsAuthorized {
            initCamera()
        } else if isCameraAuthStatusIsAuthorized == isMicAuthStatusIsAuthorized {
            alertDescription = "Нужен доступ к камере и микрофону"
        } else if isCameraAuthStatusIsAuthorized {
            alertDescription = "Нужен доступ к микрофону"
        } else if isMicAuthStatusIsAuthorized {
            alertDescription = "Нужен доступ к камере"
        }
        
        if (alertDescription != "") {
            let alert = UIAlertController(title: "Вы можете открыть доступ в Настройках", message: alertDescription, preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Отмена", style: .default, handler: { (alert) -> Void in
                self.dismiss(animated: true, completion: nil)
            }))
            
            alert.addAction(UIAlertAction(title: "Настройки", style: .cancel, handler: { (alert) -> Void in
                UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, completionHandler: { (void) -> Void in
                    self.dismiss(animated: true, completion: nil)
                })
            }))
            
            present(alert, animated: true, completion: nil)
        }
    }
    fileprivate func setDeviceOrientation() {
        if let connection = previewLayer?.connection {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = deviceOrientation()
                previewLayer?.frame = view.bounds
            }
        }
    }
    
    fileprivate func deviceOrientation() -> AVCaptureVideoOrientation {
        return .portrait
    }
    
    fileprivate func updateRecordButtonTitle() {
        if stopBtnPrsd == false {
            recBtnConfigure(type: "press")
        }
        else {
            recBtnConfigure(type: "release")
        }
    }
    
    fileprivate func switchCameraInput() {
        captureSession.beginConfiguration()
        
        if captureSession.inputs.contains(where: { (input) -> Bool in
            let input = input as! AVCaptureDeviceInput
            return input == frontCaptureDeviceInput
        }) {
            captureSession.removeInput(frontCaptureDeviceInput)
            captureSession.addInput(backCaptureDeviceInput)
        }
        else {
            captureSession.removeInput(backCaptureDeviceInput)
            captureSession.addInput(frontCaptureDeviceInput)
        }
        
        captureSession.commitConfiguration()
    }
    
    
    //MARK: - IBActions
    @IBAction func didTakePhoto(_ sender: Any) {
        if takePhoto {
            takePhoto = false
        } else {
            takePhoto = true
        }
    }
    @IBAction func shootButtonPressed(_ sender: UIButton) {
        stopBtnPrsd = !stopBtnPrsd
        if stopBtnPrsd {
            stopCaptureTimer()
            recBtnInteraction(isEnabled: false)
            movieFileOutput.stopRecording()
        }
        else {
            videoClipsPath.removeAll()
            videoClipsDevicePosition.removeAll()
            videoClipsDuration.removeAll()
            movieFileOutput.maxRecordedDuration = maxRecordDuration()
            movieFileOutput.startRecording(to: URL(fileURLWithPath: videoFileLocation()), recordingDelegate: self)
            startCaptureTimer()
            updateRecordButtonTitle()
        }
    }
    
    @IBAction func toggleButtonPressed(_ sender: UIButton) {
        toggleButton.isUserInteractionEnabled = false
        
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { (timer) in
            self.toggleButton.isUserInteractionEnabled = true
        }
        
        switchCameraInput()
    }
    @IBAction func closeButtonPressed(_ sender: UIButton) {
        stopCaptureTimer()
        dismiss(animated: true, completion: nil)
    }
    
    
    //MARK: - Get image from buffer
    func getImageFromSampleBuffer (buffer:CMSampleBuffer) -> UIImage? {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            
            let imageRect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
            
            if let image = context.createCGImage(ciImage, from: imageRect) {
                return UIImage(cgImage: image, scale: UIScreen.main.scale, orientation: .right)
            }
            
        }
        
        return nil
    }
    
}
//MARK: - Photo capture
extension CameraVC: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        if takePhoto {
            takePhoto = false
            
            if let image = self.getImageFromSampleBuffer(buffer: sampleBuffer) {
                
                CustomPhotoAlbum.sharedInstance.save(image: image)
                self.takenImage.image = image
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
            }
            
            
        }
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            // we got back an error!
            let ac = UIAlertController(title: "Save error", message: error.localizedDescription, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        } else {
            let ac = UIAlertController(title: "Saved!", message: "Your altered image has been saved to your photos.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        }
    }
}

