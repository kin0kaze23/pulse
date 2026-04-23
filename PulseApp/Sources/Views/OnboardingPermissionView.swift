//
//  OnboardingPermissionView.swift
//  Pulse
//
//  First-run onboarding flow explaining why Pulse needs permissions
//  Non-blocking, dismissable, shows feature impact clearly
//

import SwiftUI

/// First-run onboarding for permissions
struct OnboardingPermissionView: View {
    @StateObject private var permissionsService = PermissionsService.shared
    @ObservedObject var settings = AppSettings.shared
    @State private var currentStep = 0
    @State private var isDismissing = false
    @Environment(\.openWindow) private var openWindow

    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // Allow dismissing by clicking backdrop
                    dismiss()
                }

            // Onboarding card
            VStack(spacing: 0) {
                onboardingContent
            }
            .frame(maxWidth: 520)
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(DesignSystem.Radius.large)
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            .scaleEffect(isDismissing ? 0.95 : 1.0)
            .opacity(isDismissing ? 0 : 1)
            .animation(DesignSystem.Animation.standard, value: isDismissing)
        }
        .onAppear {
            permissionsService.checkAllPermissions()
        }
    }

    private var onboardingContent: some View {
        Group {
            switch currentStep {
            case 0: welcomeStep
            case 1: permissionsOverviewStep
            case 2: featureImpactStep
            case 3: actionStep
            default: welcomeStep
            }
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            .padding(.top, DesignSystem.Spacing.xl)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Welcome to Pulse")
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text("Your Mac's health companion")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: DesignSystem.Spacing.md) {
                Text("Pulse helps you monitor system health, optimize performance, and keep your Mac running smoothly.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text("To provide these features, Pulse may request certain permissions. Let's walk through what each one does and why it matters.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            Spacer()

            // Action buttons
            HStack(spacing: DesignSystem.Spacing.md) {
                Button {
                    dismiss()
                } label: {
                    Text("Skip for now")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Spacer()

                Button {
                    withAnimation(DesignSystem.Animation.standard) {
                        currentStep = 1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Continue")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.accentColor.gradient))
                .foregroundColor(.white)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
    }

    // MARK: - Step 2: Permissions Overview

    private var permissionsOverviewStep: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Header
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Permissions Overview")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Pulse only requests permissions it actually needs")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.top, DesignSystem.Spacing.lg)

            // Permission cards
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    permissionCard(
                        icon: "externaldrive.fill",
                        color: .orange,
                        title: "Full Disk Access",
                        description: "Allows Pulse to scan system directories for security threats and clean deep cache files.",
                        required: false
                    )

                    permissionCard(
                        icon: "accessibility",
                        color: .purple,
                        title: "Accessibility",
                        description: "Enables detection of apps with keyboard monitoring capabilities for security scanning.",
                        required: false
                    )

                    permissionCard(
                        icon: "bell.fill",
                        color: .blue,
                        title: "Notifications",
                        description: "Sends alerts when memory, CPU, or disk usage exceeds your configured thresholds.",
                        required: false
                    )

                    permissionCard(
                        icon: "applescript.fill",
                        color: .green,
                        title: "Apple Events",
                        description: "Counts browser tabs and manages applications for optimization features.",
                        required: false
                    )
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }

            Spacer()

            // Action buttons
            HStack(spacing: DesignSystem.Spacing.md) {
                Button {
                    withAnimation(DesignSystem.Animation.standard) {
                        currentStep = 0
                    }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Circle().fill(Color.primary.opacity(0.06)))

                Spacer()

                Button {
                    withAnimation(DesignSystem.Animation.standard) {
                        currentStep = 2
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Next")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.accentColor.gradient))
                .foregroundColor(.white)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
    }

    // MARK: - Step 3: Feature Impact

    private var featureImpactStep: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Header
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Feature Impact")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Pulse works partially without some permissions")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.top, DesignSystem.Spacing.lg)

            // Impact cards
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    impactCard(
                        permission: "Full Disk Access",
                        icon: "externaldrive.fill",
                        color: .orange,
                        withPermission: "Full security scan of system directories",
                        withoutPermission: "Limited to user directories only"
                    )

                    impactCard(
                        permission: "Accessibility",
                        icon: "accessibility",
                        color: .purple,
                        withPermission: "Keylogger detection enabled",
                        withoutPermission: "Security scanning still works"
                    )

                    impactCard(
                        permission: "Notifications",
                        icon: "bell.fill",
                        color: .blue,
                        withPermission: "Receive threshold alerts",
                        withoutPermission: "Monitor manually in dashboard"
                    )

                    impactCard(
                        permission: "Apple Events",
                        icon: "applescript.fill",
                        color: .green,
                        withPermission: "Browser tab counting available",
                        withoutPermission: "Core optimization works normally"
                    )
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }

            // Info note
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .frame(width: 20)
                Text("You can grant or revoke permissions anytime in System Settings → Privacy & Security")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(DesignSystem.Radius.small)
            .padding(.horizontal, DesignSystem.Spacing.lg)

            Spacer()

            // Action buttons
            HStack(spacing: DesignSystem.Spacing.md) {
                Button {
                    withAnimation(DesignSystem.Animation.standard) {
                        currentStep = 1
                    }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Circle().fill(Color.primary.opacity(0.06)))

                Spacer()

                Button {
                    withAnimation(DesignSystem.Animation.standard) {
                        currentStep = 3
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Continue")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.accentColor.gradient))
                .foregroundColor(.white)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
    }

    // MARK: - Step 4: Action

    private var actionStep: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Header
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Ready to Start")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Choose how you want to proceed")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.top, DesignSystem.Spacing.lg)

            // Current permission status
            VStack(spacing: DesignSystem.Spacing.md) {
                Text("Current Permission Status")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)

                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(permissionsService.permissions) { permission in
                        permissionStatusRow(permission: permission)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }

            Spacer()

            // Action buttons
            VStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    // Open System Settings to Privacy
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.PrivacySettings")!)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text("Open System Settings")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.accentColor.gradient))
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.lg)

                Button {
                    dismiss()
                } label: {
                    Text("Continue to Pulse")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.plain)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
                .foregroundColor(.primary)
                .padding(.horizontal, DesignSystem.Spacing.lg)

                Button {
                    dismiss()
                } label: {
                    Text("Skip and don't show again")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, DesignSystem.Spacing.sm)
            }
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
    }

    // MARK: - Helper Views

    private func permissionCard(icon: String, color: Color, title: String, description: String, required: Bool) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    if required {
                        Text("Required")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red.opacity(0.12)))
                            .foregroundColor(.red)
                    }
                }

                Text(description)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(DesignSystem.Radius.medium)
    }

    private func impactCard(permission: String, icon: String, color: Color, withPermission: String, withoutPermission: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color)
                Text(permission)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer()
            }

            HStack(spacing: DesignSystem.Spacing.lg) {
                // With permission
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                        Text("With permission")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundColor(.green)
                    }

                    Text(withPermission)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.primary)
                }

                // Without permission
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                        Text("Without")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundColor(.orange)
                    }

                    Text(withoutPermission)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, DesignSystem.Spacing.xs)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(DesignSystem.Radius.medium)
    }

    private func permissionStatusRow(permission: PermissionInfo) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: permission.status.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(permission.status.color))
                .frame(width: 24)

            Text(permission.type.rawValue)
                .font(.system(size: 12, weight: .medium, design: .rounded))

            Spacer()

            Text(permission.status.rawValue)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color(permission.status.color).opacity(0.12)))
                .foregroundColor(Color(permission.status.color))
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(DesignSystem.Radius.small)
    }

    // MARK: - Dismiss

    private func dismiss() {
        withAnimation(DesignSystem.Animation.standard) {
            isDismissing = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            settings.hasSeenPermissionOnboarding = true
            onDismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingPermissionView(onDismiss: {})
}
