/*
Copyright 2022 happn

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



public enum OperationLifecycleError : Error {
	
	/** The initial result of all BMO operations is a failure with this error until the operation is started. */
	case notStarted
	/** The result of all BMO operations are set to a failure with this error after the operation has started and until the operation is finished. */
	case inProgress
	
	/**
	 An error representing an operation that was stopped because it was cancelled.
	 
	 This can be removed when the minimum supported version of BMO is high enough (to be replaced by the native `Swift.CancellationError`). */
	case cancelled
	
}
