import SwiftUI

/// Renders a simplified Markdown string as stacked SwiftUI Text blocks.
/// Supports: `# H1`, `## H2`, `**bold**`, `*italic*`, `- bullet`, `* bullet`,
/// paragraphs (newline-separated). Inline links/code via AttributedString.
struct MarkdownText: View {

    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parse()) { block in
                block.render()
            }
        }
    }

    private func parse() -> [MDBlock] {
        var blocks: [MDBlock] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let raw = lines[i]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                i += 1
                continue
            }
            if trimmed.hasPrefix("### ") {
                blocks.append(.h3(String(trimmed.dropFirst(4))))
                i += 1
            } else if trimmed.hasPrefix("## ") {
                blocks.append(.h2(String(trimmed.dropFirst(3))))
                i += 1
            } else if trimmed.hasPrefix("# ") {
                blocks.append(.h1(String(trimmed.dropFirst(2))))
                i += 1
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                var bullets: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if t.hasPrefix("- ") { bullets.append(String(t.dropFirst(2))) }
                    else if t.hasPrefix("* ") { bullets.append(String(t.dropFirst(2))) }
                    else { break }
                    i += 1
                }
                blocks.append(.bullets(bullets))
            } else {
                blocks.append(.paragraph(trimmed))
                i += 1
            }
        }
        return blocks
    }
}

private enum MDBlock: Identifiable {
    case h1(String)
    case h2(String)
    case h3(String)
    case paragraph(String)
    case bullets([String])

    var id: String {
        switch self {
        case .h1(let s), .h2(let s), .h3(let s), .paragraph(let s): return UUID().uuidString + s
        case .bullets(let a): return UUID().uuidString + a.joined()
        }
    }

    @ViewBuilder
    func render() -> some View {
        switch self {
        case .h1(let s):
            Text(inline(s))
                .font(.title3.bold())
                .padding(.top, 2)
        case .h2(let s):
            Text(inline(s))
                .font(.headline)
                .padding(.top, 2)
        case .h3(let s):
            Text(inline(s))
                .font(.subheadline.bold())
        case .paragraph(let s):
            Text(inline(s))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        case .bullets(let arr):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(arr, id: \.self) { b in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").font(.subheadline)
                        Text(inline(b))
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func inline(_ s: String) -> AttributedString {
        let opts = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: s, options: opts)) ?? AttributedString(s)
    }
}
