import Foundation
import ProjectDescription

let localDevelopmentTeam = ProcessInfo.processInfo.environment["SWIPECELL_DEVELOPMENT_TEAM"]
    .flatMap { $0.isEmpty ? nil : $0 }

var targetSettings: SettingsDictionary = [
    "CODE_SIGN_STYLE": "Automatic",
    "SWIFT_VERSION": "6.0",
]

if let localDevelopmentTeam {
    targetSettings["DEVELOPMENT_TEAM"] = .string(localDevelopmentTeam)
}

let project = Project(
    name: "SwipeCellDefaultShowcase",
    packages: [
        .local(path: "../..")
    ],
    settings: .settings(
        base: [
            "IPHONEOS_DEPLOYMENT_TARGET": "18.0",
            "MACOSX_DEPLOYMENT_TARGET": "15.0",
            "SWIFT_VERSION": "6.0",
        ]
    ),
    targets: [
        .target(
            name: "SwipeCellDefaultShowcase",
            destinations: .iOS,
            product: .app,
            bundleId: "com.fatbobman.SwipeCellDefaultShowcase",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [:],
                    "UISupportedInterfaceOrientations": [
                        "UIInterfaceOrientationPortrait",
                        "UIInterfaceOrientationLandscapeLeft",
                        "UIInterfaceOrientationLandscapeRight",
                    ],
                    "UISupportedInterfaceOrientations~ipad": [
                        "UIInterfaceOrientationPortrait",
                        "UIInterfaceOrientationPortraitUpsideDown",
                        "UIInterfaceOrientationLandscapeLeft",
                        "UIInterfaceOrientationLandscapeRight",
                    ],
                ]
            ),
            sources: ["Sources/**"],
            dependencies: [
                .package(product: "SwipeCell")
            ],
            settings: .settings(base: targetSettings)
        ),
        .target(
            name: "SwipeCellDefaultShowcaseMac",
            destinations: .macOS,
            product: .app,
            bundleId: "com.fatbobman.SwipeCellDefaultShowcaseMac",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleDisplayName": "SwipeCell Default Showcase"
                ]
            ),
            sources: ["Sources/**"],
            dependencies: [
                .package(product: "SwipeCell")
            ],
            settings: .settings(base: targetSettings)
        ),
    ]
)
