import SwiftUI

struct StableViewClosure<Input, Output>: Equatable {
    private let body: (Input) -> Output

    init(_ body: @escaping (Input) -> Output) {
        self.body = body
    }

    func callAsFunction(_ input: Input) -> Output {
        body(input)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        true
    }
}

struct KeyedViewClosure<Key: Equatable, Input, Output>: Equatable {
    let key: Key
    private let body: (Input) -> Output

    init(
        key: Key,
        _ body: @escaping (Input) -> Output
    ) {
        self.key = key
        self.body = body
    }

    func callAsFunction(_ input: Input) -> Output {
        body(input)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.key == rhs.key
    }
}

/// A row-agnostic template for one swipe action slot.
///
/// The template is defined once at container scope. The id-only row modifier binds `RowID` later,
/// using the template slot id for button identity and the row id for diff eligibility.
public struct SwipeActionTemplate<RowID: Hashable> {
    let id: AnyHashable
    let title: LocalizedStringKey?
    let systemImage: String?
    let role: SwipeActionRole
    let tint: SwipeActionTint
    private let action: StableViewClosure<RowID, Void>

    public init(
        id: some Hashable,
        _ title: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        role: SwipeActionRole = .normal(),
        tint: Color = .accentColor,
        action: @escaping (RowID) -> Void
    ) {
        self.id = AnyHashable(id)
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.tint = SwipeActionTint(tint)
        self.action = StableViewClosure(action)
    }

    public init<Style: ShapeStyle>(
        id: some Hashable,
        _ title: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        role: SwipeActionRole = .normal(),
        tint: Style,
        action: @escaping (RowID) -> Void
    ) {
        self.id = AnyHashable(id)
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.tint = SwipeActionTint(tint)
        self.action = StableViewClosure(action)
    }

    func bind(to rowID: RowID) -> SwipeAction {
        SwipeAction(
            resolvedID: id,
            role: role,
            tint: tint,
            title: title,
            systemImage: systemImage,
            handlerKey: AnyHashable(rowID),
            action: { action(rowID) },
            controlledAction: nil,
            makeLabel: { _ in
                AnyView(
                    SwipeActionDefaultLabel(
                        title: title,
                        systemImage: systemImage
                    )
                )
            }
        )
    }
}

/// A type-erased template bundle for both sides of one row.
///
/// `SwipeActionTemplate` is one slot and generic over `RowID`; this bundle stores both sides after
/// erasing `RowID` so `swipeCellScope(actionTemplate:)` remains non-generic.
public struct SwipeCellActionTemplate {
    private let leadingTemplates: [AnySwipeActionTemplate]
    private let trailingTemplates: [AnySwipeActionTemplate]

    public init() {
        self.leadingTemplates = []
        self.trailingTemplates = []
    }

    public init<RowID: Hashable>(
        leading: [SwipeActionTemplate<RowID>] = [],
        trailing: [SwipeActionTemplate<RowID>] = []
    ) {
        self.leadingTemplates = leading.map(AnySwipeActionTemplate.init)
        self.trailingTemplates = trailing.map(AnySwipeActionTemplate.init)
    }

    func resolveActions<RowID: Hashable>(
        for rowID: RowID,
        emitsDiagnostics: Bool = true
    ) -> (leading: [SwipeAction], trailing: [SwipeAction]) {
        (
            leading: Self.resolve(leadingTemplates, for: rowID, emitsDiagnostics: emitsDiagnostics),
            trailing: Self.resolve(trailingTemplates, for: rowID, emitsDiagnostics: emitsDiagnostics)
        )
    }

    private static func resolve<RowID: Hashable>(
        _ templates: [AnySwipeActionTemplate],
        for rowID: RowID,
        emitsDiagnostics: Bool
    ) -> [SwipeAction] {
        let erasedRowID = AnyHashable(rowID)

        return templates.compactMap { template in
            template.bind(erasedRowID, suppliedRowIDType: RowID.self, emitsDiagnostics: emitsDiagnostics)
        }
    }
}

private struct AnySwipeActionTemplate {
    private let expectedRowIDType: Any.Type
    private let bindAction: (AnyHashable) -> SwipeAction?

    init<RowID: Hashable>(_ template: SwipeActionTemplate<RowID>) {
        self.expectedRowIDType = RowID.self
        self.bindAction = { erasedRowID in
            guard let rowID = erasedRowID.base as? RowID else {
                return nil
            }
            return template.bind(to: rowID)
        }
    }

    func bind(
        _ erasedRowID: AnyHashable,
        suppliedRowIDType: Any.Type,
        emitsDiagnostics: Bool
    ) -> SwipeAction? {
        guard let action = bindAction(erasedRowID) else {
            #if DEBUG
                SwipeCellDiagnostics.warning(
                    "action-template.row-id-mismatch.\(expectedRowIDType).\(suppliedRowIDType)",
                    enabled: emitsDiagnostics,
                    message: "action template was built for RowID = \(expectedRowIDType) "
                        + "but a row supplied id of type \(suppliedRowIDType); "
                        + "the template binding is skipped for this row."
                )
            #endif
            return nil
        }

        return action
    }
}
