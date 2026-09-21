import SwiftUI
import UIKit

/// A native modal/navigation stack; only its content transition is customized.
struct CardOrderSheet: View {
    var selectCardType: (CardOrderKind) -> Void
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 64

    var body: some View {
        OrderSheetNavigation(selectCardType: selectCardType)
            .ignoresSafeArea()
            .presentationDetents([.height(104 + rowHeight * 2 + 4)])
            .presentationSizing(.page)
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(48)
            .presentationBackground(Color("ModalBackground"))
    }
}

private enum OrderSheetStep {
    case recipient, cardType
    var title: String { self == .recipient ? "Who to issue extra card for" : "Select card type" }
}

private final class OrderSheetMorphState: ObservableObject {
    @Published var step: OrderSheetStep
    init(_ step: OrderSheetStep) { self.step = step }
}

/// Both pages share row identities. Text interpolates while the leading image
/// slot collapses and the chevron becomes Issue, without sliding an opaque page.
private struct OrderSheetContent: View {
    @ObservedObject var state: OrderSheetMorphState
    var select: (Int) -> Void
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 64
    private var isType: Bool { state.step == .cardType }

    var body: some View {
        ScrollView {
          VStack(spacing: 4) {
            ForEach(0..<2) { index in
                Button { select(index) } label: {
                    row(index)
                }
                .buttonStyle(.plain)
                .allowsHitTesting(isType || index == 0)
                .accessibilityRemoveTraits(removedTraits(index))
                .accessibilityIdentifier(identifier(index))
            }
        }
        .padding(.horizontal, isType ? 20 : 24.5)
        .padding(.top, headerContentInset)
        .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .softNavigationScrollEdge()
        .background(Color("ModalBackground"))
    }

    private func row(_ index: Int) -> some View {
        HStack(spacing: 0) {
            Image(index == 0 ? "order-avatar" : "order-add-person")
                .resizable().frame(width: 40, height: 40)
                .frame(width: isType ? 0 : 56, alignment: .leading)
                .opacity(isType ? 0 : 1)
                .clipped()
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(isType ? (index == 0 ? "Physical" : "Digital")
                     : (index == 0 ? "Me" : "Another person"))
                    .font(.body).frame(minHeight: 20)
                    .contentTransition(.interpolate)
                if isType || index == 1 {
                    Text(isType ? (index == 0 ? "Pay everywhere" : "Ready to use")
                         : "They will spend from your Crédito")
                        .font(.footnote)
                        .foregroundStyle(Color("AccountTextSecondary"))
                        .frame(minHeight: 16)
                        .contentTransition(.interpolate)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ZStack {
                Image("account-chevron").resizable().frame(width: 16, height: 16)
                    .opacity(isType ? 0 : 1)
                Text("Issue")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 40)
                    .background(Color("AccentColor"), in: RoundedRectangle(cornerRadius: 12))
                    .opacity(isType ? 1 : 0)
            }
            .frame(width: isType ? 62 : 32, height: 40)
            .padding(.leading, 8)
            .accessibilityHidden(true)
        }
        .foregroundStyle(Color("AccountTextPrimary"))
        .frame(height: rowHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func identifier(_ index: Int) -> String {
        if isType { return index == 0 ? "issuePhysicalCardButton" : "issueDigitalCardButton" }
        return index == 0 ? "orderForMeButton" : "orderForAnotherPerson"
    }

    private func removedTraits(_ index: Int) -> AccessibilityTraits {
        !isType && index == 1 ? .isButton : []
    }

    private var headerContentInset: CGFloat {
        if #available(iOS 26.0, *) { return 14 }
        return 24
    }
}

private struct OrderSheetNavigation: UIViewControllerRepresentable {
    var selectCardType: (CardOrderKind) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(selectCardType: selectCardType) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let coordinator = context.coordinator
        // The preview launcher opens directly at the type choice. There is no
        // recipient page beneath it and therefore no in-sheet Back button.
        let navigation = UINavigationController(rootViewController: coordinator.page(.cardType))
        navigation.delegate = coordinator
        navigation.view.backgroundColor = UIColor(named: "ModalBackground")
        navigation.navigationBar.tintColor = UIColor(named: "AccountTextPrimary")
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.shadowColor = .clear
        navigation.navigationBar.standardAppearance = appearance
        // Default edge appearance stays transparent and receives the native
        // soft effect from each page's ScrollView, not an opaque color layer.
        navigation.navigationBar.scrollEdgeAppearance = nil
        coordinator.navigation = navigation
        return navigation
    }

    func updateUIViewController(_ navigation: UINavigationController, context: Context) {
        context.coordinator.selectCardType = selectCardType
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate {
        weak var navigation: UINavigationController?
        var selectCardType: (CardOrderKind) -> Void

        init(selectCardType: @escaping (CardOrderKind) -> Void) { self.selectCardType = selectCardType }

        fileprivate func page(_ step: OrderSheetStep) -> OrderSheetPage {
            OrderSheetPage(step: step) { [weak self] index in
                guard let self, let navigation, navigation.transitionCoordinator == nil else { return }
                if step == .recipient {
                    guard index == 0, navigation.viewControllers.count == 1 else { return }
                    navigation.pushViewController(page(.cardType), animated: true)
                } else {
                    selectCardType(index == 0 ? .physical : .digital)
                }
            }
        }

        func navigationController(_ navigationController: UINavigationController,
                                  animationControllerFor operation: UINavigationController.Operation,
                                  from fromVC: UIViewController, to toVC: UIViewController)
        -> (any UIViewControllerAnimatedTransitioning)? {
            OrderSheetMorphTransition()
        }
    }
}

private final class OrderSheetPage: UIHostingController<OrderSheetContent> {
    let step: OrderSheetStep
    let morph: OrderSheetMorphState

    init(step: OrderSheetStep, select: @escaping (Int) -> Void) {
        self.step = step
        morph = OrderSheetMorphState(step)
        super.init(rootView: OrderSheetContent(state: morph, select: select))
        navigationItem.title = step.title
        navigationItem.backButtonDisplayMode = .minimal
        let title = UILabel()
        title.text = step.title
        title.font = UIFontMetrics(forTextStyle: .title3)
            .scaledFont(for: .systemFont(ofSize: 20, weight: .semibold))
        title.adjustsFontForContentSizeCategory = true
        title.textColor = UIColor(named: "AccountTextPrimary")
        title.sizeToFit()
        if #available(iOS 26.0, *) {
            title.transform = CGAffineTransform(translationX: 0, y: 4)
        } else {
            title.transform = CGAffineTransform(translationX: 0, y: 9)
        }
        navigationItem.titleView = title
        view.backgroundColor = UIColor(named: "ModalBackground")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

/// UIKit owns push/pop and the real navbar. SwiftUI interpolates the *same*
/// visible rows; the destination is revealed only after they reach its layout.
private final class OrderSheetMorphTransition: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using context: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        UIAccessibility.isReduceMotionEnabled ? 0.16 : 0.38
    }

    func animateTransition(using context: any UIViewControllerContextTransitioning) {
        guard let from = context.viewController(forKey: .from) as? OrderSheetPage,
              let to = context.viewController(forKey: .to) as? OrderSheetPage else {
            context.completeTransition(false)
            return
        }
        to.view.frame = context.finalFrame(for: to)
        context.containerView.insertSubview(to.view, belowSubview: from.view)
        to.view.layoutIfNeeded()
        let duration = transitionDuration(using: context)
        if UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: duration, animations: {
                from.view.alpha = 0
            }, completion: { _ in
                let completed = !context.transitionWasCancelled
                if completed { from.view.removeFromSuperview() }
                from.view.alpha = 1
                context.completeTransition(completed)
            })
            return
        }
        let animation: Animation = .smooth(duration: duration, extraBounce: 0)
        withAnimation(animation, completionCriteria: .removed) {
            from.morph.step = to.step
        } completion: {
            let completed = !context.transitionWasCancelled
            if completed { from.view.removeFromSuperview() }
            context.completeTransition(completed)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { from.morph.step = from.step }
        }
    }
}
