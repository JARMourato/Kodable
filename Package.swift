// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Kodable",
    platforms: [
        .macOS(.v10_14), .iOS(.v12), .tvOS(.v12), .watchOS(.v5),
    ],
    products: [
        .library(name: "Kodable", targets: ["Kodable"]),
    ],
    dependencies: [
        .package(url: "https://github.com/wickwirew/Runtime", from: "2.2.2"),
    ],
    targets: [
        .target(name: "Kodable", dependencies: ["Runtime"], path: "Sources"),
        .testTarget(name: "KodableTests", dependencies: ["Kodable"], path: "Tests"),
    ]
)
