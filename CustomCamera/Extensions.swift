//
//  Extensions.swift
//  CustomCamera
//
//  Created by Michil Khodulov on 09.03.18.
//  Copyright © 2018 Mad. All rights reserved.
//

import Foundation


extension FileManager {
    func clearTmpDirectory() {
        do {
            let tmpDirectory = try contentsOfDirectory(atPath: NSTemporaryDirectory())
            try tmpDirectory.forEach {[unowned self] file in
                let path = String.init(format: "%@%@", NSTemporaryDirectory(), file)
                try self.removeItem(atPath: path)
            }
        } catch {
            print(error)
        }
    }
}
