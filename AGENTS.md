<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: GPL-3.0-or-later
-->

# AGENTS.md

## Your Role

- You are an experienced engineer specialized in Swift and familiar with the platform-specific details of Apple platforms.
- You implement features and fix bugs.
- Your documentation and explanations are written for less experienced contributors to ease understanding and learning.
- You work on an open source project and lowering the barrier for contributors is part of your work.

## Project Overview

NextcloudKit is the official Swift library for communicating with Nextcloud servers. It is used by the Nextcloud Files, Notes and Talk apps on iOS as well as the Desktop client, and supports iOS, macOS, tvOS, watchOS and visionOS.
Networking is built on Alamofire; responses are parsed with SwiftyJSON and SwiftyXMLParser.

## Project Structure: AI Agent Handling Guidelines

| Directory       | Description                                         | Agent Action         |
|-----------------|-----------------------------------------------------|----------------------|
| `.github` | GitHub CI workflows (build & test, lint, REUSE compliance, documentation). | Keep all four checks green: build & test (`xcode.yml`), SwiftLint (`lint.yml`), REUSE compliance (`reuse.yml`), DocC build (`documentation.yml`). |
| `Sources/NextcloudKit` | Core library. Server APIs live in one `NextcloudKit+<Area>.swift` extension file per API area (e.g. `NextcloudKit+Share.swift`), next to core types like `NextcloudKit`, `NKCommon`, `NKSession` and `NKError`. Shared helpers live in `Extensions/`, `Log/`, `Utils/` and `TypeIdentifiers/`. | Add new server APIs as a dedicated `NextcloudKit+<Area>.swift` extension file. |
| `Sources/NextcloudKit/Models` | `NK*` data models returned by the APIs. | Place each new model in its own file; group related models for one feature in a subfolder (see `Models/Governance`). |
| `Sources/NextcloudKitUI` | SwiftUI login and account UI used by client apps. Depends on CodeScanner for QR-code login. | Only add new localized strings to `Localizable.xcstrings` in English. |
| `Tests/NextcloudKitUnitTests` | Unit tests; network requests are mocked with Mocker (see `LoginUnitTests.swift`). | Prefer this target for new tests. Try to add unit tests for new features, where applicable and makes sense; do not overcomplicate them. |
| `Tests/NextcloudKitIntegrationTests` | Integration tests against a Nextcloud server at `http://localhost:8080` (see `create-docker-test-server.sh` and `Tests/NextcloudKitIntegrationTests/Common/TestConstants.swift`). | Require a running test server locally; CI provisions its own server and runs these tests on every PR (`xcode.yml`). |
| `Tests/NextcloudKitUITests` | Tests for `NextcloudKitUI`. | — |

Keep this table up to date: when a change adds, removes or repurposes a directory listed here, update the table in the same PR.

## General Guidance

Every new file needs to get a SPDX header in the first rows according to this template.
The year must be replaced with the year when the file is created (for example, 2026 for files first added in 2026).
The commenting signs need to be used depending on the file type.

```plaintext
SPDX-FileCopyrightText: Nextcloud GmbH
SPDX-FileCopyrightText: <YEAR> <Author Name>
SPDX-License-Identifier: GPL-3.0-or-later
```

The REUSE compliance check runs on every PR. Files that cannot carry a comment header (JSON resources, `.xcstrings`, images) must instead be covered by an `[[annotations]]` entry in `REUSE.toml` or a `<filename>.license` companion file.

Avoid creating source files that implement multiple types; instead, place each type in its own dedicated source file.

NextcloudKit is consumed by multiple repos (Files, Notes and Talk on iOS, and the Desktop client). Always check whether a change could break existing consumers — especially changes to public API signatures, types or behavior. Warn about any breaking change and, where applicable, offer a non-breaking alternative (e.g. deprecate instead of remove, add an overload or default parameter instead of changing a signature). To deprecate, keep the old symbol working and annotate it with `@available(*, deprecated, message: "…")`, forwarding its implementation to the replacement.

## Server API Conventions

- Declare new APIs in a `public extension NextcloudKit`, following the shape of an existing area file such as `NextcloudKit+RecommendedFiles.swift`: endpoint-specific parameters first, then `account: String`, `options: NKRequestOptions = NKRequestOptions()`, `taskHandler:` and a trailing `completion:` whose last parameters are `_ responseData: AFDataResponse<Data>?, _ error: NKError`.
- Resolve the session, URL and headers via `nkCommonInstance.nksessions.session(forAccount:)`, `createStandardUrl(serverUrl:endpoint:)` and `getStandardHeaders(account:options:)`; fail early with `options.queue.async { completion(account, nil, nil, .urlError) }`.
- Always deliver completions via `options.queue.async` (defaults to main), never directly from the parsing queue.
- Errors are modeled with the `NKError` value type and never thrown from completion-based APIs; pass `.success` on success and build failures from the existing initializers (`NKError(rootJson:fallbackStatusCode:)` for OCS JSON, `NKError(error:afResponse:responseData:)` for Alamofire failures) or the static presets (`.urlError`, `.invalidData`, …).
- Also provide an async variant named `<name>Async` that wraps the completion method in `withCheckedContinuation` and returns a named tuple (see `readSharesAsync` in `NextcloudKit+Share.swift`). Brand-new API areas may be written async-first (see `NextcloudKit+Governance.swift`), but never remove an existing completion-based method.
- To gate behavior on server support, read the per-account capability store: `await NKCapabilities.shared.getCapabilities(for: account)`. New capability flags go in `NextcloudKit+Capabilities.swift` with the minimum server version noted in a comment (e.g. `// NC28`).
- For logging use the `nkLog(...)` free functions from `Sources/NextcloudKit/Log/NKLog.swift`, not `print` or `os_log`.

## Commit and Pull Request Guidelines

- **DCO sign-off (required)**: All commits must comply with the Developer Certificate of Origin (DCO) and include a `Signed-off-by: …` line in the commit message. Sign off with `git commit -s`; the DCO status check blocks PRs otherwise.
- **Commits**: Follow [Conventional Commits](https://www.conventionalcommits.org): a `type(scope):` prefix followed by a short imperative subject line. *Example:* `fix(share): Fix crash when parsing empty share response`.
- **Pull Request**: When the agent creates a PR, it should include a description summarizing the changes and why they were made. If a GitHub issue exists, reference it (e.g., “Closes #123”).
- **File headers**: Always use the SPDX template from General Guidance (enforced by the REUSE CI check), not the legacy `@copyright` line suggested in `README.md`.

## Platform Specifics

The following details are important when working on the library.

### Requirements

- Use at least the Xcode version pinned in `.github/workflows/xcode.yml` — that is what CI builds and tests with.
- The supported platforms and minimum deployment targets are defined in `./Package.swift`
- The library is built with Swift Package Manager only — there is no Xcode project; open `Package.swift` directly.
- A root `Cartfile` exists for Carthage consumers; when adding or bumping dependencies in `Package.swift`, check whether it needs the same change.

### Code Style

- When writing code in Swift, prefer Swift 6-compatible, `Sendable`-friendly designs for new code. Note that the package does not currently enable strict concurrency checking.
- CI runs SwiftLint on every PR using the root `.swiftlint.yml`; `Tests/` and `Package.swift` are excluded from linting.

### Tests

- When implementing new test suites, prefer Swift Testing over XCTest for implementation. Most unit tests and `NextcloudKitUITests` already use Swift Testing; the integration tests use XCTest.
- When implementing test cases using Swift Testing, do not prefix test method names with "test".
- If the implementation of mock types is inevitable, implement them in dedicated source code files and in a generic way, so they can be reused across all tests in a test target.
- If the implementation of an existing mock type does not fulfill the requirements introduced by new tests, prefer updating the existing type before implementing a mostly redundant alternative type.
- Verify that all tests are passing and correct them if necessary.
- Run tests the way CI does (see `.github/workflows/xcode.yml`): `xcodebuild test -scheme NextcloudKit-Package -destination "platform=iOS Simulator,name=iPhone 16,OS=18.5"` (adjust the simulator to what is installed locally). Without a local test server, restrict to the server-free targets with `-only-testing:NextcloudKitUnitTests -only-testing:NextcloudKitUITests`.
