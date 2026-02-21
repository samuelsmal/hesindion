import SwiftUI

// MARK: - AttributesBar

struct AttributesBar: View {
    let attrs: Attributes

    var body: some View {
        HStack(spacing: 0) {
            attrBox("MU", attrs.mu)
            attrBox("KL", attrs.kl)
            attrBox("IN", attrs.inValue)
            attrBox("CH", attrs.ch)
            attrBox("FF", attrs.ff)
            attrBox("GE", attrs.ge)
            attrBox("KO", attrs.ko)
            attrBox("KK", attrs.kk)
        }
    }

    private func attrBox(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(.caption, weight: .bold))
            Text("\(value)")
                .font(.system(.title3, weight: .black))
        }
        .foregroundStyle(Color.attributeForeground(for: label))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.attributeBackground(for: label))
        .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
    }
}

// MARK: - Group Environment Keys

private struct GroupColorKey: EnvironmentKey {
    static let defaultValue: Color = .yellow
}
private struct GroupTextColorKey: EnvironmentKey {
    static let defaultValue: Color = .black
}

extension EnvironmentValues {
    var groupColor: Color {
        get { self[GroupColorKey.self] }
        set { self[GroupColorKey.self] = newValue }
    }
    var groupTextColor: Color {
        get { self[GroupTextColorKey.self] }
        set { self[GroupTextColorKey.self] = newValue }
    }
}

// MARK: - CollapsibleSection

struct CollapsibleSection<Content: View>: View {
    let title: String
    @State private var isExpanded = true
    @Environment(\.groupColor) private var groupColor
    @Environment(\.groupTextColor) private var groupTextColor
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .font(.system(.headline, weight: .black))
                        .foregroundStyle(groupTextColor)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(groupTextColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(groupColor)
            }
            .buttonStyle(.plain)

            if isExpanded { content }
        }
        .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
    }
}

// MARK: - CollapsibleGroup

struct CollapsibleGroup<Content: View>: View {
    let title: String
    let color: Color
    let textColor: Color
    @State private var isExpanded = true
    let content: Content

    init(_ title: String, color: Color, textColor: Color = .black, @ViewBuilder content: () -> Content) {
        self.title = title
        self.color = color
        self.textColor = textColor
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Rectangle()
                        .frame(height: 2)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.system(.caption, weight: .black))
                        .foregroundStyle(color)
                        .fixedSize()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(color)
                    Rectangle()
                        .frame(height: 2)
                        .foregroundStyle(color)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
            }
        }
        .environment(\.groupColor, color)
        .environment(\.groupTextColor, textColor)
    }
}

// MARK: - FieldRow

struct FieldRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Text(label)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !value.isEmpty {
                    Text(value)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
        }
    }
}

// MARK: - SubfieldBlock

struct SubfieldBlock: View {
    let label: String
    let subfields: [(String, String)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(.system(.body, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ForEach(subfields, id: \.0) { key, val in
                VStack(spacing: 0) {
                    HStack {
                        Text(key).font(.body).foregroundStyle(.secondary)
                        Spacer()
                        Text(val).font(.system(.body, design: .monospaced))
                    }
                    .padding(.leading, 24)
                    .padding(.trailing, 12)
                    .padding(.vertical, 6)
                    Divider()
                }
            }
        }
    }
}

// MARK: - EquipmentRow (swipe-to-delete)

struct EquipmentRow: View {
    let item: EquipmentItem
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    private let threshold: CGFloat = -80

    var body: some View {
        ZStack(alignment: .trailing) {
            Color.red
            Text("Delete")
                .font(.system(.body, weight: .bold))
                .foregroundStyle(.white)
                .padding(.trailing, 20)
                .opacity(offset < -40 ? 1 : 0)

            VStack(spacing: 0) {
                HStack {
                    Text(item.name).font(.body)
                    Spacer()
                    Text(String(format: "%.2f st", item.weight))
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemBackground))
                .offset(x: max(offset, threshold))
                Divider()
            }
        }
        .gesture(
            DragGesture()
                .onChanged { v in if v.translation.width < 0 { offset = v.translation.width } }
                .onEnded { v in
                    if v.translation.width < threshold {
                        onDelete()
                    } else {
                        withAnimation { offset = 0 }
                    }
                }
        )
    }
}
