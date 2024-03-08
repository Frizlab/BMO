import Foundation
import os.log



#if swift(>=6.0)
/* See <https://developer.apple.com/forums/thread/747816?answerId=781922022#781922022>. */
#warning("Reevaluate whether nonisolated(unsafe) is still necessary.")
#endif

@available(macOS 11.0, tvOS 14.0, iOS 14.0, watchOS 7.0, *)
extension Logger {
	
	nonisolated(unsafe) static let importer          = {Logger(OSLog.importer)}()
	nonisolated(unsafe) static let saveRequestHelper = {Logger(OSLog.saveRequestHelper)}()
	
}

extension OSLog {
	
	nonisolated(unsafe) static let importer = {
		return OSLog(subsystem: OSLog.subsystem, category: "Importer")
	}()
	
	nonisolated(unsafe) static let saveRequestHelper = {
		return OSLog(subsystem: OSLog.subsystem, category: "SaveRequestHelper")
	}()
	
	private static let subsystem = "me.frizlab.bmo-coredata"
	
}
