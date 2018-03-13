//
//  CameraVC.swift
//  CustomCamera
//
//  Created by Michil Khodulov on 03.03.18.
//  Copyright © 2018 Mad. All rights reserved.
//

import UIKit
import AVFoundation

class CameraVC: UIViewController, AVCaptureFileOutputRecordingDelegate, UIGestureRecognizerDelegate

{
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var shootButton: UIButton!
    @IBOutlet weak var toggleButton: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    @IBOutlet weak var takenImage: UIImageView!
    @IBOutlet weak var takePhotoButton: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    
    let captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    var movieFileOutput = AVCaptureMovieFileOutput()
    var frontCaptureDeviceInput : AVCaptureDeviceInput!
    var backCaptureDeviceInput : AVCaptureDeviceInput!
    let videoMaxDuration = 30
    var capturePrgsTimer: Timer?
    var outputFileLocation: URL?
    var videoClipsPath = [URL]()
    var videoClipsDuration = [Double]()
    var isStopButtonPressed = true
    var isClosed = false
    let screen = UIScreen.main.bounds
    var screenWidth : CGFloat = 0
    var screenHeight : CGFloat = 0
    var isFlashlightOn = false
    let minimumZoom: CGFloat = 1.0
    let maximumZoom: CGFloat = 3.0
    var lastZoomFactor: CGFloat = 1.0
    var photoOutput = AVCapturePhotoOutput()
    var actionTimer: Timer?
    
    //MARK: - Overriding methods
    override func viewDidLoad() {
        super.viewDidLoad()

        indicatorViewConfigure()
        progressViewConfigure()
        recBtnConfigure(type: "default")
        
        screenWidth = screen.width
        screenHeight = screen.height
        
        //add gestures
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(CameraVC.pinch(_:)))
        pinchGestureRecognizer.delegate = self
        cameraView.addGestureRecognizer(pinchGestureRecognizer)
        
        /*
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(CameraVC.tapped(sender:)))
        tapGesture.numberOfTapsRequired = 1
        shootButton.addGestureRecognizer(tapGesture)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(CameraVC.longPressed(sender:)))
        shootButton.addGestureRecognizer(longPress)
         */
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
    
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        videoClipsPath.append(outputFileURL)
        videoClipsDuration.append(output.recordedDuration.seconds)
        
        if isStopButtonPressed || maxRecordDuration().seconds <= 1 {
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
        isStopButtonPressed = true
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
        self.captureSession.addInput(self.backCaptureDeviceInput)
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
        captureSession.addOutput(self.photoOutput)
    }
    
    //MARK: - Check access
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
    
    //MARK: - Camera options
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
        if isStopButtonPressed == false {
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
    
    //MARK: - Toggle flashlight
    func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video)
            else {return}
        
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                
                if on == true {
                    device.torchMode = .on
                } else {
                    device.torchMode = .off
                }
                
                device.unlockForConfiguration()
            } catch {
                print(error.localizedDescription)
            }
        } else {
            print("Torch is not available")
        }
    }
    
    //MARK: - Zoom pinch
    @objc func pinch(_ pinch: UIPinchGestureRecognizer) {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video)
            else {return}
        
        // Return zoom value between minimum and maximum zoom values
        func minMaxZoom(_ factor: CGFloat) -> CGFloat {
            return min(min(max(factor, minimumZoom), maximumZoom), device.activeFormat.videoMaxZoomFactor)
        }
        func update(scale factor: CGFloat) {
            do {
                try device.lockForConfiguration()
                defer {
                    device.unlockForConfiguration()
                }
                device.videoZoomFactor = factor
            } catch {
                print(error.localizedDescription)
            }
        }
        
        let newScaleFactor = minMaxZoom(pinch.scale * lastZoomFactor)
        
        switch pinch.state {
        case .began:
            fallthrough
        case .changed:
            update(scale: newScaleFactor)
        case .ended:
            lastZoomFactor = minMaxZoom(newScaleFactor)
            update(scale: lastZoomFactor)
        default:
            break
        }
        
    }
    
    //MARK: - Shoot action
    func shootButtonPressed() {
        isStopButtonPressed = !isStopButtonPressed
        if isStopButtonPressed {
            stopCaptureTimer()
            recBtnInteraction(isEnabled: false)
            movieFileOutput.stopRecording()
        }
        else {
            FileManager.default.clearTmpDirectory()
            videoClipsPath.removeAll()
            videoClipsDuration.removeAll()
            movieFileOutput.maxRecordedDuration = maxRecordDuration()
            movieFileOutput.startRecording(to: URL(fileURLWithPath: videoFileLocation()), recordingDelegate: self)
            startCaptureTimer()
            updateRecordButtonTitle()
        }
    }
    
    //MARK: - IBActions
    
    @IBAction func shootDown(_ sender: UIButton) {
        actionTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false, block: { (timer) in
            self.shootButtonPressed()
        })
    }
    @IBAction func shootTouchUpInside(_ sender: UIButton) {
        actionTimer?.invalidate()
        actionTimer = nil
        self.didTakePhoto(sender)
    }
    @IBAction func shootTouchUpOutside(_ sender: UIButton) {
        actionTimer?.invalidate()
        actionTimer = nil
        self.shootButtonPressed()
    }
    @IBAction func shootTouchCancel(_ sender: UIButton) {
        actionTimer?.invalidate()
        actionTimer = nil
        self.shootButtonPressed()
    }
    
    
    @IBAction func toggleFlash(_ sender: UIButton) {
        //do nothing if front camera enabled
        if captureSession.inputs.contains(where: { (input) -> Bool in
            let input = input as! AVCaptureDeviceInput
            return input == frontCaptureDeviceInput
        }) {
            return
        }
        
        isFlashlightOn = !isFlashlightOn
        toggleTorch(on: isFlashlightOn)
        if isFlashlightOn {
            sender.setImage(#imageLiteral(resourceName: "icons8-flash_on"), for: .normal)
        } else {
            sender.setImage(#imageLiteral(resourceName: "icons8-flash_off"), for: .normal)
        }
    }
    
    @IBAction func didTakePhoto(_ sender: Any) {
        let settings = AVCapturePhotoSettings()
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                             kCVPixelBufferWidthKey as String: 300,
                             kCVPixelBufferHeightKey as String: 300]
        settings.previewPhotoFormat = previewFormat
        self.photoOutput.capturePhoto(with: settings, delegate: self)
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
        if let destinationVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MainVC") as? MainVC {
            self.present(destinationVC, animated: false, completion: nil)
        }
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
/*
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
 */
extension CameraVC: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            return
        }
        
        if let sampleBuffer = photoSampleBuffer, let previewBuffer = previewPhotoSampleBuffer, let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewBuffer) {
            let image = UIImage(data: dataImage)!
            CustomPhotoAlbum.sharedInstance.save(image: image)
            self.takenImage.image = image
        }
    }
}

























