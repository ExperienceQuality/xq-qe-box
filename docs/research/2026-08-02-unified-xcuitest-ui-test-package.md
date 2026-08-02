# Unified XCUITest UI test package for consumer iOS apps

**Date:** 2026-08-02  
**Repo:** `ExperienceQuality/xq-qe-box`  
**Status:** Research (primary sources)

## Executive summary

A reusable XCUITest helper package is a normal Swift Package Manager **library product** that consumers link **only into their UI Testing target**, not the app target. Helpers ship as source (preferred) that `import XCTest` / use XCUIAutomation APIs; XCTest itself is an Xcode/system framework, not an SPM dependency—packages typically declare `linkerSettings: [.linkedFramework("XCTest")]` and/or rely on the consumer UI test target’s testing search paths. Apple’s UI testing stack is black-box (accessibility-driven) via [XCUIAutomation](https://developer.apple.com/documentation/XCUIAutomation) on top of [XCTest](https://developer.apple.com/documentation/xctest); app-side testability is a contract of stable `accessibilityIdentifier`s, launch arguments/environment, and deep links—not shared in-process app code. That model fits classic app-team CI (`xcodebuild test`) but is **architecturally separate** from xq-qe-box’s DeviceKit path (a preinstalled XCUITest **runner app** driven over JSON-RPC by `xq-motest`). Under `packages/`, ship a thin dual-product layout: XCTest-free **testability contracts** (usable by apps + agents) plus an **XCUITest helper library** for human-written UITests—do not expect one drop-in library to also become DeviceKit’s runtime.

---

## 1. XCUITest fundamentals relevant to packaging

### 1.1 What lives where

| Layer | Owns | Primary source |
| --- | --- | --- |
| **App target** | Product code, accessibility attributes, reading `ProcessInfo` launch args / env, URL handling | [UIAccessibilityIdentification.accessibilityIdentifier](https://developer.apple.com/documentation/uikit/uiaccessibilityidentification/accessibilityidentifier); [ProcessInfo.arguments](https://developer.apple.com/documentation/foundation/processinfo/arguments) |
| **UI automation test target** | `XCTestCase` subclasses, `test…` methods, assertions, `XCUIApplication` launch + queries | [Defining Test Cases and Test Methods](https://developer.apple.com/documentation/xctest/defining-test-cases-and-test-methods); [Recording UI automation for testing](https://developer.apple.com/documentation/XCUIAutomation/recording-ui-automation-for-testing) |
| **Reusable package (library)** | Extensions/helpers on XCTest/XCUI\* types, page-object bases, launch helpers, shared matchers—**not** the consumer’s test methods or Target Application wiring | Precedent packages below (§4) |

Apple documents UI tests as: create a class subclassing `XCTestCase` **in the UI automation test target**, add methods whose names begin with `test`, then drive the UI with XCUIAutomation queries and XCTest assertions ([Recording UI automation for testing](https://developer.apple.com/documentation/XCUIAutomation/recording-ui-automation-for-testing); [Defining Test Cases and Test Methods](https://developer.apple.com/documentation/xctest/defining-test-cases-and-test-methods)).

[XCUIApplication](https://developer.apple.com/documentation/XCUIAutomation/XCUIApplication) is a **proxy** that launches, monitors, and terminates the test application. Default `init()` uses the Target Application configured in Xcode’s target settings; `init(bundleIdentifier:)` targets another installed app ([XCUIApplication](https://developer.apple.com/documentation/XCUIAutomation/XCUIApplication)).

### 1.2 XCTest vs XCUIAutomation vs Swift Testing

- [XCTest](https://developer.apple.com/documentation/xctest) is the framework for unit, performance, and UI tests; UI interaction is via **XCUIAutomation** ([XCTest overview](https://developer.apple.com/documentation/xctest)).
- Apple’s tip on XCTest: continue to use **XCTest for user interface tests** even when adopting Swift Testing for unit tests; do not mix the two frameworks’ APIs in the same test ([XCTest](https://developer.apple.com/documentation/xctest)).
- XCUIAutomation’s job: “control your app’s user interface and inspect its state”; write tests with XCTest that use XCUIAutomation ([XCUIAutomation](https://developer.apple.com/documentation/XCUIAutomation)).

### 1.3 Constraints: injection, entitlements, accessibility

- **Black-box / accessibility:** UI tests locate controls through the accessibility hierarchy (`XCUIElementQuery`, element type providers) ([XCUIAutomation](https://developer.apple.com/documentation/XCUIAutomation); [Recording UI automation…](https://developer.apple.com/documentation/XCUIAutomation/recording-ui-automation-for-testing)). Stable automation IDs should use `accessibilityIdentifier` rather than overloading accessibility labels ([accessibilityIdentifier](https://developer.apple.com/documentation/uikit/uiaccessibilityidentification/accessibilityidentifier)).
- **Separate process:** The UI test runner process hosts XCTest; the app under test is launched as a separate process via `XCUIApplication`. There is no Apple-documented path for a helper package to “inject” into the app binary the way an in-process unit-test host can (@testable import). White-box in-app access is outside stock XCUITest (EarlGrey 2 documents this and adds eDistantObject for white-box—see §4).
- **Launch configuration:** Tests set `launchArguments` / `launchEnvironment` **before** `launch()`; changes after launch apply only on the next launch ([launchArguments](https://developer.apple.com/documentation/XCUIAutomation/XCUIApplication/launchArguments); [launchEnvironment](https://developer.apple.com/documentation/XCUIAutomation/XCUIApplication/launchEnvironment)). Deep-link style entry uses `open(_:)` ([open(_:)](https://developer.apple.com/documentation/XCUIAutomation/XCUIApplication/open(_:))).
- **System apps / multi-app:** Recording docs note interaction with Settings, alerts, and multiple apps via additional `XCUIApplication` instances ([Recording UI automation…](https://developer.apple.com/documentation/XCUIAutomation/recording-ui-automation-for-testing)). Apple DTS has noted launch args/env are passed when **your** `XCUIApplication` is launched—not necessarily for extensions in the same way ([Apple Developer Forums — launch args on extensions](https://developer.apple.com/forums/thread/709952)).
- **visionOS:** UI testing is not available for apps built with the visionOS SDK; compatible iPhone/iPad apps run in visionOS can still be UI-tested when built with the iOS SDK ([XCUIAutomation](https://developer.apple.com/documentation/XCUIAutomation)).

### 1.4 Implications for a shared package

Anything that subclasses `XCTestCase` or touches `XCUIApplication` / `XCUIElement` must be compiled and linked in a context that can see XCTest/XCUIAutomation (the consumer’s **UI Tests** target). The package should not be linked into the **app** target, or the app will try to link XCTest (see §2).

---

## 2. How to ship a reusable Swift package for UI tests

### 2.1 SPM product shape

**Recommended:** one or more `.library` products. Real packages that ship XCUITest helpers do this without a special “UI test plugin” product type:

| Package | Product | Notes | Source |
| --- | --- | --- | --- |
| [A11yUITests](https://github.com/rwapp/A11yUITests) | `.library(name: "A11yUITests", …)` | Plain library; sources `import XCTest` | [Package.swift](https://raw.githubusercontent.com/rwapp/A11yUITests/master/Package.swift); [XCTestCase+A11y.swift](https://raw.githubusercontent.com/rwapp/A11yUITests/master/Sources/A11yUITests/Tests/XCTestCase%2BA11y.swift) |
| [XCUITestHelper](https://github.com/0xWDG/XCUITestHelper) | `.library(name: "XCUITestHelper", …)` | Extensions under `#if canImport(XCTest)` | [Package.swift](https://raw.githubusercontent.com/0xWDG/XCUITestHelper/main/Package.swift); [XCUIApplication.swift](https://raw.githubusercontent.com/0xWDG/XCUITestHelper/main/Sources/XCUITestHelper/XCUIApplication.swift) |
| [Hela](https://github.com/AsyncSwiftKits/Hela) | `.library(name: "Hela", …)` | Explicit `linkerSettings: [.linkedFramework("XCTest")]` | [Package.swift](https://raw.githubusercontent.com/AsyncSwiftKits/Hela/main/Package.swift) |
| [stream-chat-swift](https://github.com/GetStream/stream-chat-swift) | Separate `StreamChatTestTools` library product | Test tooling as its own product (pattern for “don’t ship test helpers with app libs”) | [Package.swift](https://raw.githubusercontent.com/GetStream/stream-chat-swift/develop/Package.swift) |

You do **not** need an SPM `.testTarget` to *distribute* helpers. `.testTarget` is for the package’s own tests ([PackageDescription / SPM docs](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs)). Consumers add the **library** product to their Xcode UI Test target ([Adding package dependencies to your app](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app)).

### 2.2 Linking XCTest from a package (known pitfalls)

**XCTest is not an SPM package dependency.** It lives under Xcode’s platform Developer libraries. Consequences documented in practice:

1. **Linker failures** when a package imports XCTest/`XCUI*` but the consuming link step cannot find XCTest (`Could not find or use auto-linked framework 'XCTest'`, `XCTestSwiftSupport`)—commonly when the package is accidentally linked to a non-test target ([Stack Overflow report of the failure mode](https://stackoverflow.com/questions/77199236/how-can-i-include-xctest-as-a-dependency-in-a-swift-spm-package); Apple Forums discussion of `ENABLE_TESTING_SEARCH_PATHS` for XCTest-using libraries ([How can I support XCTest extensions with a Swift package?](https://developer.apple.com/forums/thread/695555))).

2. **Accepted pattern (Apple Forums):**  
   - Add XCTest as a linked framework in `Package.swift` (`linkerSettings`).  
   - When adding the package in Xcode, **do not** leave the package linked to the primary app target; link it **only** to the test target that uses it ([forums thread 695555](https://developer.apple.com/forums/thread/695555)).

3. **SPM API:** `LinkerSetting.linkedFramework(_:_:)` “Declares linkage to a system framework” ([linkedFramework(_:_:)](https://developer.apple.com/documentation/packagedescription/linkersetting/linkedframework(_:_:))).

4. **Build setting workaround on the consumer:** `ENABLE_TESTING_SEARCH_PATHS = YES` (and related framework search paths) so XCTest can be resolved for testing-support modules ([forums 695555](https://developer.apple.com/forums/thread/695555); also cited in [tuist#5538](https://github.com/tuist/tuist/issues/5538) as the practical fix when generators omit XCTest linkage).

5. **Guarded imports:** Some packages wrap UI APIs in `#if canImport(XCTest)` ([XCUITestHelper XCUIApplication.swift](https://raw.githubusercontent.com/0xWDG/XCUITestHelper/main/Sources/XCUITestHelper/XCUIApplication.swift)) so non-Apple/tooling builds degrade gracefully—but consumers still need a real UI test target to *use* the APIs.

**Manifest sketch (aligned with Hela + Apple linkerSettings docs):**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "XQUITestKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "XQTestContracts", targets: ["XQTestContracts"]),
        .library(name: "XQUITestKit", targets: ["XQUITestKit"]),
    ],
    targets: [
        .target(name: "XQTestContracts"), // no XCTest
        .target(
            name: "XQUITestKit",
            dependencies: ["XQTestContracts"],
            linkerSettings: [.linkedFramework("XCTest")]
        ),
        .testTarget(name: "XQUITestKitTests", dependencies: ["XQUITestKit"]),
    ]
)
```

`swift-tools-version` should match the org’s minimum Xcode/Swift (5.9+ aligns with DeviceKit/xq-motest tooling notes in-repo). Platforms should declare `.iOS` (and others only if APIs are multiplatform).

### 2.3 Binary XCFramework

If source SPM is insufficient (IP, prebuilt closed helpers), Apple documents distributing binaries as Swift packages via XCFramework + `.binaryTarget` ([Distributing binary frameworks as Swift packages](https://developer.apple.com/documentation/xcode/distributing-binary-frameworks-as-swift-packages)). Trade-offs Apple calls out: less portable, Apple-platforms-only, checksum/hosting complexity. For an **internal** org helper library, **source SPM is the default**; binary is optional, not required for XCUITest helpers.

### 2.4 CocoaPods / Carthage (secondary)

- [A11yUITests](https://github.com/rwapp/A11yUITests) still publishes a podspec with `s.frameworks = 'XCTest'` ([A11yUITests.podspec](https://raw.githubusercontent.com/rwapp/A11yUITests/master/A11yUITests.podspec))—same “link XCTest, UI test only” idea.
- [EarlGrey 2.0](https://github.com/google/EarlGrey/tree/earlgrey2) documents Xcode project integration and CocoaPods for black-box testing; README states SPM/other package managers are not first-class (“Contributions are welcome for … other package managers”) ([EarlGrey 2 README](https://raw.githubusercontent.com/google/EarlGrey/earlgrey2/README.md)).
- For new XQ work, **SPM via Xcode package dependency** matches Apple’s current packaging path ([Adding package dependencies…](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app); [Publishing a Swift package with Xcode](https://developer.apple.com/documentation/xcode/publishing-a-swift-package-with-xcode)). Carthage is not needed for this design.

### 2.5 Distribution / versioning

Apple’s publish flow: Git repo + semantic version tags; consumers add by URL and version requirement ([Publishing a Swift package with Xcode](https://developer.apple.com/documentation/xcode/publishing-a-swift-package-with-xcode); [Adding package dependencies…](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app)). For CI, commit `Package.resolved` and consider `-disableAutomaticPackageResolution` ([Building Swift packages or apps that use them in continuous integration workflows](https://developer.apple.com/documentation/xcode/building-swift-packages-or-apps-that-use-them-in-continuous-integration-workflows)).

---

## 3. Consumer integration patterns

### 3.1 How an app team adds the package

Per Apple ([Adding package dependencies to your app](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app)):

1. **File → Add Package Dependency…** (or target General → Frameworks → Add Other → Add Package Dependency).
2. Enter the Git URL (public or private; private needs credentials in Xcode/CI).
3. Choose a **version** requirement (up to next major / range / exact)—prefer semver tags.
4. In the add-to-target sheet, select **only the UI Tests target** for `XQUITestKit` (and optionally the **app** target for `XQTestContracts` if that product is XCTest-free).
5. In a UI test file: `import XCTest` / `import XQUITestKit`, subclass `XCTestCase`, configure `XCUIApplication`, call helpers.

Confirm under the UI Test target’s **Frameworks and Libraries** that the package product is listed, and under the app target that the XCTest-linked product is **not**.

### 3.2 Recommended package layout (under `packages/`)

xq-qe-box already reserves `packages/` ([README](https://github.com/ExperienceQuality/xq-qe-box/blob/main/README.md); [Hub Spec: xq-qe-box](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/specs/xq-qe-box.md)). Suggested layout:

```
packages/
  XQUITestKit/                 # or xq-xcuitest/
    Package.swift
    README.md
    Sources/
      XQTestContracts/         # launch arg keys, accessibility ID constants, deep-link schemes
      XQUITestKit/             # XCUIApplication helpers, waits, page object base, matchers
    Tests/
      XQUITestKitTests/
    Examples/                  # optional sample app + UITests (like A11yUITests Example/)
```

Dual product rationale:

- **`XQTestContracts`:** Safe to link from the **app** (and document for agents). No `import XCTest`.
- **`XQUITestKit`:** Link from **UITests only**. Depends on contracts + XCTest/XCUIAutomation.

This mirrors Stream’s split of app libraries vs `StreamChatTestTools` ([Package.swift](https://raw.githubusercontent.com/GetStream/stream-chat-swift/develop/Package.swift)).

### 3.3 What the package should export vs keep in the consumer

| Export from package | Keep in consumer UITests / app |
| --- | --- |
| Wait / retry helpers on `XCUIElement` | Concrete `XCTestCase` subclasses and `test…` methods |
| Page-object **base** types (`struct Screen { let app: XCUIApplication }`) | App-specific screens and flows |
| Standard launch presets (locale, “UI testing” flag helpers) | Product bundle IDs, scheme/Target Application |
| Matchers / a11y audit wrappers calling `performAccessibilityAudit` if desired | Assertions about product business rules |
| Shared accessibility ID **string constants** (contracts) | Wiring those IDs in SwiftUI/UIKit views |
| Deep-link URL builders | URL scheme registration / routing in the app |

Apple’s recording guide expects assertions and queries to live in the test method after interactions ([Recording UI automation…](https://developer.apple.com/documentation/XCUIAutomation/recording-ui-automation-for-testing))—the package accelerates that; it does not replace the consumer test target.

### 3.4 Launch arguments, environment, deep links (testability contract)

**From the UI test (package helpers can encapsulate):**

```swift
let app = XCUIApplication()
app.launchArguments += ["-XQUITesting", "1"]
app.launchEnvironment["XQ_FIXTURE"] = "logged-out"
app.launch()
// or: app.open(URL(string: "myapp://settings")!)
```

Documented APIs: [launchArguments](https://developer.apple.com/documentation/XCUIAutomation/XCUIApplication/launchArguments), [launchEnvironment](https://developer.apple.com/documentation/XCUIAutomation/XCUIApplication/launchEnvironment), [open(_:)](https://developer.apple.com/documentation/XCUIAutomation/XCUIApplication/open(_:)).

**In the app:** read `ProcessInfo.processInfo.arguments` / environment ([ProcessInfo.arguments](https://developer.apple.com/documentation/foundation/processinfo/arguments)) to disable animations, seed state, or skip onboarding. Prefer a small, versioned flag vocabulary in `XQTestContracts` so UITests and agent tooling agree.

**Accessibility:** set `accessibilityIdentifier` on controls for stable queries ([accessibilityIdentifier](https://developer.apple.com/documentation/uikit/uiaccessibilityidentification/accessibilityidentifier)).

### 3.5 Sharing code between app and UI tests safely

| Approach | Safety | Notes |
| --- | --- | --- |
| Shared **string constants** / URL builders (`XQTestContracts`) | Safe | No XCTest; linkable from app + tests |
| Launch args / env / `open(URL)` | Safe | Cross-process contract ([XCUIApplication](https://developer.apple.com/documentation/XCUIAutomation/XCUIApplication)) |
| `@testable import App` from UITests | Generally **not** the UI-test model | UI tests are out-of-process; white-box needs other tech (e.g. EarlGrey eDO) ([EarlGrey 2 README](https://raw.githubusercontent.com/google/EarlGrey/earlgrey2/README.md)) |
| Linking XCTest helper into app | **Unsafe / broken** | Causes XCTest link into production target ([forums 695555](https://developer.apple.com/forums/thread/695555)) |

---

## 4. Industry / first-party precedents

### 4.1 Apple

- Frameworks: [XCTest](https://developer.apple.com/documentation/xctest), [XCUIAutomation](https://developer.apple.com/documentation/XCUIAutomation).
- How-to: [Recording UI automation for testing](https://developer.apple.com/documentation/XCUIAutomation/recording-ui-automation-for-testing), [Defining Test Cases and Test Methods](https://developer.apple.com/documentation/xctest/defining-test-cases-and-test-methods).
- Packaging: [Adding package dependencies…](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app), [Publishing a Swift package…](https://developer.apple.com/documentation/xcode/publishing-a-swift-package-with-xcode), [Distributing binary frameworks…](https://developer.apple.com/documentation/xcode/distributing-binary-frameworks-as-swift-packages), [CI + packages](https://developer.apple.com/documentation/xcode/building-swift-packages-or-apps-that-use-them-in-continuous-integration-workflows).
- Apple does **not** publish a first-party “modular UI test helpers” SPM package; modularization guidance for UI tests is implicit (test target + XCUIAutomation + accessibility), not a dedicated modularization guide found in current XCUIAutomation docs.
- Official forum guidance on XCTest-in-SPM: link XCTest in the package; link package only to test targets ([thread 695555](https://developer.apple.com/forums/thread/695555)).

### 4.2 Open-source packages (consumable patterns)

| Project | Distribution | Relevance |
| --- | --- | --- |
| [rwapp/A11yUITests](https://github.com/rwapp/A11yUITests) | SPM library + CocoaPods (`frameworks = XCTest`) | Accessibility assertions as `XCTestCase` extensions; Example UITests app |
| [0xWDG/XCUITestHelper](https://github.com/0xWDG/XCUITestHelper) | SPM library | Thin `XCUIApplication` / element helpers; `canImport(XCTest)` |
| [AsyncSwiftKits/Hela](https://github.com/AsyncSwiftKits/Hela) | SPM + `linkedFramework("XCTest")` | Explicit linker setting; documents not linking to app |
| [pointfreeco/swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) | SPM libraries | Shows mature multi-product SPM for test tooling (snapshot ≠ XCUITest, same “test library” packaging) ([Package.swift](https://raw.githubusercontent.com/pointfreeco/swift-snapshot-testing/main/Package.swift)) |
| [GetStream/stream-chat-swift](https://github.com/GetStream/stream-chat-swift) | Separate `*TestTools` products | Org-scale pattern: test helpers as distinct products |
| [google/EarlGrey](https://github.com/google/EarlGrey) `earlgrey2` | Xcode / CocoaPods on XCUITest | Proves UI Testing **target** is the integration surface; white-box needs eDO; **not** SPM-first ([README](https://raw.githubusercontent.com/google/EarlGrey/earlgrey2/README.md)) |

EarlGrey 2 explicitly: “uses a UI Testing Target and not a Unit Testing Target”; built on XCUITest ([README](https://raw.githubusercontent.com/google/EarlGrey/earlgrey2/README.md)). That reinforces packaging helpers as libraries consumed by UI Testing targets—not replacing that target.

---

## 5. Fit with DeviceKit / xq-motest

### 5.1 Two different consumption models

| | Classic XCUITest package | DeviceKit + xq-motest |
| --- | --- | --- |
| **Where code runs** | Consumer app’s UITests bundle (XCTest host) | DeviceKit’s own `DeviceKitTests` XCUITest runner ([devicekit-ios Architecture](https://github.com/mobile-next/devicekit-ios)) |
| **How tests are authored** | Swift `XCTestCase` in app repo | Agent/CLI JSON-RPC (`map` / `tap` / …) ([xq-motest README](../../cli/xq-motest/README.md)) |
| **Dependency mechanism** | SPM library linked into UITests | Preinstalled runner `.app`/`.ipa`; CLI does not install ([ADR-0001](../adr/0001-cli-assumes-devicekit-preinstalled.md); [Hub Spec](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/specs/xq-qe-box.md)) |
| **App coupling** | Target Application + accessibility | Launch by bundle ID over RPC; UI dump via accessibility tree |

DeviceKit “runs as an XCUITest” and exposes JSON-RPC on localhost ([devicekit-ios README](https://raw.githubusercontent.com/mobile-next/devicekit-ios/main/README.md)). `xq-motest` writes `.xctestrun` metadata and talks Session traffic to that runner ([XCTestRun.swift](../../cli/xq-motest/swift/Sources/Motest/XCTestRun.swift); CONTEXT.md).

### 5.2 Can one package under `packages/` serve both?

**Partially—contracts yes; XCTest helpers no (as a shared runtime).**

| Shared layer | Both paths? | Constraint from sources |
| --- | --- | --- |
| Accessibility ID vocabulary, launch-arg keys, deep-link schemes (`XQTestContracts`) | **Yes** | Cross-process; no XCTest link ([accessibilityIdentifier](https://developer.apple.com/documentation/uikit/uiaccessibilityidentification/accessibilityidentifier); launch APIs above) |
| Swift page objects / `XCUIElement` extensions (`XQUITestKit`) | **Human UITests only** | Must link into a UI Test target with XCTest ([forums 695555](https://developer.apple.com/forums/thread/695555)); DeviceKit runner is a **different** XCUITest host/binary and does not load the consumer’s SPM product |
| DeviceKit JSON-RPC client / runner packaging | **Agent path only** | Runner install owned by infra ([ADR-0001](../adr/0001-cli-assumes-devicekit-preinstalled.md)); Hub Spec keeps `packages/` reserved and out-of-scope for DeviceKit install scripts |

**Recommendation:** keep **XQUITestKit** and **DeviceKit/xq-motest** as separate products that optionally share **XQTestContracts**. Do not try to make DeviceKit “depend on” the UI helper library for its on-device runtime—the runner is already an XCUITest app with its own target graph ([devicekit-ios Architecture](https://github.com/mobile-next/devicekit-ios)).

---

## 6. Concrete recommendation skeleton

### 6.1 Name / layout

- Path: `packages/XQUITestKit/` (module names: `XQTestContracts`, `XQUITestKit`).
- Aligns with reserved `packages/` in [README](https://github.com/ExperienceQuality/xq-qe-box/blob/main/README.md) / [Hub Spec](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/specs/xq-qe-box.md).

### 6.2 Minimum viable API surface

**`XQTestContracts`**

- `enum XQLaunchFlag` / string constants (`xq.uitesting`, fixture keys).
- `enum XQAccessibilityID` (or namespaced structs per feature) for shared identifiers.
- Optional `XQDeepLink` URL builders.

**`XQUITestKit`**

- `XCUIApplication` launch helper applying contracts (args/env).
- Wait helpers (`waitForExistence`-style wrappers) and failure messages.
- Lightweight page-object base holding `XCUIApplication`.
- Optional wrappers around [performAccessibilityAudit](https://developer.apple.com/documentation/XCUIAutomation/XCUIApplication/performAccessibilityAudit(for:_:)) if org standardizes a11y gates.

Defer: full page-object DSL, screenshot diff engine, network stubbing (separate packages if needed).

### 6.3 Distribution

1. Implement package in `packages/XQUITestKit` inside `xq-qe-box` **or** extract to `ExperienceQuality/xq-xcuitest` if consumer apps should not depend on the whole QE monorepo.
2. Tag semver (`1.0.0`) per [Publishing a Swift package with Xcode](https://developer.apple.com/documentation/xcode/publishing-a-swift-package-with-xcode).
3. Consumers: `https://github.com/ExperienceQuality/xq-qe-box` with SPM path to `packages/XQUITestKit` **if** using a monorepo path dependency—or a dedicated repo URL for cleaner versioning.
   - Note: SPM supports path-based local packages and git URLs; monorepo-subdirectory consumption may require a dedicated package repo or documented local `path:` for early adopters—validate with the org’s Xcode version before promising “git URL of monorepo + subfolder” as the only channel.
4. CI: commit `Package.resolved`; private Git auth for Xcode Cloud / `xcodebuild` per Apple CI package docs.

### 6.4 Consumer checklist (Xcode)

1. Add UI Testing Bundle if missing (Target Application = app).
2. Add package dependency (versioned).
3. Link **`XQUITestKit` → UITests only**; link **`XQTestContracts` → App (+ UITests)** as needed.
4. Verify app target does **not** link `XQUITestKit`.
5. If link errors for XCTest: confirm UI Test target (not app); set `ENABLE_TESTING_SEARCH_PATHS=YES` on the UI Test target if required ([forums 695555](https://developer.apple.com/forums/thread/695555)).
6. Apply `accessibilityIdentifier`s from contracts in app UI.
7. In `setUp`, use package launch helper; write `test…` methods.
8. Run via Test navigator / `xcodebuild test`; keep `Package.resolved` committed for CI.

### 6.5 Open risks / Apple limitations (blockers for “drop-in”)

1. **XCTest is not a portable SPM dependency** — packages that import it are effectively Apple-platform / Xcode-linked; linux `swift test` of those targets is a non-goal ([linkedFramework](https://developer.apple.com/documentation/packagedescription/linkersetting/linkedframework(_:_:)); forums pitfalls).
2. **Wrong target linkage breaks app builds** — Xcode’s default “add package to project” can attach the library to the app; must be corrected ([forums 695555](https://developer.apple.com/forums/thread/695555)).
3. **Black-box only** — no supported in-process hooks from UITests; testability is accessibility + launch contracts ([XCUIAutomation](https://developer.apple.com/documentation/XCUIAutomation)).
4. **Not a substitute for DeviceKit** — agents still need the runner + `xq-motest`; the package does not install or replace DeviceKit ([ADR-0001](../adr/0001-cli-assumes-devicekit-preinstalled.md)).
5. **Swift Testing ≠ UI testing** — UI tests remain on XCTest ([XCTest tip](https://developer.apple.com/documentation/xctest)).
6. **Monorepo SPM UX** — shipping from `packages/` inside a large satellite may push consumers toward a dedicated git repo for clean version tags (operational, not an Apple API ban).
7. **Binary/IP** — only needed if source distribution is unacceptable; brings XCFramework overhead ([binary frameworks doc](https://developer.apple.com/documentation/xcode/distributing-binary-frameworks-as-swift-packages)).

---

## Recommended next steps for xq-qe-box

1. **Spike** `packages/XQUITestKit` with the dual-product `Package.swift` above; consume from a sample app UITests target (link-matrix: UITests OK / App+XQUITestKit must fail loudly in docs).
2. **Extract `XQTestContracts`** first if product Satellites need shared accessibility IDs for both UITests and DeviceKit `map`/`tap` flows—this is the only layer both stacks can share without fighting XCTest linkage.
3. **Decide distribution repo** (monorepo subpackage vs `ExperienceQuality/xq-xcuitest`) before tagging `1.0.0`.
4. **Do not** merge DeviceKit runner packaging into this SPM library; keep ADR-0001 boundary (infra owns runner; CLI owns Session).
5. **Hub follow-up:** if this becomes a Ticket, extend [xq-qe-box Spec](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/specs/xq-qe-box.md) “Out of scope / Tracer-bullet” to mention the UITest kit explicitly (today `packages/` is only “reserved”).
6. **Optional later:** Example app under `packages/XQUITestKit/Examples` mirroring A11yUITests’ Example UITests layout.

---

## Sources

- [XCTest (Apple)](https://developer.apple.com/documentation/xctest)
- [XCUIAutomation (Apple)](https://developer.apple.com/documentation/XCUIAutomation)
- [XCUIApplication (Apple)](https://developer.apple.com/documentation/XCUIAutomation/XCUIApplication)
- [launchArguments](https://developer.apple.com/documentation/XCUIAutomation/XCUIApplication/launchArguments) · [launchEnvironment](https://developer.apple.com/documentation/XCUIAutomation/XCUIApplication/launchEnvironment) · [open(_:)](https://developer.apple.com/documentation/XCUIAutomation/XCUIApplication/open(_:))
- [Recording UI automation for testing](https://developer.apple.com/documentation/XCUIAutomation/recording-ui-automation-for-testing)
- [Defining Test Cases and Test Methods](https://developer.apple.com/documentation/xctest/defining-test-cases-and-test-methods)
- [accessibilityIdentifier (UIKit)](https://developer.apple.com/documentation/uikit/uiaccessibilityidentification/accessibilityidentifier)
- [ProcessInfo.arguments](https://developer.apple.com/documentation/foundation/processinfo/arguments)
- [Adding package dependencies to your app](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app)
- [Publishing a Swift package with Xcode](https://developer.apple.com/documentation/xcode/publishing-a-swift-package-with-xcode)
- [Distributing binary frameworks as Swift packages](https://developer.apple.com/documentation/xcode/distributing-binary-frameworks-as-swift-packages)
- [Building Swift packages… in CI](https://developer.apple.com/documentation/xcode/building-swift-packages-or-apps-that-use-them-in-continuous-integration-workflows)
- [LinkerSetting.linkedFramework](https://developer.apple.com/documentation/packagedescription/linkersetting/linkedframework(_:_:))
- [Apple Forums: XCTest extensions with a Swift package](https://developer.apple.com/forums/thread/695555)
- [Apple Forums: launch args on extensions](https://developer.apple.com/forums/thread/709952)
- [A11yUITests Package.swift](https://raw.githubusercontent.com/rwapp/A11yUITests/master/Package.swift) · [podspec](https://raw.githubusercontent.com/rwapp/A11yUITests/master/A11yUITests.podspec)
- [XCUITestHelper Package.swift](https://raw.githubusercontent.com/0xWDG/XCUITestHelper/main/Package.swift) · [XCUIApplication.swift](https://raw.githubusercontent.com/0xWDG/XCUITestHelper/main/Sources/XCUITestHelper/XCUIApplication.swift)
- [Hela Package.swift](https://raw.githubusercontent.com/AsyncSwiftKits/Hela/main/Package.swift)
- [swift-snapshot-testing Package.swift](https://raw.githubusercontent.com/pointfreeco/swift-snapshot-testing/main/Package.swift)
- [stream-chat-swift Package.swift](https://raw.githubusercontent.com/GetStream/stream-chat-swift/develop/Package.swift)
- [EarlGrey 2.0 README](https://raw.githubusercontent.com/google/EarlGrey/earlgrey2/README.md)
- [devicekit-ios README](https://raw.githubusercontent.com/mobile-next/devicekit-ios/main/README.md)
- [Hub Spec: xq-qe-box](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/specs/xq-qe-box.md)
- In-repo: [README.md](../../README.md), [ADR-0001](../adr/0001-cli-assumes-devicekit-preinstalled.md), [cli/xq-motest/README.md](../../cli/xq-motest/README.md), [XCTestRun.swift](../../cli/xq-motest/swift/Sources/Motest/XCTestRun.swift)
