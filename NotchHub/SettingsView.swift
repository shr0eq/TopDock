import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.topthird.inset.filled")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("NotchHub")
                .font(.title2.bold())
            Text("설정 UI는 M4에서 구현됩니다.")
                .foregroundStyle(.secondary)
            Text("Made by Won-Young Choi")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(width: 480, height: 320)
    }
}

#Preview {
    SettingsView()
}
