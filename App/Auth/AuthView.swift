import SwiftUI

/// Sign-in screen (spec screen #1, prototype data-screen="auth"). Sign in with
/// Apple / Google, brokered by Entra External ID. No passwords in the app.
struct AuthView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        ZStack {
            FMW.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                brand
                Spacer()
                actions
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)

            if auth.isLoading {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView().controlSize(.large).tint(FMW.pine)
            }
        }
    }

    private var brand: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(FMW.heroGradient).frame(width: 92, height: 92)
                    .overlay(Circle().stroke(FMW.sun.opacity(0.30), lineWidth: 1))
                Image(systemName: "tree.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(FMW.pine)
            }
            .shadow(color: FMW.ink.opacity(0.12), radius: 14, x: 0, y: 8)

            Text("Fox Mill Woods").font(FMW.display(30, .bold)).foregroundStyle(FMW.ink)
            Text("CONNECT · PLAY · GROW")
                .font(FMW.ui(11, .bold)).tracking(2).foregroundStyle(FMW.sun)
            Text("Your neighborhood’s events, rentals, and everything ahead — in one place.")
                .font(FMW.ui(14.5))
                .foregroundStyle(FMW.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.top, 6)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if let message = auth.errorMessage {
                Text(message)
                    .font(FMW.ui(12.5, .semibold))
                    .foregroundStyle(FMW.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }
            signButton(title: "Sign in with Apple", symbol: "apple.logo", fg: .white, bg: FMW.ink) {
                Task { await auth.signInWithApple() }
            }
            signButton(title: "Sign in with Google", symbol: "g.circle.fill", fg: FMW.ink, bg: FMW.paper, bordered: true) {
                Task { await auth.signInWithGoogle() }
            }
            Text("By continuing you agree to the Fox Mill Woods community guidelines.")
                .font(FMW.ui(11))
                .foregroundStyle(FMW.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.top, 2)
        }
    }

    private func signButton(
        title: String, symbol: String, fg: Color, bg: Color,
        bordered: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
                Text(title).font(FMW.ui(16, .semibold))
            }
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                if bordered {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(FMW.line, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(auth.isLoading)
    }
}

#Preview {
    AuthView().environment(AuthService())
}
