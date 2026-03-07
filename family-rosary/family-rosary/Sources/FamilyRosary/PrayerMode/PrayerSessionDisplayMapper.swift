import Foundation

enum SessionPrayerType: Equatable {
    case apostlesCreed
    case ourFather
    case hailMary
    case gloryBe
    case fatima
    case hailHolyQueen
    case unknown
}

struct PrayerSessionDisplayMapper {
    func map(
        rosaryStepIndex: Int,
        prayerType: SessionPrayerType,
        mode: PrayerMode,
        style: PrayerStyle,
        promptTitle: String?
    ) -> PrayerSessionDisplayState {
        let boundedStepIndex = max(1, rosaryStepIndex)

        return PrayerSessionDisplayState(
            sectionTitle: sectionTitle(forStepIndex: boundedStepIndex),
            prayerTitle: prayerTitle(for: prayerType),
            countText: countText(forStepIndex: boundedStepIndex, prayerType: prayerType),
            rolePrompt: rolePrompt(
                forStepIndex: boundedStepIndex,
                prayerType: prayerType,
                mode: mode,
                style: style,
                promptTitle: promptTitle
            ),
            isPaused: false
        )
    }

    func prayerType(for promptText: String) -> SessionPrayerType {
        if promptText.hasPrefix("I believe in God") {
            return .apostlesCreed
        }
        if promptText.hasPrefix("Our Father") {
            return .ourFather
        }
        if promptText.hasPrefix("Hail Mary") {
            return .hailMary
        }
        if promptText.hasPrefix("Glory be") {
            return .gloryBe
        }
        if promptText.hasPrefix("O my Jesus") {
            return .fatima
        }
        if promptText.hasPrefix("Hail, holy Queen") {
            return .hailHolyQueen
        }

        return .unknown
    }

    private func sectionTitle(forStepIndex stepIndex: Int) -> String {
        if stepIndex <= 12 {
            return "Opening Prayers"
        }
        if stepIndex >= 138 {
            return "Closing Prayers"
        }
        return "1st Decade"
    }

    private func prayerTitle(for prayerType: SessionPrayerType) -> String {
        switch prayerType {
        case .apostlesCreed:
            return "Apostles' Creed"
        case .ourFather:
            return "Our Father"
        case .hailMary:
            return "Hail Mary"
        case .gloryBe:
            return "Glory Be"
        case .fatima:
            return "Fatima Prayer"
        case .hailHolyQueen:
            return "Hail Holy Queen"
        case .unknown:
            return "Prayer"
        }
    }

    private func countText(forStepIndex stepIndex: Int, prayerType: SessionPrayerType) -> String? {
        guard prayerType == .hailMary else {
            return nil
        }

        guard let hailNumber = hailMaryOrdinalByStep[stepIndex] else {
            return nil
        }

        if hailNumber <= 3 {
            return "\(hailNumber) of 3"
        }

        let decadeIndex = (hailNumber - 4) % 10 + 1
        return "\(decadeIndex) of 10"
    }

    private func rolePrompt(
        forStepIndex stepIndex: Int,
        prayerType: SessionPrayerType,
        mode: PrayerMode,
        style: PrayerStyle,
        promptTitle: String?
    ) -> String? {
        guard mode == .interactive else {
            return nil
        }

        if prayerType == .fatima {
            return "Pray together"
        }

        if let promptTitle {
            let normalized = promptTitle.lowercased()
            if normalized.contains("your turn") {
                return "Now your turn"
            }
            if normalized.contains("listen") {
                return "Now listen"
            }
            if normalized.contains("together") {
                return "Pray together"
            }
        }

        guard let step = sequenceStepByIndex[stepIndex] else {
            return nil
        }

        guard step.segmentRole != .single else {
            return "Pray together"
        }

        let userTurn: Bool
        switch style {
        case .alwaysLead:
            userTurn = step.segmentRole == .lead
        case .alwaysRespond:
            userTurn = step.segmentRole == .response
        case .alternateIStart:
            if step.pairIndex.isMultiple(of: 2) {
                userTurn = step.segmentRole == .response
            } else {
                userTurn = step.segmentRole == .lead
            }
        case .alternateIRespond:
            if step.pairIndex.isMultiple(of: 2) {
                userTurn = step.segmentRole == .lead
            } else {
                userTurn = step.segmentRole == .response
            }
        }

        return userTurn ? "Now your turn" : "Now listen"
    }
}

private enum SequenceSegmentRole {
    case lead
    case response
    case single
}

private struct SequenceStep {
    let prayerType: SessionPrayerType
    let segmentRole: SequenceSegmentRole
    let pairIndex: Int
}

private let sequenceStepByIndex: [Int: SequenceStep] = {
    var result: [Int: SequenceStep] = [:]
    let sequence = RosarySequenceBuilder.makeStandardRosary()

    var pairIndex = 0

    for (zeroBasedIndex, step) in sequence.enumerated() {
        let stepIndex = zeroBasedIndex + 1
        switch step {
        case .apostlesCreedLead:
            pairIndex += 1
            result[stepIndex] = SequenceStep(prayerType: .apostlesCreed, segmentRole: .lead, pairIndex: pairIndex)
        case .apostlesCreedResponse:
            result[stepIndex] = SequenceStep(prayerType: .apostlesCreed, segmentRole: .response, pairIndex: pairIndex)
        case .ourFatherLead:
            pairIndex += 1
            result[stepIndex] = SequenceStep(prayerType: .ourFather, segmentRole: .lead, pairIndex: pairIndex)
        case .ourFatherResponse:
            result[stepIndex] = SequenceStep(prayerType: .ourFather, segmentRole: .response, pairIndex: pairIndex)
        case .hailMaryLead:
            pairIndex += 1
            result[stepIndex] = SequenceStep(prayerType: .hailMary, segmentRole: .lead, pairIndex: pairIndex)
        case .hailMaryResponse:
            result[stepIndex] = SequenceStep(prayerType: .hailMary, segmentRole: .response, pairIndex: pairIndex)
        case .gloryBeLead:
            pairIndex += 1
            result[stepIndex] = SequenceStep(prayerType: .gloryBe, segmentRole: .lead, pairIndex: pairIndex)
        case .gloryBeResponse:
            result[stepIndex] = SequenceStep(prayerType: .gloryBe, segmentRole: .response, pairIndex: pairIndex)
        case .fatima:
            result[stepIndex] = SequenceStep(prayerType: .fatima, segmentRole: .single, pairIndex: pairIndex)
        case .hailHolyQueenLead:
            pairIndex += 1
            result[stepIndex] = SequenceStep(prayerType: .hailHolyQueen, segmentRole: .lead, pairIndex: pairIndex)
        case .hailHolyQueenResponse:
            result[stepIndex] = SequenceStep(prayerType: .hailHolyQueen, segmentRole: .response, pairIndex: pairIndex)
        }
    }

    return result
}()

private let hailMaryOrdinalByStep: [Int: Int] = {
    var result: [Int: Int] = [:]
    var currentHail = 0

    for (zeroBasedIndex, step) in RosarySequenceBuilder.makeStandardRosary().enumerated() {
        if step == .hailMaryLead {
            currentHail += 1
            result[zeroBasedIndex + 1] = currentHail
        } else if step == .hailMaryResponse {
            result[zeroBasedIndex + 1] = currentHail
        }
    }

    return result
}()
