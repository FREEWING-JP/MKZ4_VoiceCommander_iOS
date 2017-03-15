//
//  LocalizedString.swift
//  VoiceCommander
//
//  Created by Toshinari Nakamura on 2016/10/25.
//  Copyright © 2017年 Cerevo Inc. All rights reserved.
//

import Foundation

func LocalizedString(_ key: String, _ comment: String = "") -> String {
    let ret = NSLocalizedString(key, comment: comment)
    return ret
}
