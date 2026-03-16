import SwiftUI

// MARK: - AvatarFullscreenView

struct AvatarFullscreenView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Blurred background using the same hero image
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .scaleEffect(1.2)
                .blur(radius: 30)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.3))

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.dsaBorder, lineWidth: 3)
                )
                .padding(32)
        }
        .onTapGesture { dismiss() }
        .statusBarHidden()
    }
}

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
    }
}

// MARK: - AttributesColumn

struct AttributesColumn: View {
    let attrs: Attributes

    var body: some View {
        VStack(spacing: 0) {
            attrCell("MU", attrs.mu)
            attrCell("KL", attrs.kl)
            attrCell("IN", attrs.inValue)
            attrCell("CH", attrs.ch)
            attrCell("FF", attrs.ff)
            attrCell("GE", attrs.ge)
            attrCell("KO", attrs.ko)
            attrCell("KK", attrs.kk)
        }
        .frame(width: 80)
    }

    private func attrCell(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(.caption, weight: .bold))
            Text("\(value)")
                .font(.system(.title3, weight: .black))
        }
        .foregroundStyle(Color.attributeForeground(for: label))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.attributeBackground(for: label))
    }
}

// MARK: - Group Environment Keys

private struct GroupColorKey: EnvironmentKey {
    static let defaultValue: Color = .yellow
}
private struct GroupTextColorKey: EnvironmentKey {
    static let defaultValue: Color = .primary
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
                withAnimation(DSAAnimation.standard) { isExpanded.toggle() }
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
        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 3))
    }
}

// MARK: - CollapsibleGroup

struct CollapsibleGroup<Content: View>: View {
    let title: String
    let color: Color
    let textColor: Color
    @State private var isExpanded = true
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(_ title: String, color: Color, textColor: Color = .primary, @ViewBuilder content: () -> Content) {
        self.title = title
        self.color = color
        self.textColor = textColor
        self.content = content()
    }

    /// Ensures the header color is visible against the current background.
    private var headerColor: Color {
        colorScheme == .dark ? color.adaptedForDarkBackground() : color
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(DSAAnimation.standard) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Rectangle()
                        .frame(height: 2)
                        .foregroundStyle(headerColor)
                    Text(title)
                        .font(.system(.subheadline, weight: .black))
                        .foregroundStyle(headerColor)
                        .fixedSize()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(headerColor)
                    Rectangle()
                        .frame(height: 2)
                        .foregroundStyle(headerColor)
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
                Text(L(label))
                    .font(.body)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if !value.isEmpty {
                    Text(value)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.leading, 24)
            .padding(.trailing, 12)
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
                        Text(L(key)).font(.body).foregroundStyle(.secondary)
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

// MARK: - LPBarView

struct LPBarView: View {
    let current: Int
    let max: Int
    var accent: Color = Color.groupCombat
    var label: String = "lifePoints.short"
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onDecrement) {
                Text("▼")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 48)
                    .background(accent)
            }
            .buttonStyle(.plain)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(current == 0 ? Color.dsaDark : Color(UIColor.systemGray5))
                    let fraction = max > 0 ? CGFloat(current) / CGFloat(max) : 0
                    Rectangle()
                        .fill(barColor)
                        .frame(width: geo.size.width * fraction)
                    Text("\(L(label))   \(current) / \(max)")
                        .font(.system(.body, weight: .black))
                        .foregroundStyle(textColor)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 48)

            Button(action: onIncrement) {
                Text("▲")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 48)
                    .background(accent)
            }
            .buttonStyle(.plain)
        }
    }

    private var barColor: Color {
        if current == 0 { return .dsaDark }
        if current <= 5 { return Color(red: 0x8B/255.0, green: 0x00/255.0, blue: 0x00/255.0) }
        if max > 0 && current < max / 4 { return Color(red: 0xCC/255.0, green: 0x22/255.0, blue: 0x00/255.0) }
        if max > 0 && current < max / 2 { return Color(red: 0xE0/255.0, green: 0x70/255.0, blue: 0x00/255.0) }
        if max > 0 && current < max * 3 / 4 { return Color(red: 0xD4/255.0, green: 0xC0/255.0, blue: 0x00/255.0) }
        return Color(red: 0x2E/255.0, green: 0x7D/255.0, blue: 0x32/255.0)
    }

    private var textColor: Color {
        if current == 0 { return .white }
        if max > 0 && current >= max * 3 / 4 { return .white }
        return .primary
    }
}

