// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftSQL",
    platforms: [
        .macOS(.v13),
        .iOS(.v14),
        .tvOS(.v11),
        .watchOS(.v4)
    ],
    products: [
        .library(name: "SwiftSQL", targets: ["SwiftSQL"]),
        .library(name: "SwiftSQLExt", targets: ["SwiftSQLExt"]),
        .library(name: "SwiftSQLTesting", targets: ["SwiftSQLTesting"]),
    ],
    dependencies: [
//        .package(url: "https://github.com/wildthink/uniqueid", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/wildthink/KeyValueCoding.git", from: "1.0.0"),
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            from: "1.10.0"),
    ],
    targets: [
         .target(
            name: "SwiftSQL",
            dependencies: [
//                .product(name: "UniqueID", package: "uniqueid")
            ]
        ),
        .testTarget(
            name: "SwiftSQLTests",
            dependencies: [
                "SwiftSQL",
                "SwiftSQLExt",
                "SwiftSQLTesting",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "KeyValueCoding", package: "KeyValueCoding"),
            ]
        ),
         .target(
            name: "SwiftSQLTesting",
            dependencies: [
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
         ),
        .target(
            name: "SwiftSQLExt",
            dependencies: [
                "SwiftSQL",
                .product(name: "KeyValueCoding", package: "KeyValueCoding"),
            ]
        ),
        .testTarget(
            name: "SwiftSQLExtTests",
            dependencies: [
                "SwiftSQL",
                "SwiftSQLExt",
                "SwiftSQLTesting",
                .product(name: "KeyValueCoding", package: "KeyValueCoding"),
            ]
        ),
    ]
)
