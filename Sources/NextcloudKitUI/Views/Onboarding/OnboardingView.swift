// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// A full screen view introducing a list of features, with a single button at the bottom to continue.
///
public struct OnboardingView: View {
    let title: String
    let features: [OnboardingFeature]
    let buttonTitle: String?
    let tint: Color
    let continueHandler: () -> Void

    ///
    /// Create a new onboarding view.
    ///
    /// - Parameters:
    ///     - title: The large title on top of the screen.
    ///     - features: The rows listed below the title.
    ///     - buttonTitle: The label of the bottom button. Defaults to "Continue".
    ///     - tint: The color of the feature icons and the button.
    ///     - continueHandler: Called when the user taps the button.
    ///
    public init(title: String, features: [OnboardingFeature], buttonTitle: String? = nil, tint: Color = .accentColor, continueHandler: @escaping () -> Void) {
        self.title = title
        self.features = features
        self.buttonTitle = buttonTitle
        self.tint = tint
        self.continueHandler = continueHandler
    }

    // MARK: - Environment

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 44

    // MARK: - Implementation

    ///
    /// Rows stack vertically at accessibility sizes so words don't break mid-word.
    ///
    private var rowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 16))
    }

    private var horizontalPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 20 : 40
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                        .padding(.bottom, 20)

                    ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                        rowLayout {
                            feature.icon
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(tint)
                                .frame(width: iconSize, height: iconSize)
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
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, horizontalPadding)
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
}

#if DEBUG

#Preview {
    OnboardingView(
        title: "What's New",
        features: [
            OnboardingFeature(icon: Image(systemName: "heart.fill"), title: "More Personalized", description: "Top stories picked for you."),
            OnboardingFeature(icon: Image(systemName: "star.fill"), title: "New Spotlight Tab", description: "Discover great stories selected by our editors."),
            OnboardingFeature(icon: Image(systemName: "play.rectangle.fill"), title: "Title Only")
        ]
    ) {
        print("Continue!")
    }
}

#endif
