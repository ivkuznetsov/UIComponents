// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UIComponents",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "UIComponents", targets: ["UIComponents"])
    ],
    dependencies: [
        .package(url: "https://github.com/ivkuznetsov/CommonUtils.git", branch: "main"),
        .package(url: "https://github.com/ivkuznetsov/SharedUIComponents.git", branch: "main")
    ],
    targets: [
        .target(name: "UIComponents",
                dependencies: ["CommonUtils", "SharedUIComponents"],
                resources: [.copy("Resources/AlertBarView.xib"),
                            .copy("Resources/FailedView.xib"),
                            .copy("Resources/LoadingView.xib"),
                            .copy("Resources/NoObjectsView.xib"),
                            .copy("Resources/TabsCell.xib")]),
    ]
)
