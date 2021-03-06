//
//  Created for schulcloud-mobile-ios under GPL-3.0 license.
//  Copyright © HPI. All rights reserved.
//

import Foundation

public extension Bundle {
    var appGroupIdentifier: String? {
        return self.infoDictionary?["APP_GROUP_IDENTIFIER"] as? String
    }

    var keychainGroupIdentifier: String? {
        return self.infoDictionary?["KEYCHAIN_GROUP"] as? String
    }
}
