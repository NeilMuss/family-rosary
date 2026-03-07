import Foundation

enum PrayerType: Equatable {
    case apostlesCreedLead
    case apostlesCreedResponse
    case ourFatherLead
    case ourFatherResponse
    case hailMaryLead
    case hailMaryResponse
    case gloryBeLead
    case gloryBeResponse
    case fatima
    case hailHolyQueenLead
    case hailHolyQueenResponse
}

struct RosarySequenceBuilder {
    static func makeStandardRosary() -> [PrayerType] {
        var sequence: [PrayerType] = []

        // Intro
        sequence.append(.apostlesCreedLead)
        sequence.append(.apostlesCreedResponse)

        sequence.append(.ourFatherLead)
        sequence.append(.ourFatherResponse)

        for _ in 0..<3 {
            sequence.append(.hailMaryLead)
            sequence.append(.hailMaryResponse)
        }

        sequence.append(.gloryBeLead)
        sequence.append(.gloryBeResponse)

        // 5 Decades
        for _ in 0..<5 {
            sequence.append(.ourFatherLead)
            sequence.append(.ourFatherResponse)

            for _ in 0..<10 {
                sequence.append(.hailMaryLead)
                sequence.append(.hailMaryResponse)
            }

            sequence.append(.gloryBeLead)
            sequence.append(.gloryBeResponse)

            sequence.append(.fatima)
        }

        // Closing
        sequence.append(.hailHolyQueenLead)
        sequence.append(.hailHolyQueenResponse)

        return sequence
    }
}
