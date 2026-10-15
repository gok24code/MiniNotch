import SwiftUI

/// The apps Always Awake is currently waiting for.
struct AwakeListView: View {
    let awake: AwakeKeeper

    var body: some View {
        Group {
            if awake.activeTasks.isEmpty {
                Text("Looking for active tasks…")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: NotchGeometry.awakeRowSpacing) {
                        ForEach(awake.activeTasks) { item in
                            AwakeRow(item: item)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 16)
        .padding(.bottom, NotchGeometry.awakeListBottomPadding)
        .foregroundStyle(.white)
    }
}

private struct AwakeRow: View {
    let item: ActivityItem

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let icon = item.icon {
                    Image(nsImage: icon).resizable()
                } else {
                    Image(systemName: "gearshape.fill").resizable().scaledToFit().padding(3)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: 20, height: 20)

            Text(item.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(item.reasons.map(\.label).joined(separator: " · "))
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: NotchGeometry.awakeRowHeight)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.08))
        )
    }
}
