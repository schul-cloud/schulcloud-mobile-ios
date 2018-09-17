//
//  Created for schulcloud-mobile-ios under GPL-3.0 license.
//  Copyright © HPI. All rights reserved.
//

import BrightFutures
import Common
import CoreData
import FileProvider

class FileProviderExtension: NSFileProviderExtension {
    
    let rootDirectory: File
    let fileSync: FileSync

    lazy var coordinator: NSFileCoordinator = {
        let result = NSFileCoordinator()
        result.purposeIdentifier = NSFileProviderManager.default.providerIdentifier
        return result
    }()

    override init() {
        guard let acc = LoginHelper.loadAccount() else {
            fatalError("No account, login in the main app first")
        }

        guard let account = LoginHelper.validate(acc) else {
            fatalError("Invalid Account, login again")
        }

        Globals.account = account

        rootDirectory = FileHelper.rootFolder
        fileSync = FileSync(backgroundSessionIdentifier: "org.schulcloud.fileprovider.background")
        super.init()
    }

    deinit {
        fileSync.invalidate()
    }

    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
        if identifier == .rootContainer {
            return FileProviderItem(file: rootDirectory)
        } else if identifier == .workingSet {
            throw NSFileProviderError(.noSuchItem)
        } else {
            let fetchRequest: NSFetchRequest<File> = File.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", identifier.rawValue)

            let context = CoreDataHelper.persistentContainer.newBackgroundContext()
            let result = context.fetchSingle(fetchRequest)
            if let file = result.value {
                return FileProviderItem(file: file)
            }
            throw NSFileProviderError(.noSuchItem)
        }
    }
    
    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        // resolve the given identifier to a file on disk

        let id = identifier == .rootContainer ? FileHelper.rootDirectoryID : identifier.rawValue
        let fetchRequest = File.fetchRequest() as NSFetchRequest<File>
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)

        let context = CoreDataHelper.persistentContainer.newBackgroundContext()
        guard let file = context.fetchSingle(fetchRequest).value else {
            return nil
        }
        return file.localURL
    }
    
    override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
        // resolve the given URL to a persistent identifier using a database
        // Filename of format fileid__name, extract id from filename, no need to hit the DB
        let filename = url.lastPathComponent
        guard let localURLSeparatorRange = filename.range(of: "__") else {
            return nil
        }
        let fileIdentifier = String(filename[filename.startIndex..<localURLSeparatorRange.lowerBound])
        return NSFileProviderItemIdentifier(fileIdentifier)
    }
    
    override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let identifier = persistentIdentifierForItem(at: url) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }

        do {
            let fileProviderItem = try item(for: identifier)
            let placeholderURL = NSFileProviderManager.placeholderURL(for: url)
            try NSFileProviderManager.writePlaceholder(at: placeholderURL, withMetadata: fileProviderItem)
            completionHandler(nil)
        } catch let error {
            completionHandler(error)
        }
    }

    override func startProvidingItem(at url: URL, completionHandler: @escaping ((_ error: Error?) -> Void)) {
        // Should ensure that the actual file is in the position returned by URLForItemWithIdentifier:, then call the completion handler
        guard let identifier = persistentIdentifierForItem(at: url),
              let item = try? self.item(for: identifier) else {
                completionHandler(NSFileProviderError(.noSuchItem))
                return
        }

        let id = identifier == .rootContainer ? FileHelper.rootDirectoryID : identifier.rawValue
        let context = CoreDataHelper.persistentContainer.newBackgroundContext()
        let fetchRequest = File.fetchRequest() as NSFetchRequest<File>
        fetchRequest.predicate = NSPredicate(format: "id == %@  ", id)

        guard let file = context.fetchSingle(fetchRequest).value else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }

        if FileManager.default.fileExists(atPath: file.localURL.path) {
            completionHandler(nil)
        } else {
            fileSync.download(file, background: true, progressHandler: {_ in }).onSuccess { (_) in
                DispatchQueue.main.async {
                    completionHandler(nil)
                    NSFileProviderManager.default.signalEnumerator(for: item.parentItemIdentifier, completionHandler: { _ in })
                    NSFileProviderManager.default.signalEnumerator(for: NSFileProviderItemIdentifier.workingSet, completionHandler: { _ in })
                }
            }.onFailure { (error) in
                DispatchQueue.main.async {
                    completionHandler(error)
                }
            }
        }
    }

    override func itemChanged(at url: URL) {
        // Called at some point after the file has changed; the provider may then trigger an upload
        
        /* TODO:
         - mark file at <url> as needing an update in the model
         - if there are existing NSURLSessionTasks uploading this file, cancel them
         - create a fresh background NSURLSessionTask and schedule it to upload the current modifications
         - register the NSURLSessionTask with NSFileProviderManager to provide progress updates
         */
    }
    
    override func stopProvidingItem(at url: URL) {
        print("stopProvidingItem(at: \(url))")
        // Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.
        // Care should be taken that the corresponding placeholder file stays behind after the content file has been deleted.
        
        // TODO: look up whether the file has local changes
        /*
        let fileHasLocalChanges = false
        
        if !fileHasLocalChanges {
            // remove the existing file to free up space
            do {
                _ = try FileManager.default.removeItem(at: url)
            } catch {
                // Handle error
            }
            
            // write out a placeholder to facilitate future property lookups
            self.providePlaceholder(at: url, completionHandler: { error in
                // TODO: handle any error, do any necessary cleanup
            })
        }
        */
    }
    
    // MARK: - Actions
    
    /* TODO: implement the actions for items here
     each of the actions follows the same pattern:
     - make a note of the change in the local model
     - schedule a server request as a background task to inform the server of the change
     - call the completion block with the modified item in its post-modification state
     */
    
    // MARK: - Enumeration
    
    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        var maybeEnumerator: NSFileProviderEnumerator? = nil
        if (containerItemIdentifier == NSFileProviderItemIdentifier.rootContainer) {
            maybeEnumerator = FolderEnumerator(item: containerItemIdentifier)
        } else if (containerItemIdentifier == NSFileProviderItemIdentifier.workingSet) {

            let fetchRequest = File.fetchRequest() as NSFetchRequest<File>
            fetchRequest.predicate = FileHelper.workingSetPredicate

            let fetchResult = CoreDataHelper.viewContext.fetchMultiple(fetchRequest)
            guard let result = fetchResult.value else {
                fatalError(fetchResult.error?.localizedDescription ?? "")
            }

            maybeEnumerator = WorkingSetEnumerator(workingSet: result)
        } else {
            let item = try self.item(for: containerItemIdentifier) as! FileProviderItem
            let id = item.itemIdentifier == .rootContainer ? FileHelper.rootDirectoryID : item.itemIdentifier.rawValue

            let fetchRequest = File.fetchRequest() as NSFetchRequest<File>
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)

            let context = CoreDataHelper.persistentContainer.newBackgroundContext()
            let file = context.fetchSingle(fetchRequest).value!
            if file.isDirectory {
                maybeEnumerator = OnlineFolderEnumerator(itemIdentifier: containerItemIdentifier, fileSync: self.fileSync)
            } else {
                maybeEnumerator = FileEnumerator(file: file)
            }
        }
        guard let enumerator = maybeEnumerator else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:])
        }
        return enumerator
    }

    override func fetchThumbnails(for itemIdentifiers: [NSFileProviderItemIdentifier],
                                  requestedSize size: CGSize,
                                  perThumbnailCompletionHandler: @escaping (NSFileProviderItemIdentifier, Data?, Error?) -> Void,
                                  completionHandler: @escaping (Error?) -> Void) -> Progress {

        let progress = Progress(totalUnitCount: Int64(itemIdentifiers.count))
        progress.isCancellable = true
        progress.cancellationHandler = {

        }

        let ids = itemIdentifiers.map { $0.rawValue }

        let fetchRequest = File.fetchRequest() as NSFetchRequest<File>
        fetchRequest.predicate = NSPredicate(format: "id IN %@", ids)

        let context = CoreDataHelper.persistentContainer.newBackgroundContext()
        let result = context.fetchMultiple(fetchRequest)
        guard let files = result.value else {
            completionHandler(result.error!)
            progress.becomeCurrent(withPendingUnitCount: Int64(itemIdentifiers.count))
            return progress
        }

        var downloadTasks = [Future<URL, SCError>]()

        for file in files {
            let itemIdentifier = FileProviderItem(file: file).itemIdentifier
            if file.thumbnailRemoteURL == nil {
                perThumbnailCompletionHandler(itemIdentifier, nil, nil)
                progress.completedUnitCount += 1
                continue
            }

            if FileManager.default.fileExists(atPath: file.localThumbnailURL.path) {
                //TODO: Handle error here
                let data = try! Data(contentsOf: file.localThumbnailURL, options: .alwaysMapped)
                perThumbnailCompletionHandler(itemIdentifier, data, nil)
                progress.completedUnitCount += 1
            }

            let future = fileSync.downloadThumbnail(from: file, background: true, progressHandler: { _ in }).onSuccess { url in
                let data = try? Data(contentsOf: url, options: .alwaysMapped)
                DispatchQueue.main.async {
                    perThumbnailCompletionHandler(itemIdentifier, data, nil)
                }
            }.onFailure { error in
                DispatchQueue.main.async {
                    perThumbnailCompletionHandler(itemIdentifier, nil, error)
                }
            }.onComplete { _ in
                DispatchQueue.main.async {
                    progress.completedUnitCount += 1
                }
            }

            downloadTasks.append(future)
        }

        downloadTasks.sequence().onSuccess { _ in
            completionHandler(nil)
        }.onFailure { error in
            completionHandler(error)
        }

        return progress
    }

    override func setTagData(_ tagData: Data?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {

        let id = itemIdentifier == .rootContainer ? FileHelper.rootDirectoryID : itemIdentifier.rawValue

        var providerItem: FileProviderItem!
        let context = CoreDataHelper.persistentContainer.newBackgroundContext()
        context.performAndWait {

            let fetchRequest = File.fetchRequest() as NSFetchRequest<File>
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)

            let f = context.fetchSingle(fetchRequest).value!
            f.localTagData = tagData

            let workingSetAnchor = context.fetchSingle(WorkingSetSyncAnchor.mainAnchorFetchRequest).value!
            workingSetAnchor.value += 1

            _ = context.saveWithResult()
            providerItem = FileProviderItem(file: f)
        }

        completionHandler(providerItem, nil)

        NSFileProviderManager.default.signalEnumerator(for: providerItem.parentItemIdentifier, completionHandler: { _ in })
        NSFileProviderManager.default.signalEnumerator(for: .workingSet, completionHandler: { _ in })
    }

    override func setFavoriteRank(_ favoriteRank: NSNumber?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        let id = itemIdentifier == .rootContainer ? FileHelper.rootDirectoryID : itemIdentifier.rawValue

        var providerItem: FileProviderItem!
        let context = CoreDataHelper.persistentContainer.newBackgroundContext()
        context.performAndWait {
            let fetchRequest = File.fetchRequest() as NSFetchRequest<File>
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)

            let rankValueData: Data?
            if let favoriteRank = favoriteRank {

                var rankValue = favoriteRank.uint64Value
                rankValueData = Data(buffer: UnsafeBufferPointer(start: &rankValue, count: 1))
            } else {
                rankValueData = nil
            }

            let f = context.fetchSingle(fetchRequest).value!
            f.favoriteRankData = rankValueData

            let workingSetAnchor = context.fetchSingle(WorkingSetSyncAnchor.mainAnchorFetchRequest).value!
            workingSetAnchor.value += 1

            _ = context.saveWithResult()
            providerItem = FileProviderItem(file: f)
        }
        completionHandler(providerItem, nil)

        NSFileProviderManager.default.signalEnumerator(for: providerItem.parentItemIdentifier, completionHandler: { _ in })
        NSFileProviderManager.default.signalEnumerator(for: .workingSet, completionHandler: { _ in })
    }

    override func setLastUsedDate(_ lastUsedDate: Date?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        let id = itemIdentifier == .rootContainer ? FileHelper.rootDirectoryID : itemIdentifier.rawValue

        var providerItem: FileProviderItem!
        let context = CoreDataHelper.persistentContainer.newBackgroundContext()
        context.performAndWait {
            let fetchRequest = File.fetchRequest() as NSFetchRequest<File>
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)

            let f = context.fetchSingle(fetchRequest).value!
            f.lastReadAt = lastUsedDate!
            
            let workingSetAnchor = context.fetchSingle(WorkingSetSyncAnchor.mainAnchorFetchRequest).value!
            workingSetAnchor.value += 1

            _ = context.saveWithResult()
            providerItem = FileProviderItem(file: f)
        }
        completionHandler(providerItem, nil)

        NSFileProviderManager.default.signalEnumerator(for: providerItem.parentItemIdentifier, completionHandler: { _ in })
        NSFileProviderManager.default.signalEnumerator(for: .workingSet, completionHandler: { _ in })
    }
}