import Foundation
import CoreAudio

private enum TestError: Error { case assertion(String), simulated }
private func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw TestError.assertion(message) }
}
private func expectFailure(_ operation: () async throws -> Void) async throws {
    do { try await operation() }
    catch { return }
    throw TestError.assertion("Expected operation to fail")
}

@main
struct CoreAudioLogicTests {
    static func main() async {
        do {
            let inputs = [InputDevice(id: 10, name: "One"), InputDevice(id: 20, name: "Two")]
            var writes: [AudioDeviceID] = []
            var current: AudioDeviceID = 10
            let result = try await CoreAudioClient.switchAndVerify(20, devices: { inputs },
                readDefault: { current }, writeDefault: { writes.append($0); current = $0 }, delayNanoseconds: 0)
            try require(result == 20 && writes == [20], "Immediate success must write target and read it back")
            print("PASS immediate readback confirmation")

            var reads = 0
            writes = []
            let delayed = try await CoreAudioClient.switchAndVerify(20, devices: { inputs },
                readDefault: { reads += 1; return reads < 3 ? 10 : 20 },
                writeDefault: { writes.append($0) }, attempts: 4, delayNanoseconds: 0)
            try require(delayed == 20 && reads == 3 && writes == [20], "Delayed confirmation must poll without repeating write")
            print("PASS delayed readback confirmation")

            // Real HAL changes are asynchronous. This uses production retry defaults
            // and becomes visible only after the previous 250ms timeout.
            reads = 0
            let later = try await CoreAudioClient.switchAndVerify(20, devices: { inputs },
                readDefault: { reads += 1; return reads < 8 ? 10 : 20 }, writeDefault: { _ in })
            try require(later == 20 && reads == 8, "Production timeout must allow asynchronous changes beyond 250ms")
            print("PASS production retry defaults permit confirmation after 350ms")

            writes = []
            let ineligible = [InputDevice(id: 30, name: "App-owned virtual input", canBeDefaultInput: false)]
            try await expectFailure {
                _ = try await CoreAudioClient.switchAndVerify(30, devices: { ineligible }, readDefault: { 10 },
                    writeDefault: { writes.append($0) }, delayNanoseconds: 0)
            }
            try require(writes.isEmpty, "A stream-capable device that cannot be default input must never be written")
            print("PASS ineligible virtual input rejected before write")

            let mixed = [InputDevice(id: 5, name: "Virtual", canBeDefaultInput: false)] + inputs
            try require(CoreAudioClient.nextInput(in: mixed, current: 10)?.id == 20,
                        "Cycling must skip ineligible devices")
            try require(CoreAudioClient.nextInput(in: mixed, current: 20)?.id == 10,
                        "Cycling must wrap to first eligible device")
            try require(CoreAudioClient.nextInput(in: mixed, current: 999)?.id == 10,
                        "Unknown current input must select first eligible device")
            try require(CoreAudioClient.nextInput(in: ineligible, current: 10) == nil,
                        "All-ineligible list must have no next input")
            try require(CoreAudioClient.nextInput(in: [], current: 10) == nil,
                        "Empty list must have no next input")
            print("PASS cycle eligibility, wrap, absent current, all-ineligible and empty lists")

            reads = 0
            writes = []
            try await expectFailure {
                _ = try await CoreAudioClient.switchAndVerify(20, devices: { inputs },
                    readDefault: { reads += 1; return 10 }, writeDefault: { writes.append($0) },
                    attempts: 3, delayNanoseconds: 0)
            }
            try require(reads == 3 && writes == [20], "An accepted write with mismatching readback must fail after bounded retries")
            print("PASS accepted write with wrong readback is rejected")

            writes = []
            try await expectFailure {
                _ = try await CoreAudioClient.switchAndVerify(0, devices: { inputs }, readDefault: { 10 },
                    writeDefault: { writes.append($0) }, delayNanoseconds: 0)
            }
            try require(writes.isEmpty, "Unavailable device must never be written")
            print("PASS unavailable device rejected before write")

            reads = 0
            try await expectFailure {
                _ = try await CoreAudioClient.switchAndVerify(20, devices: { inputs },
                    readDefault: { reads += 1; return 20 }, writeDefault: { _ in throw TestError.simulated }, delayNanoseconds: 0)
            }
            try require(reads == 0, "Write failure must propagate without pretending success")
            print("PASS write failure propagation")

            try await expectFailure {
                _ = try await CoreAudioClient.switchAndVerify(20, devices: { inputs },
                    readDefault: { throw TestError.simulated }, writeDefault: { _ in }, delayNanoseconds: 0)
            }
            print("PASS read failure propagation")
            writes = []
            try await expectFailure {
                _ = try await CoreAudioClient.switchAndVerify(20, devices: { throw TestError.simulated },
                    readDefault: { 20 }, writeDefault: { writes.append($0) }, delayNanoseconds: 0)
            }
            try require(writes.isEmpty, "Enumeration failure must prevent mutation")
            print("PASS enumeration failure propagation")
            print("PASS 14 checks of production switching and cycling")
        } catch {
            fputs("FAIL \(error)\n", stderr)
            exit(1)
        }
    }
}
