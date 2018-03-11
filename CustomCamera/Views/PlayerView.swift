//
//  PlayerView.swift
//  CustomCamera
//
//  Created by Michil Khodulov on 08.03.18.
//  Copyright © 2018 Mad. All rights reserved.
//

import UIKit
import AVFoundation

class PlayerView: UIView {
    
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        
        set {
            playerLayer.player = newValue
        }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    override public class var layerClass:Swift.AnyClass {
        get {
            return AVPlayerLayer.self
        }
    }
}
