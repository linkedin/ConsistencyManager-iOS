// © 2016 LinkedIn Corp. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at  http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

import Foundation
import ConsistencyManager


final class UpdateModel: ConsistencyManagerModel, Equatable {
	let id: String
	let liked: Bool
	
	init(id: String, liked: Bool) {
		self.id = id
		self.liked = liked
	}
	
	var modelIdentifier: String? {
		return id
	}
	
	func map(_ transform: (ConsistencyManagerModel) -> ConsistencyManagerModel?) -> ConsistencyManagerModel? {
		// Do nothing. No children.
		return self
	}
	
	func forEach(_ function: (ConsistencyManagerModel) -> ()) {
		// Do nothing. No children.
	}
}

func ==(lhs: UpdateModel, rhs: UpdateModel) -> Bool {
	return lhs.id == rhs.id && lhs.liked == rhs.liked
}
