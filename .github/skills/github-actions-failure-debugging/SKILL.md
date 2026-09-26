---
# SPDX-FileCopyrightText: Nextcloud GmbH
# SPDX-FileCopyrightText: 2026 Milen Pivchev
# SPDX-License-Identifier: GPL-3.0-or-later
name: github-actions-failure-debugging
description: Debug and fix failing GitHub Actions workflows (CI) in this repo — failing PR checks, xcodebuild/simulator/runner-image errors, SwiftLint failures. Use when asked to review, debug, or fix CI or a failing workflow run.
---

# Debugging failing GitHub Actions workflows

Workflows live in `.github/workflows/`:

- `xcode.yml` — builds and tests the `NextcloudKit-Package` scheme on a simulator against a Nextcloud server installed on the runner. Version pins are env vars at the top: `DESTINATION_IOS`, plus the `runs-on` label and the `xcode-version` passed to `maxim-lobanov/setup-xcode` further down.
- `lint.yml` — SwiftLint on ubuntu.
- `documentation.yml` — builds the DocC documentation.
- `reuse.yml` — REUSE compliance check; provided by the org template repository, keep in sync with `nextcloud/.github`.

## 1. Get the failure

Use the `gh` CLI (if a GitHub MCP server is connected, its equivalents like `list_workflow_runs` / `get_job_logs` work too):

- `gh pr checks <pr>` or `gh run list --workflow "Build and test" --limit 10` — find failing runs
- `gh run view <run-id>` — see which jobs and steps failed
- `gh run view --job <job-id> --log-failed | grep -iE "error:|failed" | head -60` — never dump full logs into context; grep/tail them, or have a subagent read them and report only the failing step and error lines.

## 2. Classify before fixing

- "Unable to find a device matching the provided destination specifier" → the pinned `DESTINATION_IOS` device or OS does not exist on the runner image. The log prints the available destinations right below the error; if only placeholders (`Any iOS Simulator Device`) are listed, no simulator runtime is installed for the selected Xcode.
- `cannot find type '…' in scope` for Apple APIs → SDK mismatch: the code uses APIs newer than the SDK of the Xcode selected on the runner. Confirm the API's introduction version by grepping the local SDK, e.g.
  `grep -rn -B4 "TypeName" /Applications/Xcode-*.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/<Framework>.framework/Modules/*.swiftmodule/*.swiftinterface`
  and look for `@available(iOS X.0, …)`.
- Job queued forever or tooling missing → invalid or stale `runs-on` label.
- Test failures around PHP/occ → the "Set up Nextcloud" step; those shell steps can be reproduced locally.
- SwiftLint failures → run `swiftlint` locally.

## 3. Check runner-image compatibility

A green run that starts failing with no code change usually means the runner image was updated. Compare the timestamp of the last successful run with the failing one — if they straddle an image rollout, the pins are stale rather than the code being wrong.

Before changing any pin, check https://github.com/actions/runner-images:

- The README's Available Images table has the valid `runs-on` labels, including preview images (e.g. `xcode-27`) and deprecation notices.
- Each macOS image readme (`images/macos/<image>-arm64-Readme.md`) lists installed Xcode versions, iOS simulator runtimes, and device types.

The chosen combination must exist together on one image: `runs-on` label ↔ `xcode-version` ↔ `DESTINATION_IOS` OS + device. New Xcode majors appear first on a dedicated preview image before reaching the GA `macos-NN` image.

`nextcloud/ios` pins the same trio in its own `.github/workflows/xcode.yml` and is usually migrated first, so a combination that is currently green there is a safe target to copy.

## 4. Reproduce and fix

- This is a Swift package, so `swift build` / `swift test` are cheap — reproduce locally where you can. A full `xcodebuild test` still needs the Nextcloud server from the "Set up Nextcloud" step to be running on `localhost:8080`.
- Apply the fix to every workflow sharing the stale value.
- Validate edited YAML: `ruby -ryaml -e 'YAML.load_file(".github/workflows/xcode.yml")'`
- If you reproduced a failure locally, verify the fix locally before committing. Otherwise say plainly that verification needs a CI run; after pushing, watch it with `gh pr checks --watch` or `gh run watch`.
