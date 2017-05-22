//
//  Account.swift
//  schulcloud
//
//  Created by Carl Gödecken on 08.05.17.
//  Copyright © 2017 Hasso-Plattner-Institut. All rights reserved.
//

import Foundation
import Locksmith



struct SchulCloudAccount: CreateableSecureStorable, ReadableSecureStorable, DeleteableSecureStorable, GenericPasswordSecureStorable, SecureStorableResultType {

    var userId: String
    var accountId: String
    
    var accessToken: String?
    
    // Required by GenericPasswordSecureStorable
    let service = "Schul-Cloud"
    var account: String { return userId }
    
    // Required by CreateableSecureStorable
    var data: [String: Any] {
        return ["accessToken": accessToken as AnyObject]
    }
    
    mutating func loadAccessTokenFromKeychain() {
        let result = readFromSecureStore()
        accessToken = result?.data?["accessToken"] as? String
    }
}

class Globals {
    static var account: SchulCloudAccount? = nil
}
