/*
Copyright 2019 happn

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

import Foundation



/* What I'd have liked below, but not possible with current Swift (or ever?).
 * Instead we have generic functions in the extension.
extension Result<BridgeType : Bridge, Error> where T == BackRequestResult<CoreDataFetchRequest, BridgeType> {
	var simpleBackRequestResult: Result<BridgeBackRequestResult<BridgeType>, Error> {...}
	var simpleBackRequestSuccessValue: BridgeBackRequestResult<HappnBridge>? {...}
	var simpleBackRequestError: Swift.Error? {...}
}*/

extension Result {
	
	public var successValue: Success? {
		switch self {
			case .success(let s): return s
			case .failure:        return nil
		}
	}
	
	public var failure: Failure? {
		switch self {
			case .failure(let f): return f
			case .success:        return nil
		}
	}
	
	public func simpleBackRequestResult<RequestType, BridgeType>(forRequestPartId requestPartId: RequestType.RequestPartId) -> Result<BridgeBackRequestResult<BridgeType>, Error> where Success == BackRequestResult<RequestType, BridgeType> {
		switch self {
			case .success(let value):
				/* If there are no results for the given request part id, that means the request has been denied going to a back request and was to succeed directly
				 *  (eg. for a fetch request, when fetch type is only if no local results and there are local results). */
				return value.results[requestPartId] ?? .success(BridgeBackRequestResult(metadata: nil, returnedObjectIDsAndRelationships: [], asyncChanges: ChangesDescription()))
				
			case .failure(let e):
				return .failure(e)
		}
	}
	
	public func simpleBackRequestSuccessValue<RequestType, BridgeType>(forRequestPartId requestPartId: RequestType.RequestPartId) -> BridgeBackRequestResult<BridgeType>? where Success == BackRequestResult<RequestType, BridgeType> {
		return simpleBackRequestResult(forRequestPartId: requestPartId).successValue
	}
	
	public func simpleBackRequestError<RequestType, BridgeType>(forRequestPartId requestPartId: RequestType.RequestPartId) -> Swift.Error? where Success == BackRequestResult<RequestType, BridgeType> {
		return simpleBackRequestResult(forRequestPartId: requestPartId).failure
	}
	
	public func backRequestResultHasErrors<RequestType, BridgeType>() -> Bool where Success == BackRequestResult<RequestType, BridgeType> {
		switch self {
			case .failure: return true
			case .success(let value):
				for (_, subValue) in value.results {
					switch subValue {
						case .failure: return true
						case .success: (/*nop*/)
					}
				}
				return false
		}
	}
	
	public func backRequestResultErrors<RequestType, BridgeType>() -> [Swift.Error] where Success == BackRequestResult<RequestType, BridgeType> {
		switch self {
			case .failure(let e): return [e]
			case .success(let value):
				var errors = [Swift.Error]()
				for (_, subValue) in value.results {
					switch subValue {
						case .failure(let e): errors.append(e)
						case .success: (/*nop*/)
					}
				}
				return errors
		}
	}
	
}
