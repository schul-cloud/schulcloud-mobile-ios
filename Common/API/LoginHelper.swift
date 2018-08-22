//
//  Created for schulcloud-mobile-ios under GPL-3.0 license.
//  Copyright © HPI. All rights reserved.
//

import Alamofire
import BrightFutures
import Foundation
import JWTDecode
import Locksmith
import Result

public extension UserDefaults {
    public static var appGroupDefaults: UserDefaults? {
        return UserDefaults(suiteName: "group.org.schulcloud")
    }
}

public class LoginHelper {

    public static func getAccessToken(username: String?, password: String?) -> Future<String, SCError> {
        let promise = Promise<String, SCError>()

        let parameters: Parameters = [
            "username": username as Any,
            "password": password as Any,
        ]

        let loginEndpoint = Brand.default.servers.backend.appendingPathComponent("authentication/")
        Alamofire.request(loginEndpoint, method: .post, parameters: parameters, encoding: JSONEncoding.default).responseJSON { response in
            guard let json = response.result.value as? [String: Any] else {
                let error = response.error!
                // using the error directly isn't possible because Error can't be used as a concrete type
                promise.failure(.loginFailed(error.localizedDescription))
                return
            }

            if let accessToken = json["accessToken"] as? String {
                promise.success(accessToken)
            } else if let errorMessage = json["message"] as? String, errorMessage != "Error" {
                promise.failure(.loginFailed(errorMessage))
            } else if json["code"] as? Int == 401 {
                promise.failure(.wrongCredentials)
            } else {
                promise.failure(.unknown)
            }
        }

        return promise.future
    }

    public static func login(username: String?, password: String?) -> Future<Void, SCError> {
        return getAccessToken(username: username, password: password).flatMap(saveToken).flatMap { _ in
            return UserHelper.syncUser(withId: Globals.account!.userId)
        }.asVoid()
    }

    public static func saveToken(accessToken: String) -> Future<Void, SCError> {
        do {
            let jwt = try decode(jwt: accessToken)
            guard let accountId = jwt.body["accountId"] as? String, let userId = jwt.body["userId"] as? String else {
                return Future(error: SCError.loginFailed("Did not receive account id and user id"))
            }

            let account = SchulCloudAccount(userId: userId, accountId: accountId, accessToken: accessToken)
            try account.saveCredentials()
            log.info("Successfully saved login data for user \(userId) with account \(accountId)")
            Globals.account = account
//            DispatchQueue.main.async {
//                SCNotifications.initializeMessaging()
//            }

            return Future(value: Void())
        } catch let error {
            return Future(error: SCError.loginFailed(error.localizedDescription))
        }
    }

    public static func renewAccessToken() -> Future<Void, SCError> {
        return getAccessToken(username: nil, password: nil).flatMap(saveToken)
    }

    public static func loadAccount() -> SchulCloudAccount? {
        guard let defaults = UserDefaults.appGroupDefaults, let accountId = defaults.string(forKey: "accountId"), let userId = defaults.string(forKey: "userId") else {
            return nil
        }

        var account = SchulCloudAccount(userId: userId, accountId: accountId, accessToken: nil)
        account.loadAccessTokenFromKeychain()

        return account
    }

    public static func validate(_ account: SchulCloudAccount) -> SchulCloudAccount? {
        guard let accessToken = account.accessToken else {
            log.error("Could not load access token for account!")
            return nil
        }

        do {
            let jwt = try decode(jwt: accessToken)
            let expiration = jwt.body["exp"] as! Int64
            let interval = TimeInterval(exactly: expiration)!
            let expirationDate = Date(timeIntervalSince1970: interval)
            let threeHourBuffer = TimeInterval(exactly: 60 * 60 * 3)!
            let isValid = Date() < expirationDate - threeHourBuffer
            return isValid ? account : nil
        } catch let error {
            log.error("Error validating token: " + error.description)
            return nil
        }
    }

    public static func logout() {
        UserDefaults.appGroupDefaults?.set(nil, forKey: "accountId")
        UserDefaults.appGroupDefaults?.set(nil, forKey: "userId")

        do {
            CoreDataHelper.clearCoreDataStorage()
            try Globals.account!.deleteFromSecureStore()
            try CalendarEventHelper.deleteSchulcloudCalendar()
        } catch let error {
            log.error(error.localizedDescription)
        }
    }

}
