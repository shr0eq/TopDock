import SwiftUI

struct HubPanelView: View {
    @EnvironmentObject private var state: PanelController.State

    var body: some View {
        VStack(spacing: 0) {
            // 헤더: 타이틀 + 핀
            HStack {
                Image(systemName: "rectangle.topthird.inset.filled")
                    .foregroundStyle(.secondary)
                Text("NotchHub")
                    .font(.headline)
                Spacer()
                Button {
                    state.isPinned.toggle()
                } label: {
                    Image(systemName: state.isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(state.isPinned ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(state.isPinned ? "핀 해제" : "핀 고정")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ItemGridView()
        }
        .frame(width: 520, height: 260)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }
}
