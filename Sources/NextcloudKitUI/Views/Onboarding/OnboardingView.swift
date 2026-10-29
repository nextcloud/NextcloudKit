// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// A full screen view introducing a list of features, with a single button at the bottom to continue.
///
public struct OnboardingView: View {
    let icon: Image?
    let title: String
    let features: [OnboardingFeature]
    let buttonTitle: String?
    let tint: Color
    let continueHandler: () -> Void

    ///
    /// Create a new onboarding view.
    ///
    /// - Parameters:
    ///     - icon: The image above the title, clipped to a rounded square. Defaults to the app's own icon; `nil` hides it.
    ///     - title: The large title on top of the screen.
    ///     - features: The rows listed below the title.
    ///     - buttonTitle: The label of the bottom button. Defaults to "Continue".
    ///     - tint: The color of the icons and the button.
    ///     - continueHandler: Called when the user taps the button.
    ///
    public init(icon: Image? = .appIcon, title: String, features: [OnboardingFeature], buttonTitle: String? = nil, tint: Color = .accentColor, continueHandler: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.features = features
        self.buttonTitle = buttonTitle
        self.tint = tint
        self.continueHandler = continueHandler
    }

    // MARK: - Environment

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 64

    @ScaledMetric(relativeTo: .headline) private var featureIconSize: CGFloat = 44

    // MARK: - Implementation

    ///
    /// Rows stack vertically at accessibility sizes so words don't break mid-word.
    ///
    private var rowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
    }

    private var horizontalPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 20 : 28
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let icon {
                        icon
                            .resizable()
                            .scaledToFill()
                            .frame(width: iconSize, height: iconSize)
                            .clipShape(.rect(cornerRadius: iconSize * 0.225, style: .continuous))
                            .accessibilityHidden(true)
                            .padding(.bottom, 20)
                    }

                    Text(title)
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 32)

                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                            featureRow(feature)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 60)
                .padding(.bottom, 20)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            Button(action: continueHandler) {
                Group {
                    if let buttonTitle {
                        Text(buttonTitle)
                    } else {
                        Text("Continue", bundle: .module, comment: "Button label to leave the onboarding screen.")
                    }
                }
                .font(.headline)
                .foregroundStyle(tint.readable)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(tint)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical)
            .frame(maxWidth: 520)
        }
    }

    private func featureRow(_ feature: OnboardingFeature) -> some View {
        rowLayout {
            // Sized as a font so every symbol keeps the same optical size and stroke weight.
            feature.icon
                .font(.system(size: featureIconSize * 0.4, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: featureIconSize, height: featureIconSize)
                .background(tint.opacity(0.12), in: .rect(cornerRadius: featureIconSize * 0.25, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.headline)

                if let description = feature.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG

#Preview {
    OnboardingView(
        title: "What's New",
        features: [
            OnboardingFeature(icon: Image(systemName: "heart"), title: "More Personalized", description: "Top stories picked for you."),
            OnboardingFeature(icon: Image(systemName: "star"), title: "New Spotlight Tab", description: "Discover great stories selected by our editors."),
            OnboardingFeature(icon: Image(systemName: "play.rectangle"), title: "Title Only")
        ]
    ) {
        print("Continue!")
    }
}

#endif
