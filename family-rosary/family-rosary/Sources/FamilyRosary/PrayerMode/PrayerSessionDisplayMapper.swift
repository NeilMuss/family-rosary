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
        if promptText.hasPrefix("Hail, holy Queen")
            || promptText.hasPrefix("Pray for us")
            || promptText.hasPrefix("That we may be made worthy") {
            return .hailHolyQueen
        }

        return .unknown
    }

    func decadeLabel(for index: Int) -> String {
        guard let decadeNumber = decadeNumberByStep[index] else {
            return "Opening Prayers"
        }

        return "\(ordinalLabel(for: decadeNumber)) Decade"
    }

    private func sectionTitle(forStepIndex stepIndex: Int) -> String {
        if stepIndex <= 12 {
            return "Opening Prayers"
        }
        if decadeNumberByStep[stepIndex] != nil {
            return decadeLabel(for: stepIndex)
        }
        if stepIndex >= 138 {
            return "Closing Prayers"
        }
        return "Prayer"
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
            if normalized.contains("continuing for you") {
                return "Continuing for you"
            }
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

        let policy = PrayerTurnPolicy(style: style)
        switch policy.speaker(for: step.segmentRole) {
        case .user:
            return "Now your turn"
        case .partner:
            return "Now listen"
        case .prayTogether:
            return "Pray together"
        }
    }
}

private func ordinalLabel(for number: Int) -> String {
    switch number {
    case 1:
        return "1st"
    case 2:
        return "2nd"
    case 3:
        return "3rd"
    case 4:
        return "4th"
    case 5:
        return "5th"
    default:
        return "\(number)th"
    }
}

private struct SequenceStep {
    let segmentRole: PrayerSegmentRole
}

private let sequenceStepByIndex: [Int: SequenceStep] = {
    var result: [Int: SequenceStep] = [:]
    let sequence = RosarySequenceBuilder.makeStandardRosary()

    for (zeroBasedIndex, step) in sequence.enumerated() {
        let stepIndex = zeroBasedIndex + 1
        switch step {
        case .apostlesCreedLead:
            result[stepIndex] = SequenceStep(segmentRole: .lead)
        case .apostlesCreedResponse:
            result[stepIndex] = SequenceStep(segmentRole: .response)
        case .ourFatherLead:
            result[stepIndex] = SequenceStep(segmentRole: .lead)
        case .ourFatherResponse:
            result[stepIndex] = SequenceStep(segmentRole: .response)
        case .hailMaryLead:
            result[stepIndex] = SequenceStep(segmentRole: .lead)
        case .hailMaryResponse:
            result[stepIndex] = SequenceStep(segmentRole: .response)
        case .gloryBeLead:
            result[stepIndex] = SequenceStep(segmentRole: .lead)
        case .gloryBeResponse:
            result[stepIndex] = SequenceStep(segmentRole: .response)
        case .fatima:
            result[stepIndex] = SequenceStep(segmentRole: .unison)
        case .hailHolyQueenOpeningLead:
            result[stepIndex] = SequenceStep(segmentRole: .lead)
        case .hailHolyQueenResponse:
            result[stepIndex] = SequenceStep(segmentRole: .response)
        case .hailHolyQueenClosingLead:
            result[stepIndex] = SequenceStep(segmentRole: .lead)
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

private let decadeNumberByStep: [Int: Int] = {
    var result: [Int: Int] = [:]
    var currentDecadeNumber = 0

    for (zeroBasedIndex, step) in RosarySequenceBuilder.makeStandardRosary().enumerated() {
        let stepIndex = zeroBasedIndex + 1

        if step == .ourFatherLead && stepIndex > 12 && currentDecadeNumber < 5 {
            currentDecadeNumber += 1
        }

        guard (1...5).contains(currentDecadeNumber) else {
            continue
        }

        switch step {
        case .ourFatherLead,
             .ourFatherResponse,
             .hailMaryLead,
             .hailMaryResponse,
             .gloryBeLead,
             .gloryBeResponse,
             .fatima:
            result[stepIndex] = currentDecadeNumber
        default:
            break
        }
    }

    return result
}()
