//
//  LessonHelper.swift
//  schulcloud
//
//  Created by Carl Julius Gödecken on 31.05.17.
//  Copyright © 2017 Hasso-Plattner-Institut. All rights reserved.
//

import Foundation
import Alamofire
import BrightFutures
import CoreData

public class LessonHelper {
    
    typealias FetchResult = Future<Void, SCError>
    
    static func fetchFromServer(belongingTo course: Course) -> FetchResult {
        
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = managedObjectContext
        
        let parameters: Parameters = [
            "courseId": course.id
        ]
        return ApiHelper.request("lessons", parameters: parameters).jsonArrayFuture(keyPath: "data")
            .flatMap(privateMOC.perform, f: { json -> FetchResult in
                do {
                    let updatedLessons = try json.map{ try Lesson.upsert(data: $0, context: privateMOC) }
                    let ids = updatedLessons.map({$0.id})
                    let deleteRequest: NSFetchRequest<Lesson> = Lesson.fetchRequest()
                    deleteRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "NOT (id IN %@)", ids),
                        NSPredicate(format: "course == %@", course)
                    ])
                    try CoreDataHelper.delete(fetchRequest: deleteRequest, context: privateMOC)
                    return Future(value: Void())
                } catch let error {
                    return Future(error: .database(error.localizedDescription))
                }
            })
            .flatMap { save(privateContext: privateMOC) }
    }
    
}