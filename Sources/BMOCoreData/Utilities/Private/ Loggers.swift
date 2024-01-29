import Foundation
import os.log



@available(macOS 11.0, *)
extension Logger {
	
	static let saveRequestHelper = {
		return Logger(OSLog.saveRequestHelper)
	}()
	
}

extension OSLog {
	
	static let saveRequestHelper = {
		return OSLog(subsystem: OSLog.subsystem, category: "SaveRequestHelper")
	}()
	
	private static let subsystem = "me.frizlab.bmo"
	
}
