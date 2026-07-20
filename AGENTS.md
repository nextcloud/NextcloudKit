<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: GPL-3.0-or-later
-->

# AGENTS.md

You are an experienced engineer specialized in Swift and familiar with the platform-specific details of Apple platforms.

## Your Role

- You implement features and fix bugs.
- Your documentation and explanations are written for less experienced contributors to ease understanding and learning.
- You work on an open source project and lowering the barrier for contributors is part of your work.

## Project Overview

NextcloudKit is the official Swift library for communicating with Nextcloud servers. It is used by the Nextcloud Files, Notes and Talk apps on iOS as well as the Desktop client, and supports iOS, macOS, tvOS, watchOS and visionOS.
Networking is built on Alamofire; responses are parsed with SwiftyJSON and SwiftyXMLParser.

## Project Structure: AI Agent Handling Guidelines

| Directory       | Description                                         | Agent Action         |
|-----------------|-----------------------------------------------------|----------------------|
| `.github` | GitHub CI workflows (build & test, lint, REUSE compliance, documentation). | Try to add unit tests for new features, where applicable and makes sense. Do not overcomplicate unit tests. |
| `Sources/NextcloudKit` | Core library. Server APIs live in one `NextcloudKit+<Area>.swift` extension file per API area (e.g. `NextcloudKit+Share.swift`), next to core types like `NextcloudKit`, `NKCommon`, `NKSession` and `NKError`. | Add new server APIs as a dedicated `NextcloudKit+<Area>.swift` extension file. |
| `Sources/NextcloudKit/Models` | `NK*` data models returned by the APIs. | Place each new model in its own file. |
| `Sources/NextcloudKitUI` | SwiftUI login and account UI used by client apps. | Only add new localized strings to `Localizable.xcstrings` in English. |
| `Tests/NextcloudKitUnitTests` | Unit tests; network requests are mocked with Mocker. | Prefer this target for new tests. |
| `Tests/NextcloudKitIntegrationTests` | Integration tests against a local Nextcloud test server (see `create-docker-test-server.sh` and `Tests/NextcloudKitIntegrationTests/Common/TestConstants.swift`). | Require a running test server; do not enable them in CI-only changes. |
| `Tests/NextcloudKitUITests` | Tests for `NextcloudKitUI`. | — |

## General Guidance

Every new file needs to get a SPDX header in the first rows according to this template.
The year must be replaced with the year when the file is created (for example, 2026 for files first added in 2026).
The commenting signs need to be used depending on the file type.

```plaintext
SPDX-FileCopyrightText: Nextcloud GmbH
SPDX-FileCopyrightText: <YEAR> <Author Name>
SPDX-License-Identifier: GPL-3.0-or-later
```

Avoid creating source files that implement multiple types; instead, place each type in its own dedicated source file.

NextcloudKit is consumed by multiple repos (Files, Notes and Talk on iOS, and the Desktop client). Always check whether a change could break existing consumers — especially changes to public API signatures, types or behavior. Warn about any breaking change and, where applicable, offer a non-breaking alternative (e.g. deprecate instead of remove, add an overload or default parameter instead of changing a signature).

## Commit and Pull Request Guidelines

- **DCO sign-off (required)**: All commits must comply with the Developer Certificate of Origin (DCO) and include a `Signed-off-by: …` line in the commit message.
- **Commits**: Use a short imperative subject line summarizing what changed. *Example:* `Fix crash when parsing empty share response`.
- **Pull Request**: When the agent creates a PR, it should include a description summarizing the changes and why they were made. If a GitHub issue exists, reference it (e.g., “Closes #123”). If there is any discrepancy between this section and the contribution guidance in `README.md`, the rules in `README.md` take precedence.

## Platform Specifics

The following details are important when working on the library.

### Requirements

- Latest stable Xcode available is required to be installed in the development environment.
- The library targets iOS 17, macOS 11, tvOS 14, watchOS 7 and visionOS 1 (see `Package.swift`).

### Code Style

- When writing code in Swift, prefer Swift 6-compatible, `Sendable`-friendly designs for new code. Note that the package does not currently enable strict concurrency checking.

### Tests

- When implementing new test suites, prefer Swift Testing over XCTest for implementation. Most unit tests and `NextcloudKitUITests` already use Swift Testing; the integration tests use XCTest.
- When implementing test cases using Swift Testing, do not prefix test method names with "test".
- If the implementation of mock types is inevitable, implement them in dedicated source code files and in a generic way, so they can be reused across all tests in a test target.
- If the implementation of an existing mock type does not fulfill the requirements introduced by new tests, prefer updating the existing type before implementing a mostly redundant alternative type.
- Verify that all tests are passing and correct them if necessary.
