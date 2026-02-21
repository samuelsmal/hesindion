import SwiftUI

// MARK: - ActiveEdit

struct ActiveEdit {
    let label: String
    let max: Int  // Int.max - 1 signals unbounded (money)
    let getCurrent: () -> Int
    let setCurrent: (Int) -> Void
}

// MARK: - EditCurrentModal

struct EditCurrentModal: View {
    let edit: ActiveEdit
    @Binding var activeEdit: ActiveEdit?

    private var current: Int { edit.getCurrent() }
    private var maxLabel: String {
        edit.max == Int.max - 1 ? "∞" : "\(edit.max)"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { activeEdit = nil }

            VStack(spacing: 20) {
                Text("/ \(maxLabel)")
                    .font(.system(.subheadline))
                    .foregroundStyle(.secondary)

                Text("\(current)")
                    .font(.system(.largeTitle, weight: .black))

                HStack(spacing: 16) {
                    Button {
                        edit.setCurrent(max(0, current - 1))
                    } label: {
                        Text("−")
                            .font(.system(.title, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.yellow)
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                    }
                    .buttonStyle(.plain)

                    Button {
                        let cap = edit.max == Int.max - 1 ? Int.max - 2 : edit.max
                        edit.setCurrent(min(cap, current + 1))
                    } label: {
                        Text("+")
                            .font(.system(.title, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.yellow)
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .background(Color(UIColor.systemBackground))
            .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
            .padding(32)
            .gesture(
                DragGesture().onEnded { value in
                    if value.translation.height < -50 { activeEdit = nil }
                }
            )
        }
    }
}
