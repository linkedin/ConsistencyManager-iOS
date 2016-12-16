// © 2016 LinkedIn Corp. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at  http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

import Foundation

/**
 This class is used to show which child models have changed. This object is usually in a dictionary: `[String: ModelChange]`.
 The strings represent IDs and it shows what's changed in this ID. Either the ID has been deleted or updated.
 If it's been updated, there are potentially several models that have updated if you are using projections.
 If you are not using projections, this will always have exactly one model.
 */
public enum ModelChange: Equatable {
    case updated([ConsistencyManagerModel])
    case deleted

    public static func ==(lhs: ModelChange, rhs: ModelChange) -> Bool {
        switch (lhs, rhs) {
        case (.updated(let l), .updated(let r)):
            guard l.count == r.count else {
                return false
            }
            for i in 0..<l.count {
                if !l[i].isEqualToModel(r[i]) {
                    return false
                }
            }
            return true
        case (.deleted, .deleted):
            return true
        default:
            return false
        }
    }
}
