//
//  Components.swift
//  husk
//
//  Created by Nathan Ellis on 30/05/2025.
//
import SwiftUI

struct GlassIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .blendMode(.overlay)
            )
            .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.smooth(duration: 0.15), value: configuration.isPressed)
            .foregroundStyle(.primary)
    }
}

struct SmallGlassIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .padding(8)
            .background(Color(uiColor: .systemGray5).opacity(configuration.isPressed ? 0.7 : 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct SmallGlassTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemGray5).opacity(configuration.isPressed ? 0.7 : 0.5))
            .clipShape(Capsule(style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Visual Effect View for Blur
struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) { uiView.effect = effect }
}

// MARK: - Custom Menu View (Apple Sports Style)
struct CustomMenuViewUpdated: View {
    @Binding var isPresented: Bool
    var namespace: Namespace.ID

    struct MenuItem: Identifiable {
        let id = UUID()
        let title: String
        let iconName: String
    }

    let profileImageName: String = "profile_placeholder"
    let menuItemsInternal: [MenuItem] = [
        MenuItem(title: "Search", iconName: "magnifyingglass"),
        MenuItem(title: "My Leagues", iconName: "trophy.fill"),
        MenuItem(title: "My Teams", iconName: "star.fill"),
        MenuItem(title: "Champions League", iconName: "sportscourt.fill"),
        MenuItem(title: "Formula 1", iconName: "flag.checkered.2.crossed"),
        MenuItem(title: "Premier League", iconName: "figure.soccer")
    ]
    @State private var selectedItemTitle: String? = "My Leagues"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(profileImageName)
                    .resizable().scaledToFill().frame(width: 44, height: 44).clipShape(Circle()).background(Circle().fill(Color(uiColor: .systemGray4)))
                Spacer()
                Button(action: { print("Filter tapped") }) { Image(systemName: "line.3.horizontal.decrease.circle") }
                    .buttonStyle(SmallGlassIconButtonStyle()).foregroundStyle(.primary)
                Button(action: { print("Edit tapped") }) { Text("Edit") }
                    .buttonStyle(SmallGlassTextButtonStyle()).foregroundStyle(.primary)
            }
            .padding(.horizontal).padding(.top, 16).padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(menuItemsInternal) { item in
                        Button(action: {
                            print("\(item.title) tapped")
                            if item.title != "Search" { selectedItemTitle = item.title }
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: item.iconName)
                                    .font(.system(size: 18, weight: (item.title == "Search" ? .regular : .medium)))
                                    .frame(width: 24, alignment: .center)
                                    .foregroundStyle(item.title == selectedItemTitle && item.title != "Search" ? Color.accentColor : Color.primary.opacity(0.8))
                                Text(item.title).font(.system(size: 17)).foregroundStyle(Color.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 16).padding(.vertical, item.title == "Search" ? 10 : 12)
                            .background(
                                ZStack {
                                    if item.title == selectedItemTitle && item.title != "Search" {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(uiColor: .systemGray3).opacity(0.5)).padding(.horizontal, 8)
                                    }
                                    if item.title == "Search" {
                                         RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(uiColor: .systemGray3).opacity(0.3)).padding(.horizontal, 8)
                                    }
                                }
                            )
                        }
                        .padding(.bottom, item.title == "Search" ? 12 : 2)
                        if item.title != menuItemsInternal.last?.title && item.title != "Search" && (menuItemsInternal.firstIndex(where: {$0.id == item.id}).map { $0 + 1 < menuItemsInternal.count && menuItemsInternal[$0 + 1].title != "Search"} ?? true) {
                             Divider().padding(.leading, 16 + 24 + 12).opacity(0.5)
                        }
                    }
                }
                .padding(.top, 5)
            }
        }
        .frame(width: min(UIScreen.main.bounds.width * 0.85, 340), height: min(UIScreen.main.bounds.height * 0.65, 500))
        .background(VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark)))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .matchedGeometryEffect(id: "menuTransition", in: namespace) // Key for morphing size and position
        .shadow(color: .black.opacity(0.35), radius: 25, x: 0, y: 15)
        .overlay(Capsule().fill(Color(uiColor: .systemGray2).opacity(0.7)).frame(width: 36, height: 5).padding(10), alignment: .top)
    }
}

struct DynamicTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textContainer.widthTracksTextView = true
        return textView
    }
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        DynamicTextEditor.recalculateHeight(view: uiView, result: $dynamicHeight)
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, height: $dynamicHeight)
    }
    class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var height: Binding<CGFloat>
        
        init(text: Binding<String>, height: Binding<CGFloat>) {
            self.text = text
            self.height = height
        }
        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
            DynamicTextEditor.recalculateHeight(view: textView, result: height)
        }
    }
    
    static func recalculateHeight(view: UIView, result: Binding<CGFloat>) {
        guard let textView = view as? UITextView else { return }
        
        let newSize = textView.sizeThatFits(CGSize(width: textView.bounds.width,
                                                   height: CGFloat.greatestFiniteMagnitude))
        
        if result.wrappedValue != newSize.height {
            DispatchQueue.main.async {
                result.wrappedValue = newSize.height
            }
        }
    }
}
