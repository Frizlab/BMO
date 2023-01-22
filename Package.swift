// swift-tools-version:5.7
import PackageDescription


let swiftSettings: [SwiftSetting] = []
//let swiftSettings: [SwiftSetting] = [.unsafeFlags(["-Xfrontend", "-warn-concurrency", "-Xfrontend", "-enable-actor-data-race-checks"])]

let package = Package(
	name: "BMO",
	products: buildArray{
		$0.append(.library(name: "BMO", targets: ["BMO"]))
		$0.append(.library(name: "BMOCoreData", targets: ["BMOCoreData"]))
	},
	targets: buildArray{
		$0.append(.target(name: "BMO", swiftSettings: swiftSettings))
		$0.append(.testTarget(name: "BMOTests", dependencies: ["BMO"], swiftSettings: swiftSettings))
		
		$0.append(.target(name: "BMOCoreData", dependencies: buildArray{
			$0.append(.target(name: "BMO"))
		}, swiftSettings: swiftSettings))
		$0.append(.testTarget(name: "BMOCoreDataTests", dependencies: ["BMOCoreData"], swiftSettings: swiftSettings))
	}
)


func buildArray<Element>(of type: Any.Type = Element.self, _ builder: (_ collection: inout [Element]) -> Void) -> [Element] {
	var ret = [Element]()
	builder(&ret)
	return ret
}
