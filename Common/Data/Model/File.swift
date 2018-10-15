//
//  Created for schulcloud-mobile-ios under GPL-3.0 license.
//  Copyright © HPI. All rights reserved.
//

import CoreData
import Foundation
import Marshal
import MobileCoreServices

public final class File: NSManagedObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<File> {
        return NSFetchRequest<File>(entityName: "File")
    }

    @NSManaged public var id: String
    @NSManaged public var path: String?
    @NSManaged public var thumbnailRemoteURL: URL?
    @NSManaged public var name: String
    @NSManaged public var isDirectory: Bool
    @NSManaged public var mimeType: String?
    @NSManaged public var size: Int64
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var lastReadAt: Date

    @NSManaged public var favoriteRankData: Data?
    @NSManaged public var localTagData: Data?

    @NSManaged private var permissionsValue: Int64
    @NSManaged private var downloadStateValue: Int64
    @NSManaged private var uploadStateValue: Int64

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
            let permissions: [Permissions] = fetchedPersmissions.compactMap { Permissions(str: $0) }
            self.rawValue = permissions.reduce([]) { acc, permission -> Permissions in
                return acc.union(permission)
            }.rawValue
        }
    }

    var permissions: Permissions {
        get {
            return Permissions(rawValue: self.permissionsValue)
        }
        set {
            self.permissionsValue = newValue.rawValue
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
            guard !FileManager.default.fileExists(atPath: self.localURL.path) else {
                return .downloaded
            }

            return DownloadState(rawValue: self.downloadStateValue) ?? .notDownloaded
        }

        set {
            self.downloadStateValue = newValue.rawValue
        }
    }
}

public extension File {
    public enum UploadState: Int64 {
        case notUploaded = 0
        case uploading = 1
        case uploaded = 2
        case uploadError = 3
    }

    public var uploadState: UploadState {
        get {
            return UploadState(rawValue: self.uploadStateValue) ?? .notUploaded
        }
        set {
            self.uploadStateValue = newValue.rawValue
        }
    }
}

extension File {

    @discardableResult static func createLocal(context: NSManagedObjectContext,
                                               id: String,
                                               name: String,
                                               parentFolder: File?,
                                               isDirectory: Bool,
                                               path: String? = nil) -> File {
        let file = File(context: context)
        file.id = id

        file.path = path
        file.thumbnailRemoteURL = nil

        file.name = name
        file.isDirectory = isDirectory
        file.parentDirectory = parentFolder
        file.createdAt = Date()
        file.updatedAt = file.createdAt
        file.lastReadAt = file.createdAt

        file.favoriteRankData = nil
        file.localTagData = nil

        file.permissions = .read
        file.uploadState = .uploaded
        file.downloadState = . downloaded

        return file
    }

    static func createOrUpdate(inContext context: NSManagedObjectContext, parentFolder: File, isDirectory: Bool, data: MarshaledObject) throws -> File {
        let name: String = try data.value(for: "name")
        let id: String = try data.value(for: "_id")

        let fetchRequest = NSFetchRequest<File>(entityName: "File")
        let idPredicate = NSPredicate(format: "id == %@", id)
        let parentFolderPredicate = NSPredicate(format: "parentDirectory == %@", parentFolder)
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [idPredicate, parentFolderPredicate])

        let result = try context.fetch(fetchRequest)
        if result.count > 1 {
            throw SCError.coreDataMoreThanOneObjectFound
        }

        let existed = !result.isEmpty

        let file = result.first ?? File(context: context)
        file.id = id

        let allowedCharacters = CharacterSet.whitespacesAndNewlines.inverted
        let pathString = try data.value(for: "path") as String?
        file.path = pathString?.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? ""
        let thumbnailRemoteURLString = try? data.value(for: "thumbnail") as String
        let percentEncodedThumbnailURLString = thumbnailRemoteURLString?.addingPercentEncoding(withAllowedCharacters: allowedCharacters)
        file.thumbnailRemoteURL = URL(string: percentEncodedThumbnailURLString ?? "")

        file.name = name
        file.isDirectory = isDirectory
        file.mimeType = isDirectory ? "public.folder" : try? data.value(for: "type")
        file.size = isDirectory ? 0 : try data.value(for: "size")
        file.createdAt = try data.value(for: "createdAt")
        if let updatedAt = try? data.value(for: "updatedAt") as Date {
            file.updatedAt = updatedAt
        } else {
            file.updatedAt = file.createdAt
        }

        file.lastReadAt = file.createdAt

        if existed && isDirectory {
            file.downloadState = .downloaded
        }

        //TODO(Florian): Manage here when uploading works
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

    public var remoteURL: URL? {
        guard let parentURL = self.parentDirectory?.remoteURL else {
            if let path = self.path,
                let url = URL(string: path) {
                return url
            }
            return nil
        }

        return parentURL.appendingPathComponent(self.name, isDirectory: self.isDirectory)
    }

    static var localContainerURL: URL {
        if #available(iOS 11.0, *) {
            return NSFileProviderManager.default.documentStorageURL
        } else {
            // This returns the same URL as the iOS 11.0 documentStorageURL
            return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Bundle.main.appGroupIdentifier!)!.appendingPathComponent("File Provider Storage")
        }
    }

    static var thumbnailContainerURL: URL {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Bundle.main.appGroupIdentifier!)!.appendingPathComponent("Caches")
    }

    public var localFileName: String {
        return "\(self.id)__\(self.name)"
    }

    public static func id(from url: URL) -> String? {
        // resolve the given URL to a persistent identifier using a database
        // Filename of format fileid__name, extract id from filename, no need to hit the DB
        let filename = url.lastPathComponent
        guard let localURLSeparatorRange = filename.range(of: "__") else {
            return nil
        }

        return String(filename[filename.startIndex..<localURLSeparatorRange.lowerBound])
    }

    public var localURL: URL {
        let allowedCharacters = CharacterSet.whitespacesAndNewlines.inverted
        return File.localContainerURL.appendingPathComponent(self.localFileName.addingPercentEncoding(withAllowedCharacters: allowedCharacters)!)
    }

    public var localThumbnailURL: URL {
        return File.thumbnailContainerURL.appendingPathComponent("thumnail_\(self.thumbnailRemoteURL!.lastPathComponent)")
    }

    public var detail: String? {
        guard !self.isDirectory else {
            return nil
        }

        return ByteCountFormatter.string(fromByteCount: self.size, countStyle: .binary)
    }

    public var UTI: String? {
        guard !self.isDirectory else {
            return kUTTypeFolder as String
        }

        guard let mimeType = self.mimeType else {
            return ""
        }

        return File.mimeToUTI(mime: mimeType)
    }

    private static func mimeToUTI(mime: String) -> String? {
        let cfMime = mime as CFString
        guard let strPtr = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, cfMime, nil) else {
            return nil
        }

        let cfUTI = Unmanaged<CFString>.fromOpaque(strPtr.toOpaque()).takeUnretainedValue() as CFString
        return cfUTI as String
    }
}

// MARK: Convenient requests
extension File {
    public static func by(id: String, in context: NSManagedObjectContext) -> File? {
        assert(!id.isEmpty)
        let fetchRequest = File.fetchRequest() as NSFetchRequest<File>
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)

        let result = context.fetchSingle(fetchRequest)
        guard let value = result.value else {
            log.error("Didn't find file with id: \(id)")
            return nil
        }

        return value
    }

    public static func with(parentId id: String, in context: NSManagedObjectContext) -> [File]? {
        assert(!id.isEmpty)

        let fetchRequest = File.fetchRequest() as NSFetchRequest<File>
        fetchRequest.predicate = NSPredicate(format: "parentDirectory.id == %@", id)

        let result = context.fetchMultiple(fetchRequest)
        guard let value = result.value else {
            log.error("Error looking for item with parentID: \(id)")
            return nil
        }

        return value
    }

    public static func with(ids: [String], in context: NSManagedObjectContext) -> [File]? {
        assert(!ids.isEmpty)
        assert(!(ids.map { $0.isEmpty }.contains(true))) // no empty string the list of ids

        let fetchRequest = File.fetchRequest() as NSFetchRequest<File>
        fetchRequest.predicate = NSPredicate(format: "id IN %@", ids)

        let result = context.fetchMultiple(fetchRequest)
        guard let value = result.value else {
            log.error("Error looking with ids")
            return nil
        }

        return value
    }
}
