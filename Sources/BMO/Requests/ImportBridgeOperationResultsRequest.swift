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



public struct ImportBridgeOperationResultsRequest<Bridge : BridgeProtocol> {
	
	let db: Bridge.Db
	
	let bridge: Bridge
	/**
	 The operation from which the results will be extracted to be processed.
	 The operation does not have to be finished when creating the request, only when processing it. */
	let operation: Bridge.BackOperation
	
	let expectedEntity: Bridge.Db.EntityDescription
	let updatedObjectId: Bridge.Db.ObjectID?
	
	let userInfo: Bridge.UserInfo
	
	let importPreparationBlock: (() throws -> Bool)?
	let importSuccessBlock: ((_ importResults: ImportResult<Bridge.Db>) throws -> Void)?
	/**
	 Also called if `fastImportSuccessBlock` or `fastImportPreparationBlock` fail.
	 __NOT__ called if `fastImportPreparationBlock` returns `false` though. */
	let importErrorBlock: ((_ error: Swift.Error) -> Void)?
	
}
