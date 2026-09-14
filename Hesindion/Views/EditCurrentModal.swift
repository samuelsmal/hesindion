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
            Color.dsaOverlay
                .ignoresSafeArea()
                .onTapGesture { activeEdit = nil }

            VStack(spacing: 20) {
                Text("/ \(maxLabel)")
                    .font(.dsaBody(.subheadline))
                    .foregroundStyle(.secondary)

                Text("\(current)")
                    .font(.dsaHeading(.largeTitle))

                HStack(spacing: 16) {
                    Button {
                        edit.setCurrent(max(0, current - 1))
                    } label: {
                        Text("−")
                            .font(.dsaHeading(.title))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.groupPersonalData)
                            .dsaBox(.raised)
                    }
                    .buttonStyle(.dsaMotion)

                    Button {
                        let cap = edit.max == Int.max - 1 ? Int.max - 2 : edit.max
                        edit.setCurrent(min(cap, current + 1))
                    } label: {
                        Text("+")
                            .font(.dsaHeading(.title))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.groupPersonalData)
                            .dsaBox(.raised)
                    }
                    .buttonStyle(.dsaMotion)
                }
            }
            .padding(24)
            .background(Color(UIColor.systemBackground))
            .dsaBox(.raised)
            .padding(32)
            .gesture(
                DragGesture().onEnded { value in
                    if value.translation.height < -50 { activeEdit = nil }
                }
            )
        }
    }
}
