//
//  Created for schulcloud-mobile-ios under GPL-3.0 license.
//  Copyright © HPI. All rights reserved.
//

import BrightFutures
import CoreData
import Foundation
import Marshal

// MARK: Helper to manage FileMetadata and local files
public enum FileHelper {

    public static var rootDirectoryID = "root"
    public static var coursesDirectoryID = "courses"
    public static var sharedDirectoryID = "shared"
    public static var userDirectoryID: String {
        return "users/\(Globals.account?.userId ?? "")/"
    }

    private static var notSynchronizedPath: [String] = {
        return [rootDirectoryID]
    }()

    fileprivate static var userDataRootURL: URL {
        let userId = Globals.account?.userId ?? "0"
        let url = URL(string: "users")!
        return url.appendingPathComponent(userId, isDirectory: true)
    }

    public static var rootFolder: File {
        if let root = fetchRootFolder() { return root }
        createBaseStructure()
        return fetchRootFolder()!

    }

    fileprivate static func fetchRootFolder() -> File? {
        let fetchRequest = NSFetchRequest(entityName: "File") as NSFetchRequest<File>
        fetchRequest.predicate = NSPredicate(format: "id == %@", rootDirectoryID)

        let result = CoreDataHelper.viewContext.fetchSingle(fetchRequest)
        if case let .success(file) = result {
            return file
        } else {
            return nil
        }
    }

    /// Create the basic folder structure
    static func createBaseStructure() {
        do {
            try FileManager.default.createDirectory(at: File.localContainerURL, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.createDirectory(at: File.thumbnailContainerURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            fatalError("Can't create local file container")
        }

        let context = CoreDataHelper.persistentContainer.newBackgroundContext()
        context.performAndWait {
            let anchor = WorkingSetSyncAnchor(context: context)
            anchor.id = WorkingSetSyncAnchor.mainId
            anchor.value = 0
        }
        /** Root
            |
            |_ Personal Directory
            |
            |_ Courses Directory
            |
            |_ Shared Directory
        */
        context.performAndWait {
            let rootFolder = File.createLocal(context: context,
                                              id: rootDirectoryID,
                                              name: "Dateien",
                                              parentFolder: nil,
                                              isDirectory: true,
                                              owner: .user(id: Globals.currentUser!.id))

            File.createLocal(context: context,
                             id: userDirectoryID,
                             name: "Meine Dateien",
                             parentFolder: rootFolder,
                             isDirectory: true,
                             owner: .user(id: Globals.currentUser!.id))
            File.createLocal(context: context,
                             id: coursesDirectoryID,
                             name: "Kurs-Dateien",
                             parentFolder: rootFolder,
                             isDirectory: true,
                             owner: .user(id: Globals.currentUser!.id))
            File.createLocal(context: context,
                             id: sharedDirectoryID,
                             name: "geteilte Dateien",
                             parentFolder: rootFolder,
                             isDirectory: true,
                             owner: .user(id: Globals.currentUser!.id))

            if case let .failure(error) = context.saveWithResult() {
                fatalError("Unresolved error \(error)") // TODO: replace this with something more friendly
            }
        }
    }

    /// Update content of directory with new content, inserting, updating or deleting files when needed
    /// - Parameter parentFolder: the folder of which we want to update the content of
    /// - Parameter contents: the new content
    public static func updateDatabase(contentsOf parentFolder: File, using contents: [[String: Any]]) -> Result<[File], SCError> {
        let parentFolderObjectId = parentFolder.objectID
        let context = CoreDataHelper.persistentContainer.newBackgroundContext()
        return context.performAndWait {
            do {
                guard let parentFolder = context.existingTypedObject(with: parentFolderObjectId) as? File else {
                    log.error("Unable to find parent folder")
                    return .failure(.coreDataObjectNotFound)
                }

                var createdItem = [File]()

                for data in contents {
                    createdItem.append( try File.createOrUpdate(inContext: context, parentFolder: parentFolder, data: data))
                }

                // remove deleted files or folders
                let currentItemsIDs: [String] =  createdItem.map { $0.id }
                let parentFolderPredicate = NSPredicate(format: "parentDirectory == %@", parentFolder)
                let notOnServerPredicate = NSPredicate(format: "NOT (id IN %@)", currentItemsIDs)
                let isDownloadedPredicate = NSPredicate(format: "downloadStateValue == \(File.DownloadState.downloaded.rawValue)")

                let locallyCachedFiles = NSFetchRequest<File>(entityName: "File")
                locallyCachedFiles.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    notOnServerPredicate,
                    parentFolderPredicate,
                    isDownloadedPredicate,
                ])

                let coordinator = NSFileCoordinator()
                let deletedFilesWithLocalCache = context.fetchMultiple(locallyCachedFiles).value ?? []
                for file in deletedFilesWithLocalCache {
                    var error: NSError?
                    coordinator.coordinate(writingItemAt: file.localURL, options: .forDeleting, error: &error) { url in
                        try? FileManager.default.removeItem(at: url)
                    }
                }

                let deletedFileFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "File")
                deletedFileFetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notOnServerPredicate, parentFolderPredicate])
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: deletedFileFetchRequest)
                try context.execute(deleteRequest)

                try context.save()
                // TODO(FileProvider): Signal changes in the parent folder here
                return .success(createdItem)
            } catch let error as MarshalError {
                return .failure(.jsonDeserialization(error.localizedDescription))
            } catch {
                log.error("Error updating directory content", error: error)
                return .failure(.coreData(error))
            }
        }
    }
}

// MARK: Course folder structure management
extension FileHelper {

    /// Update the courses directory stucture with courses changes
    /// - Parameter changes: A list of changes to the course directory (keys [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey], value: id, name tuple)
    public static func processCourseUpdates(changes: [String: [(id: String, name: String)]]) {
        let objectID = FileHelper.rootFolder.contents.first { $0.id == FileHelper.coursesDirectoryID }!.objectID

        CoreDataHelper.persistentContainer.performBackgroundTask { context in
            guard let parentFolder = context.typedObject(with: objectID) as? File else {
                    log.error("Unable to find course directory")
                    return
            }

            if let deletedCourses = changes[NSDeletedObjectsKey], !deletedCourses.isEmpty {
                for (courseId, _) in deletedCourses {
                    guard let content = parentFolder.contents.first(where: { $0.id == courseId }) else { continue }
                    parentFolder.contents.remove(content)
                }
            }

            if let updatedCourses = changes[NSUpdatedObjectsKey], !updatedCourses.isEmpty {
                for (courseId, courseName) in updatedCourses {
                    if let file = parentFolder.contents.first(where: { $0.id == courseId }) {
                        file.name = courseName
                    } else {
                        File.createLocal(context: context,
                                         id: courseId,
                                         name: courseName,
                                         parentFolder: parentFolder,
                                         isDirectory: true,
                                         owner: .course(id: courseId))
                    }
                }
            }

            if let insertedCourses = changes[NSInsertedObjectsKey], !insertedCourses.isEmpty {
                for (courseId, courseName) in insertedCourses {
                    File.createLocal(context: context,
                                     id: courseId,
                                     name: courseName,
                                     parentFolder: parentFolder,
                                     isDirectory: true,
                                     owner: .course(id: courseId))
                }
            }

            _ = context.saveWithResult()
        }
    }
}

extension FileHelper {

    /// Predicate for file that belongs to the [workingSet](https://developer.apple.com/documentation/fileprovider/content_and_change_tracking/defining_your_file_provider_s_content#2897861)
    public static var workingSetPredicate: NSPredicate {
        let todayCompo = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let today = Calendar.current.date(from: todayCompo)
        var twoWeeksAgoCompo = DateComponents()
        twoWeeksAgoCompo.weekOfYear = -2

        let twoWeeksAgo = Calendar.current.date(byAdding: twoWeeksAgoCompo, to: today!)!

        let lastReadPred = NSPredicate(format: "lastReadAt >= %@", twoWeeksAgo as NSDate)
        let favoriteRankPredicate = NSPredicate(format: "favoriteRankData != nil")
        let tagDataPredicate = NSPredicate(format: "localTagData != nil")

        return NSCompoundPredicate(orPredicateWithSubpredicates: [lastReadPred, favoriteRankPredicate, tagDataPredicate])
    }
}
