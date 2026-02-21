import SwiftUI

struct ToastModifier: ViewModifier {
    @Binding var message: String?
    let isError: Bool

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let msg = message {
                HStack(spacing: 8) {
                    Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(msg)
                        .font(Theme.Fonts.caption)
                        .lineLimit(2)
                }
                .foregroundColor(isError ? Theme.Colors.error : Theme.Colors.success)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isError ? Theme.Colors.errorBg : Theme.Colors.successBg)
                .cornerRadius(Theme.Radii.card)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radii.card)
                        .stroke(isError ? Theme.Colors.error.opacity(0.3) : Theme.Colors.success.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            message = nil
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: message)
    }
}

extension View {
    func toastError(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message, isError: true))
    }

    func toastSuccess(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message, isError: false))
    }
}
