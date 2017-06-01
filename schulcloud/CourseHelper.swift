//
//  CourseHelper.swift
//  schulcloud
//
//  Created by Carl Julius Gödecken on 31.05.17.
//  Copyright © 2017 Hasso-Plattner-Institut. All rights reserved.
//

import Foundation
import Alamofire
import BrightFutures
import CoreData

public class CourseHelper {
    
    typealias FetchResult = Future<Void, SCError>
    
    static func fetchFromServer() -> FetchResult {
        
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = managedObjectContext
        
        let keyPath: String? = "data"
        
        let parameters: Parameters = [
            "userIds": Globals.account!.userId
        ]
        return ApiHelper.request("courses", parameters: parameters).jsonArrayFuture(keyPath: keyPath)
            .flatMap(privateMOC.perform, f: { json -> FetchResult in
                do {
                    let updatedCourses = try json.map{ try Course.upsert(data: $0, context: privateMOC) }
                    let ids = updatedCourses.map({$0.id})
                    let deleteRequest: NSFetchRequest<Course> = Course.fetchRequest()
                    deleteRequest.predicate = NSPredicate(format: "NOT (id IN %@)", ids)
                    try CoreDataHelper.delete(fetchRequest: deleteRequest, context: privateMOC)
                    saveContext()
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: Homework.changeNotificationName), object: nil)
                    return Future(value: Void())
                } catch let error {
                    return Future(error: .database(error.localizedDescription))
                }
            })
            .flatMap { save(privateContext: privateMOC) }
    }
    
}