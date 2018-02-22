//
//  Date+Marshal.swift
//  schulcloud
//
//  Created by Carl Gödecken on 24.05.17.
//  Copyright © 2017 Hasso-Plattner-Institut. All rights reserved.
//

import Foundation
import Marshal

extension Date : ValueType {

    static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate,
                                   .withTime,
                                   .withDashSeparatorInDate,
                                   .withColonSeparatorInTime]
        return formatter
    }()

    public static func value(from object: Any) throws -> Date {
        guard let dateString = object as? String else {
            throw MarshalError.typeMismatch(expected: String.self, actual: type(of: object))
        }

        guard let date = Date.iso8601Formatter.date(from: dateString) else {
            throw MarshalError.typeMismatch(expected: "ISO8601 date string", actual: dateString)
        }
        return date
    }

}

//extension NSDate : ValueType {
//    public static func value(from object: Any) throws -> NSDate {
//        guard let dateString = object as? String else {
//            throw MarshalError.typeMismatch(expected: String.self, actual: type(of: object))
//        }
//
//        guard let date = Date.iso8601Formatter.date(from: dateString) as NSDate? else {
//            throw MarshalError.typeMismatch(expected: "ISO8601 date string", actual: dateString)
//        }
//        return date
//    }
//}


