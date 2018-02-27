//
//  Future+inject.swift
//  schulcloud
//
//  Created by Max Bothe on 08.02.18.
//  Copyright © 2018 Hasso-Plattner-Institut. All rights reserved.
//

import BrightFutures

extension Future {

    func inject(_ context: @escaping ExecutionContext = DefaultThreadingModel(), f: @escaping () -> Future<Void, Value.Error>) -> Future<Value.Value, Value.Error> {
        let promise = Promise<Value.Value, Value.Error>()

        self.onComplete(context) { result in
            switch result {
            case .success(let value):
                f().onSuccess { _ in
                    promise.success(value)
                    }.onFailure { error in
                        promise.failure(error)
                }
            case .failure(let error):
                promise.failure(error)
            }
        }

        return promise.future
    }

}