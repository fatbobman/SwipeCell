import CoreGraphics
import SwiftUI
import Testing

@_spi(ManualDebug) @testable import SwipeCell

@MainActor
@Suite("SwipeCell action group normalization")
struct SwipeActionGroupTests {
    private enum ActionID: Hashable {
        case pin
        case delete
        case more
    }

    private enum TemplateSlotID: Hashable {
        case pin
        case delete
    }

    private func stableAction(
        tint: SwipeActionTint,
        handlerKey: AnyHashable = AnyHashable("handler")
    ) -> SwipeAction {
        SwipeAction(
            resolvedID: AnyHashable(ActionID.pin),
            role: .normal(),
            tint: tint,
            title: nil,
            systemImage: nil,
            handlerKey: handlerKey,
            action: {},
            controlledAction: nil,
            makeLabel: { _ in AnyView(EmptyView()) }
        )
    }

    @Test("structured action carries role/timing defaults")
    func structuredActionDefaults() {
        let action = SwipeAction("Flag", systemImage: "flag") {}

        #expect(action.role == .normal(.immediate))
        #expect(action.fireTiming == .immediate)
        #expect(action.title == "Flag")
        #expect(action.systemImage == "flag")
    }

    @Test("custom action label keeps descriptor behavior without public AnyView")
    func customActionLabelDescriptor() {
        let action = SwipeAction(role: .destructive(.init()), tint: .red) {
        } label: { context in
            Text(context.isOutermost ? "Outer" : "Inner")
        }

        #expect(action.role == .destructive(.init()))
        #expect(action.fireTiming == .immediate)
        #expect(action.title == nil)
        #expect(action.systemImage == nil)
    }

    @Test("destructive shorthand carries the default payload")
    func destructiveShorthandCarriesDefaultPayload() {
        let shorthand = SwipeAction("Delete", role: .destructive()) {}
        let explicit = SwipeAction("Delete", role: .destructive(.init())) {}

        #expect(shorthand.role == explicit.role)
        #expect(shorthand.role.kind == .destructive)

        let shorthandGroup = SwipeActionGroup(
            side: .trailing,
            actions: [shorthand, SwipeAction("More") {}],
            actionWidth: 80,
            configuration: .iOSDefault
        )
        let explicitGroup = SwipeActionGroup(
            side: .trailing,
            actions: [explicit, SwipeAction("More") {}],
            actionWidth: 80,
            configuration: .iOSDefault
        )

        let shorthandConfiguration = shorthandGroup.interactionSideConfiguration(containerWidth: 320)
        let explicitConfiguration = explicitGroup.interactionSideConfiguration(containerWidth: 320)

        #expect(shorthandConfiguration.allowsDestructive == explicitConfiguration.allowsDestructive)
        #expect(
            shorthandConfiguration.destructiveActivationExtent
                == explicitConfiguration.destructiveActivationExtent
        )
        #expect(shorthandConfiguration.destructiveHoldExtent == explicitConfiguration.destructiveHoldExtent)
    }

    @Test("explicit destructive payload still overrides defaults")
    func explicitDestructivePayloadStillOverridesDefaults() {
        let action = SwipeAction(
            "Delete",
            role: .destructive(
                .init(
                    activation: .rowWidthFraction(0.75),
                    completion: .triggerAfterReset
                )
            )
        ) {}

        guard case .destructive(let configuration) = action.role else {
            Issue.record("Expected a destructive role")
            return
        }

        #expect(configuration.activation == .rowWidthFraction(0.75))
        #expect(configuration.completion == .triggerAfterReset)
    }

    @Test("destructive button tap falls back from hold completion to after collapse")
    func destructiveButtonTapFallsBackFromHoldCompletionToAfterCollapse() {
        let direct = SwipeAction(
            "Delete",
            role: .destructive(.init(completion: .directTrigger))
        ) {}
        let afterReset = SwipeAction(
            "Delete",
            role: .destructive(.init(completion: .triggerAfterReset))
        ) {}
        let hold = SwipeAction(
            "Delete",
            role: .destructive(.init(completion: .triggerHoldExpanded))
        ) {}

        #expect(direct.buttonTapFireTiming == .immediate)
        #expect(afterReset.buttonTapFireTiming == .afterCollapse)
        #expect(hold.buttonTapFireTiming == .afterCollapse)
    }

    @Test("default action identity is fresh per construction")
    func defaultActionIdentityIsFreshPerConstruction() {
        let first = SwipeAction("Archive") {}
        let second = SwipeAction("Archive") {}

        #expect(first.id != second.id)
    }

    @Test("supplied action identity is retained across rebuilt descriptors")
    func suppliedActionIdentityIsRetainedAcrossRebuiltDescriptors() {
        let first = SwipeAction(id: ActionID.pin, "Pin", systemImage: "pin") {}
        let second = SwipeAction(id: ActionID.pin, "Pin", systemImage: "pin") {}
        let destructive = SwipeAction(id: ActionID.delete, "Delete", role: .destructive(.init())) { _ in }
        let custom = SwipeAction(id: ActionID.more, role: .normal(), tint: .purple) {
        } label: { _ in
            Text("More")
        }

        #expect(first.id == second.id)
        #expect(first.id == AnyHashable(ActionID.pin))
        #expect(destructive.id == AnyHashable(ActionID.delete))
        #expect(custom.id == AnyHashable(ActionID.more))
    }

    @Test("stable identity does not freeze rebuilt action closures")
    func stableIdentityDoesNotFreezeRebuiltActionClosures() {
        var events: [String] = []

        func makeAction(_ event: String) -> SwipeAction {
            SwipeAction(id: ActionID.pin, "Pin") {
                events.append(event)
            }
        }

        let first = makeAction("first")
        let second = makeAction("second")

        #expect(first.id == second.id)

        first.action()
        second.action()

        #expect(events == ["first", "second"])
    }

    @Test("caller supplied action identity still does not make inline actions equatable")
    func callerSuppliedActionIdentityStillDoesNotMakeInlineActionsEquatable() {
        let first = SwipeAction(id: ActionID.pin, "Pin", systemImage: "pin") {}
        let second = SwipeAction(id: ActionID.pin, "Pin", systemImage: "pin") {}

        #expect(first.id == second.id)
        #expect(first != second)
    }

    @Test("value action separates button identity from handler input")
    func valueActionSeparatesButtonIdentityFromHandlerInput() {
        var events: [Int] = []
        let first = SwipeAction(id: ActionID.pin, value: 42, "Pin", systemImage: "pin") { value in
            events.append(value)
        }
        let second = SwipeAction(id: ActionID.pin, value: 42, "Pin", systemImage: "pin") { value in
            events.append(value + 1)
        }
        let otherValue = SwipeAction(id: ActionID.pin, value: 43, "Pin", systemImage: "pin") { value in
            events.append(value)
        }

        #expect(first.id == AnyHashable(ActionID.pin))
        #expect(first == second)
        #expect(first != otherValue)

        first.action()
        #expect(events == [42])
    }

    @Test("value trigger action passes handler input and controller")
    func valueTriggerActionPassesHandlerInputAndController() {
        var receivedValue: Int?
        let action = SwipeAction(
            id: ActionID.delete,
            value: 9,
            "Delete",
            role: .destructive(.init())
        ) { value, controller in
            receivedValue = value
            controller.collapse()
        }
        let controller = SwipeActionTriggerController.detached()

        #expect(action.trigger(with: controller) == true)
        #expect(receivedValue == 9)
        #expect(controller.isResolved)
    }

    @Test("template binding uses slot id and row id as separate identity axes")
    func templateBindingUsesSlotIDAndRowIDAsSeparateIdentityAxes() {
        var events: [String] = []
        let template = SwipeCellActionTemplate(
            leading: [
                SwipeActionTemplate<Int>(
                    id: TemplateSlotID.pin,
                    "Pin",
                    systemImage: "pin",
                    tint: .green
                ) { rowID in
                    events.append("pin \(rowID)")
                }
            ],
            trailing: [
                SwipeActionTemplate<Int>(
                    id: TemplateSlotID.delete,
                    "Delete",
                    systemImage: "trash",
                    tint: .red
                ) { rowID in
                    events.append("delete \(rowID)")
                }
            ]
        )

        let first = template.resolveActions(for: 42)
        let second = template.resolveActions(for: 42)
        let otherRow = template.resolveActions(for: 43)

        #expect(first.leading == second.leading)
        #expect(first.trailing == second.trailing)
        #expect(first.leading.first?.id == AnyHashable(TemplateSlotID.pin))
        #expect(first.trailing.first?.id == AnyHashable(TemplateSlotID.delete))
        #expect(first.leading != otherRow.leading)

        first.leading.first?.action()
        first.trailing.first?.action()

        #expect(events == ["pin 42", "delete 42"])
    }

    @Test("template row id mismatch degrades to empty actions")
    func templateRowIDMismatchDegradesToEmptyActions() {
        let template = SwipeCellActionTemplate(
            leading: [
                SwipeActionTemplate<Int>(id: TemplateSlotID.pin, "Pin") { _ in }
            ]
        )

        let resolved = template.resolveActions(for: "wrong-row-id-type", emitsDiagnostics: false)

        #expect(resolved.leading.isEmpty)
        #expect(resolved.trailing.isEmpty)
    }

    @Test("template bound action groups propagate equatable semantics")
    func templateBoundActionGroupsPropagateEquatableSemantics() {
        let template = SwipeCellActionTemplate(
            trailing: [
                SwipeActionTemplate<Int>(id: TemplateSlotID.delete, "Delete", tint: .red) { _ in }
            ]
        )

        let first = template.resolveActions(for: 7)
        let second = template.resolveActions(for: 7)
        let third = template.resolveActions(for: 8)

        let firstGroup = SwipeActionGroup(side: .trailing, actions: first.trailing)
        let secondGroup = SwipeActionGroup(side: .trailing, actions: second.trailing)
        let thirdGroup = SwipeActionGroup(side: .trailing, actions: third.trailing)

        #expect(firstGroup == secondGroup)
        #expect(firstGroup != thirdGroup)
    }

    @Test("action tint equality follows color keyed and unkeyed contracts")
    func actionTintEqualityFollowsColorKeyedAndUnkeyedContracts() {
        #expect(SwipeActionTint(Color.red) == SwipeActionTint(Color.red))
        #expect(
            SwipeActionTint(key: "danger-gradient", Color.red.gradient)
                == SwipeActionTint(key: "danger-gradient", Color.blue.gradient)
        )
        #expect(
            SwipeActionTint(key: "danger-gradient", Color.red.gradient)
                != SwipeActionTint(key: "warning-gradient", Color.red.gradient)
        )
        #expect(SwipeActionTint(Color.red.gradient) != SwipeActionTint(Color.red.gradient))
    }

    @Test("action descriptor equality respects tint stability")
    func actionDescriptorEqualityRespectsTintStability() {
        let gradientAction = SwipeAction("Delete", systemImage: "trash", tint: Color.red.gradient) {}
        let colorFirst = stableAction(tint: SwipeActionTint(Color.red))
        let colorSecond = stableAction(tint: SwipeActionTint(Color.red))
        let keyedFirst = stableAction(tint: SwipeActionTint(key: "danger-gradient", Color.red.gradient))
        let keyedSecond = stableAction(tint: SwipeActionTint(key: "danger-gradient", Color.blue.gradient))
        let unkeyedFirst = stableAction(tint: SwipeActionTint(Color.red.gradient))
        let unkeyedSecond = stableAction(tint: SwipeActionTint(Color.red.gradient))

        #expect(gradientAction.title == "Delete")
        #expect(gradientAction.systemImage == "trash")
        #expect(colorFirst == colorSecond)
        #expect(keyedFirst == keyedSecond)
        #expect(unkeyedFirst != unkeyedSecond)
    }

    @Test("template keyed ShapeStyle tint keeps diff eligibility")
    func templateKeyedShapeStyleTintKeepsDiffEligibility() {
        let template = SwipeCellActionTemplate(
            trailing: [
                SwipeActionTemplate<Int>(
                    id: TemplateSlotID.delete,
                    "Delete",
                    systemImage: "trash",
                    tint: SwipeActionTint(key: "delete-gradient", Color.red.gradient)
                ) { _ in }
            ]
        )

        let first = template.resolveActions(for: 7)
        let second = template.resolveActions(for: 7)
        let unkeyedTemplate = SwipeCellActionTemplate(
            trailing: [
                SwipeActionTemplate<Int>(
                    id: TemplateSlotID.delete,
                    "Delete",
                    systemImage: "trash",
                    tint: Color.red.gradient
                ) { _ in }
            ]
        )
        let unkeyedFirst = unkeyedTemplate.resolveActions(for: 7)
        let unkeyedSecond = unkeyedTemplate.resolveActions(for: 7)

        #expect(first.trailing == second.trailing)
        #expect(unkeyedFirst.trailing != unkeyedSecond.trailing)
    }

    @Test("library stable closure wrappers compare by contract")
    func libraryStableClosureWrappersCompareByContract() {
        let firstStable = StableViewClosure<Int, Int> { $0 + 1 }
        let secondStable = StableViewClosure<Int, Int> { $0 + 2 }
        let firstKeyed = KeyedViewClosure(key: "same") { (value: Int) in value + 1 }
        let secondKeyed = KeyedViewClosure(key: "same") { (value: Int) in value + 2 }
        let otherKeyed = KeyedViewClosure(key: "other") { (value: Int) in value + 1 }

        #expect(firstStable == secondStable)
        #expect(firstKeyed == secondKeyed)
        #expect(firstKeyed != otherKeyed)
    }

    @Test("a side keeps at most the first three actions")
    func capsAtThreeActions() {
        let group = SwipeActionGroup(
            side: .trailing,
            actions: [
                SwipeAction("1") {},
                SwipeAction("2") {},
                SwipeAction("3") {},
                SwipeAction("4") {},
            ],
            emitsDiagnostics: false
        )

        #expect(group.count == 3)
        #expect(group.actions.map(\.title) == ["1", "2", "3"])
    }

    @Test("only the outermost action stays destructive")
    func demotesInnerDestructiveActions() {
        let group = SwipeActionGroup(
            side: .trailing,
            actions: [
                SwipeAction("Delete", role: .destructive(.init())) {},
                SwipeAction("Archive", role: .destructive(.init())) {},
                SwipeAction("Flag", role: .destructive(.init())) {},
            ],
            emitsDiagnostics: false
        )

        #expect(group.actions.map(\.role) == [.destructive(.init()), .normal(.immediate), .normal(.immediate)])
        #expect(group.allowsDestructive == true)
    }

    @Test("a side without an outermost destructive does not allow destructive")
    func nonDestructiveSideDoesNotAllowDestructive() {
        let group = SwipeActionGroup(
            side: .leading,
            actions: [SwipeAction("Pin") {}, SwipeAction("Mute") {}]
        )

        #expect(group.allowsDestructive == false)
    }

    @Test("empty side bridges to a disabled configuration")
    func emptySideBridgesToDisabled() {
        let group = SwipeActionGroup(side: .leading, actions: [])
        let config = group.interactionSideConfiguration()

        #expect(group.isEmpty)
        #expect(config == .disabled)
        #expect(config.isEnabled == false)
        #expect(config.normalOpenExtent == 0)
    }

    @Test("open extent is action width times count")
    func openExtentScalesWithCount() {
        let defaultWidth = SwipeActionGroup(
            side: .trailing,
            actions: [SwipeAction("A") {}, SwipeAction("B") {}]
        )
        let customWidth = SwipeActionGroup(
            side: .trailing,
            actions: [SwipeAction("A") {}, SwipeAction("B") {}],
            actionWidth: 90
        )

        #expect(defaultWidth.actionWidth == SwipeActionGroup.defaultActionWidth)
        #expect(defaultWidth.normalOpenExtent == SwipeActionGroup.defaultActionWidth * 2)
        #expect(customWidth.normalOpenExtent == 180)
    }

    @Test("default normal open threshold is half of total action extent")
    func defaultNormalOpenThresholdIsHalfOfTotalActionExtent() {
        let oneAction = SwipeActionGroup(
            side: .leading,
            actions: [SwipeAction("A") {}],
            actionWidth: 80,
            configuration: .iOSDefault
        )
        let twoActions = SwipeActionGroup(
            side: .leading,
            actions: [SwipeAction("A") {}, SwipeAction("B") {}],
            actionWidth: 80,
            configuration: .iOSDefault
        )
        let threeActions = SwipeActionGroup(
            side: .trailing,
            actions: [SwipeAction("A") {}, SwipeAction("B") {}, SwipeAction("C") {}],
            actionWidth: 80,
            configuration: .iOSDefault
        )

        #expect(oneAction.normalOpenThreshold == 40)
        #expect(twoActions.normalOpenThreshold == 80)
        #expect(threeActions.normalOpenThreshold == 120)
        #expect(threeActions.interactionSideConfiguration().normalOpenThreshold == 120)
    }

    @Test("minimum distance normal open threshold does not scale with action count")
    func minimumDistanceNormalOpenThresholdDoesNotScaleWithActionCount() {
        var configuration = SwipeCellConfiguration.iOSDefault
        configuration.geometry.normalOpenCommitThreshold = .distance(1)

        let oneAction = SwipeActionGroup(
            side: .leading,
            actions: [SwipeAction("A") {}],
            actionWidth: 80,
            configuration: configuration
        )
        let threeActions = SwipeActionGroup(
            side: .trailing,
            actions: [SwipeAction("A") {}, SwipeAction("B") {}, SwipeAction("C") {}],
            actionWidth: 80,
            configuration: configuration
        )

        #expect(oneAction.normalOpenThreshold == 1)
        #expect(threeActions.normalOpenThreshold == 1)
        #expect(threeActions.interactionSideConfiguration().normalOpenThreshold == 1)
    }

    @Test("non-positive or non-finite action width falls back to the default")
    func nonPositiveWidthFallsBackToDefault() {
        let zero = SwipeActionGroup(side: .leading, actions: [SwipeAction("A") {}], actionWidth: 0)
        let negative = SwipeActionGroup(side: .leading, actions: [SwipeAction("A") {}], actionWidth: -10)
        let infinite = SwipeActionGroup(side: .leading, actions: [SwipeAction("A") {}], actionWidth: .infinity)

        #expect(zero.actionWidth == SwipeActionGroup.defaultActionWidth)
        #expect(negative.actionWidth == SwipeActionGroup.defaultActionWidth)
        #expect(infinite.actionWidth == SwipeActionGroup.defaultActionWidth)
    }

    @Test("destructive side derives an enabled destructive configuration")
    func destructiveSideDerivesEnabledConfiguration() {
        let group = SwipeActionGroup(
            side: .trailing,
            actions: [SwipeAction("Delete", role: .destructive(.init())) {}],
            actionWidth: 80
        )
        let config = group.interactionSideConfiguration()

        #expect(config.isEnabled)
        #expect(config.normalOpenExtent == 80)
        #expect(config.allowsDestructive == true)
        // Destructive-ready boundary stays distinct from the normal-open boundary.
        #expect(config.destructiveActivationExtent > config.normalOpenExtent)
    }

    @Test("zero container width resolves to a non-destructive configuration without trapping")
    func zeroContainerWidthResolvesWithoutTrapping() {
        let group = SwipeActionGroup(
            side: .trailing,
            actions: [SwipeAction("Delete", role: .destructive(.init())) {}],
            actionWidth: 80
        )
        // A zero width is a pre-layout state, not a misconfiguration: the side stays enabled for normal
        // open but arms no destructive, and crucially does not trip the "cannot fit" diagnostic. A later
        // pass with a real width resolves the activation extent.
        let config = group.interactionSideConfiguration(containerWidth: 0)

        #expect(config.isEnabled)
        #expect(config.normalOpenExtent == 80)
        #expect(config.allowsDestructive == false)
    }

    @Test("configuration bridge maps both sides independently")
    func configurationBridgeMapsBothSides() {
        let leading = SwipeActionGroup(
            side: .leading,
            actions: [SwipeAction("Pin") {}],
            actionWidth: 70
        )
        let trailing = SwipeActionGroup(
            side: .trailing,
            actions: [SwipeAction("Delete", role: .destructive(.init())) {}, SwipeAction("More") {}],
            actionWidth: 70
        )

        let config = SwipeActionGroup.interactionConfiguration(leading: leading, trailing: trailing)

        #expect(config.leading.normalOpenExtent == 70)
        #expect(config.leading.allowsDestructive == false)
        #expect(config.trailing.normalOpenExtent == 140)
        #expect(config.trailing.allowsDestructive == true)
    }

    @Test("automatic destructive default remains old count plus extra width behavior")
    func automaticDestructiveDefaultRemainsOldCountPlusExtraWidthBehavior() {
        let group = SwipeActionGroup(
            side: .trailing,
            actions: [
                SwipeAction("Delete", role: .destructive(.init())) {},
                SwipeAction("More") {},
            ],
            actionWidth: 80,
            configuration: .iOSDefault
        )

        let config = group.interactionSideConfiguration(containerWidth: 320)

        #expect(config.normalOpenExtent == 160)
        #expect(config.normalOpenThreshold == 80)
        #expect(config.destructiveActivationExtent == 280)
        #expect(config.destructiveHoldExtent == 280)
    }

    @Test("open extent plus distance activation resolves from normal open extent")
    func openExtentPlusDistanceActivationResolvesFromNormalOpenExtent() {
        let group = SwipeActionGroup(
            side: .trailing,
            actions: [
                SwipeAction(
                    "Delete",
                    role: .destructive(.init(activation: .openExtentPlusDistance(36)))
                ) {},
                SwipeAction("More") {},
            ],
            actionWidth: 80,
            emitsDiagnostics: false
        )

        let config = group.interactionSideConfiguration(containerWidth: 400)

        #expect(config.normalOpenExtent == 160)
        #expect(config.destructiveActivationExtent == 196)
    }

    @Test("row width fraction activation resolves from container width")
    func rowWidthFractionActivationResolvesFromContainerWidth() {
        let group = SwipeActionGroup(
            side: .trailing,
            actions: [
                SwipeAction(
                    "Delete",
                    role: .destructive(.init(activation: .rowWidthFraction(0.75)))
                ) {},
                SwipeAction("More") {},
            ],
            actionWidth: 80,
            emitsDiagnostics: false
        )

        let config = group.interactionSideConfiguration(containerWidth: 400)

        #expect(config.destructiveActivationExtent == 300)
    }

    @Test("side-specific destructive defaults resolve independently")
    func sideSpecificDestructiveDefaultsResolveIndependently() {
        var configuration = SwipeCellConfiguration.iOSDefault
        configuration.geometry.destructiveActivationDefaults = .init(
            leading: .openExtentPlusDistance(24),
            trailing: .rowWidthFraction(0.8)
        )
        let leading = SwipeActionGroup(
            side: .leading,
            actions: [
                SwipeAction("Delete", role: .destructive(.init())) {},
                SwipeAction("More") {},
            ],
            actionWidth: 50,
            configuration: configuration,
            emitsDiagnostics: false
        )
        let trailing = SwipeActionGroup(
            side: .trailing,
            actions: [
                SwipeAction("Delete", role: .destructive(.init())) {},
                SwipeAction("More") {},
            ],
            actionWidth: 50,
            configuration: configuration,
            emitsDiagnostics: false
        )

        let config = SwipeActionGroup.interactionConfiguration(
            leading: leading,
            trailing: trailing,
            containerWidth: 400
        )

        #expect(config.leading.destructiveActivationExtent == 124)
        #expect(config.trailing.destructiveActivationExtent == 320)
    }

    @Test("per-action activation overrides shared destructive defaults")
    func perActionActivationOverridesSharedDestructiveDefaults() {
        var configuration = SwipeCellConfiguration.iOSDefault
        configuration.geometry.destructiveActivationDefaults = .init(.openExtentPlusDistance(20))
        let group = SwipeActionGroup(
            side: .trailing,
            actions: [
                SwipeAction(
                    "Delete",
                    role: .destructive(.init(activation: .openExtentPlusActionWidths(2)))
                ) {},
                SwipeAction("More") {},
            ],
            actionWidth: 80,
            configuration: configuration,
            emitsDiagnostics: false
        )

        let config = group.interactionSideConfiguration(containerWidth: 400)

        #expect(config.normalOpenExtent == 160)
        #expect(config.destructiveActivationExtent == 320)
    }

    @Test("invalid or below-open destructive activation falls back beyond normal open")
    func invalidOrBelowOpenDestructiveActivationFallsBackBeyondNormalOpen() {
        let belowOpen = SwipeActionGroup(
            side: .trailing,
            actions: [
                SwipeAction(
                    "Delete",
                    role: .destructive(.init(activation: .openExtentPlusDistance(-40)))
                ) {}
            ],
            actionWidth: 80,
            emitsDiagnostics: false
        )
        let invalid = SwipeActionGroup(
            side: .trailing,
            actions: [
                SwipeAction(
                    "Delete",
                    role: .destructive(.init(activation: .rowWidthFraction(.nan)))
                ) {}
            ],
            actionWidth: 80,
            emitsDiagnostics: false
        )

        #expect(belowOpen.interactionSideConfiguration(containerWidth: 400).destructiveActivationExtent == 81)
        #expect(invalid.interactionSideConfiguration(containerWidth: 400).destructiveActivationExtent == 81)
    }

    @Test("layout resolved activation clamps to ninety percent of row width without trapping")
    func layoutResolvedActivationClampsToNinetyPercentWithoutTrapping() {
        let group = SwipeActionGroup(
            side: .trailing,
            actions: [
                SwipeAction(
                    "Delete",
                    role: .destructive(
                        SwipeActionDestructive(
                            activation: .actionWidthMultiplier(6),
                            completion: .directTrigger
                        )
                    )
                ) {},
                SwipeAction("More") {},
            ],
            actionWidth: 80
        )

        let config = group.interactionSideConfiguration(containerWidth: 320)

        #expect(config.destructiveActivationExtent == 288)
        #expect(config.destructiveHoldExtent == 288)
    }
}
