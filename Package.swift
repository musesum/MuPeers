// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MuPeer",
    platforms: [.iOS(.v17)],
    products: [.library(name: "MuPeers", targets: ["MuPeers"])],
    dependencies: [

    ],
    targets: [
        .target(
            name: "MuPeers",
            dependencies: [
               
            ]),
        .testTarget(
            name: "MuPeersTests",
            dependencies: ["MuPeers"]),
    ]
)
