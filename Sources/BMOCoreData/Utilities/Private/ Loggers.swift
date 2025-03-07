import Foundation
import os.log



@available(macOS 11.0, tvOS 14.0, iOS 14.0, watchOS 7.0, *)
extension Logger {
	
	static let importer          = {Logger(OSLog.importer)}()
	static let saveRequestHelper = {Logger(OSLog.saveRequestHelper)}()
	
}

extension OSLog {
	
	static let importer = {
		return OSLog(subsystem: OSLog.subsystem, category: "Importer")
	}()
	
	static let saveRequestHelper = {
		return OSLog(subsystem: OSLog.subsystem, category: "SaveRequestHelper")
	}()
	
	private static let subsystem = "me.frizlab.bmo-coredata"
	
}
