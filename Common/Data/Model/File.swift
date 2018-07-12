//
//  Created for schulcloud-mobile-ios under GPL-3.0 license.
//  Copyright © HPI. All rights reserved.
//

import CoreData
import Foundation
import Marshal

public final class File: NSManagedObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<File> {
        return NSFetchRequest<File>(entityName: "File")
    }

    @NSManaged public var id: String
    @NSManaged public var remoteURL_: String? // swiftlint:disable:this identifier_name
    @NSManaged public var thumbnailRemoteURL_: String? // swiftlint:disable:this identifier_name

    @NSManaged public var name: String
    @NSManaged public var isDirectory: Bool
    @NSManaged public var mimeType: String?
    @NSManaged public var size: Int64

    @NSManaged public var permissions_: Int64 // swiftlint:disable:this identifier_name
    @NSManaged public var downloadState_: Int64 // swiftlint:disable:this identifier_name
    @NSManaged public var uploadState_: Int64 // swiftlint:disable:this identifier_name

    @NSManaged public var parentDirectory: File?
    @NSManaged public var contents: Set<File>
}

public extension File {

    public struct Permissions: OptionSet {
        public let rawValue: Int64

        static let read = Permissions(rawValue: 1 << 1)
        static let write = Permissions(rawValue: 1 << 2)

        static let readWrite: Permissions = [.read, .write]

        public init(rawValue: Int64) {
            self.rawValue = rawValue
        }

        public init?(str: String) {
            switch str {
            case "can_read":
                self = Permissions.read
            case "can_write":
                self = Permissions.write
            default:
                return nil
            }
        }

        init(json: MarshaledObject) throws {
            let fetchedPersmissions: [String] = try json.value(for: "permissions")
            let permissions: [Permissions] = fetchedPersmissions.flatMap { Permissions(str: $0) }
            self.rawValue = permissions.reduce([]) { acc, permission -> Permissions in
                return acc.union(permission)
            }.rawValue
        }
    }

    var permissions: Permissions {
        get {
            return Permissions(rawValue: self.permissions_)
        }
        set {
            self.permissions_ = newValue.rawValue
        }
    }
}

public extension File {
    public enum DownloadState: Int64 {
        case notDownloaded = 0
        case downloading = 1
        case downloaded = 2
        case downloadFailed = 3
    }

    public var downloadState: DownloadState {
        get {
            return DownloadState(rawValue: self.downloadState_)!
        }

        set {
            self.downloadState_ = newValue.rawValue
        }
    }
}

public extension File {
    public enum UploadState: Int64 {
        case uploading = 0
        case uploaded = 1
        case uploadError = 2
    }

    public var uploadState: UploadState {
        get {
            return UploadState(rawValue: self.uploadState_)!
        }
        set {
            self.uploadState_ = newValue.rawValue
        }
    }
}

extension File {

    static func createLocal(context: NSManagedObjectContext, id: String, name: String, parentFolder: File?, isDirectory: Bool) -> File {
        return createLocal(context: context, id: id, name: name, parentFolder: parentFolder, isDirectory: isDirectory, remoteURL: nil)
    }

    static func createLocal(context: NSManagedObjectContext, id: String, name: String, parentFolder: File?, isDirectory: Bool, remoteURL: String?) -> File {
        let file = File(context: context)
        file.id = id

        file.remoteURL_ = remoteURL
        file.thumbnailRemoteURL_ = nil

        file.name = name
        file.isDirectory = isDirectory
        file.parentDirectory = parentFolder

        file.permissions = .read
        file.uploadState = .uploaded
        file.downloadState = . downloaded

        return file

    }

    static func createOrUpdate(inContext context: NSManagedObjectContext, parentFolder: File, isDirectory: Bool, data: MarshaledObject) throws -> File {
        let name: String = try data.value(for: "name")
        let id: String = try data.value(for: "_id")

        let fetchRequest = NSFetchRequest<File>(entityName: "File")
        let pathPredicate = NSPredicate(format: "id == %@", id)
        let parentFolderPredicate = NSPredicate(format: "parentDirectory == %@", parentFolder)
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [pathPredicate, parentFolderPredicate])

        let result = try context.fetch(fetchRequest)
        if result.count > 1 {
            throw SCError.database("Found more than one result for \(fetchRequest)")
        }
        let file = result.first ?? File(context: context)

        file.id = id

        let allowedCharacters = CharacterSet.whitespacesAndNewlines.inverted

        file.remoteURL_ = (try data.value(for: "key") as String?)?.addingPercentEncoding(withAllowedCharacters: allowedCharacters)
        file.thumbnailRemoteURL_ = (try data.value(for: "thumbnail") as String?)?.addingPercentEncoding(withAllowedCharacters: allowedCharacters)

        file.name = name
        file.isDirectory = isDirectory
        file.mimeType = try? data.value(for: "type")
        file.size = try data.value(for: "size")

        file.downloadState = isDirectory ? .downloaded : .notDownloaded
        file.uploadState = .uploaded

        file.parentDirectory = parentFolder

        let permissionsObject: [MarshaledObject]? = try? data.value(for: "permissions")
        let userPermission: MarshaledObject? = permissionsObject?.first { data -> Bool in
            if let userId: String = try? data.value(for: "userId"),
                userId == Globals.account?.userId { // find permission for current user
                return true
            }
            return false
        }

        if let userPermission = userPermission {
            file.permissions = try Permissions(json: userPermission)
        }

        return file
    }
}

// MARK: computed properties
extension File {

    static var localContainerURL: URL {
        //TODO: replace with fileprovidermanager when implemented

//        return NSURL.fileURL(withPath: NSTemporaryDirectory()).appendingPathComponent("UserFileData")
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.schulcloud")!.appendingPathComponent("File Provider Storage")
        /*
         if #available(iOS 11.0, *) {
            return NSFileProviderManager.default.documentStorageURL
         } else {
            return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.schulcloud")!
         }
 */
    }

    public var fileLocation: URL? {
        guard self.downloadState == .downloaded else { return nil }
        return self.localURL
    }

    public var localURL: URL {
        return File.localContainerURL.appendingPathComponent("\(self.id)__\(self.name.addingPercentEncoding(withAllowedCharacters: CharacterSet.whitespacesAndNewlines.inverted)!)")
    }

    public var remoteURL: URL? {
        guard let urlString = self.remoteURL_ else { return nil }
        return URL(string: urlString)!
    }

    public var thumbnailRemoteURL: URL? {
        guard let urlString = self.thumbnailRemoteURL_ else { return nil }
        return URL(string: urlString)!
    }

    public var detail: String? {
        guard !self.isDirectory else {
            return nil
        }

        return ByteCountFormatter.string(fromByteCount: self.size, countStyle: .binary)
    }
}
