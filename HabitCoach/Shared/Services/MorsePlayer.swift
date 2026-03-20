import Foundation
#if os(iOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

struct MorsePlayer {
    /// Duration of one Morse "unit" in nanoseconds (120ms).
    static let unitDuration: UInt64 = 120_000_000

    private static let morseTable: [Character: String] = [
        "A": ".-",    "B": "-...",  "C": "-.-.",  "D": "-..",
        "E": ".",     "F": "..-.",  "G": "--.",   "H": "....",
        "I": "..",    "J": ".---",  "K": "-.-",   "L": ".-..",
        "M": "--",    "N": "-.",    "O": "---",   "P": ".--.",
        "Q": "--.-",  "R": ".-.",   "S": "...",   "T": "-",
        "U": "..-",   "V": "...-",  "W": ".--",   "X": "-..-",
        "Y": "-.--",  "Z": "--..",
        "0": "-----", "1": ".----", "2": "..---", "3": "...--",
        "4": "....-", "5": ".....", "6": "-....", "7": "--...",
        "8": "---..", "9": "----.",
    ]

    /// Play the given word as Morse code haptics.
    /// Call from a detached Task so it doesn't block the timer.
    static func play(word: String) async {
        let chars = Array(word.uppercased().filter { morseTable[$0] != nil })
        guard !chars.isEmpty else { return }

        for (charIndex, char) in chars.enumerated() {
            guard !Task.isCancelled else { return }
            guard let code = morseTable[char] else { continue }

            for (elementIndex, element) in code.enumerated() {
                guard !Task.isCancelled else { return }
                await MainActor.run { playTap(isDash: element == "-") }

                // Wait for the element duration (dot=1 unit, dash=3 units)
                let tapDuration = element == "-" ? unitDuration * 3 : unitDuration
                try? await Task.sleep(nanoseconds: tapDuration)

                // Intra-character gap (1 unit) — skip after last element
                if elementIndex < code.count - 1 {
                    try? await Task.sleep(nanoseconds: unitDuration)
                }
            }

            // Inter-character gap (3 units) — skip after last character
            if charIndex < chars.count - 1 {
                try? await Task.sleep(nanoseconds: unitDuration * 3)
            }
        }
    }

    @MainActor
    private static func playTap(isDash: Bool) {
        #if os(watchOS)
        WKInterfaceDevice.current().play(isDash ? .notification : .click)
        #elseif os(iOS)
        if isDash {
            let gen = UIImpactFeedbackGenerator(style: .heavy)
            gen.impactOccurred()
        } else {
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred()
        }
        #endif
    }

    /// Derive default Morse word from a profile name (first 4 alpha chars, uppercased).
    static func defaultWord(from name: String) -> String {
        let alpha = name.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        return String(String(alpha).prefix(4)).uppercased()
    }

    /// Estimated duration in seconds for a given word.
    static func estimatedDuration(for word: String) -> Double {
        let chars = Array(word.uppercased().filter { morseTable[$0] != nil })
        guard !chars.isEmpty else { return 0 }
        var units = 0
        for (i, char) in chars.enumerated() {
            guard let code = morseTable[char] else { continue }
            for (j, el) in code.enumerated() {
                units += el == "-" ? 3 : 1
                if j < code.count - 1 { units += 1 } // intra-char gap
            }
            if i < chars.count - 1 { units += 3 } // inter-char gap
        }
        return Double(units) * 0.12 // 120ms per unit
    }
}
