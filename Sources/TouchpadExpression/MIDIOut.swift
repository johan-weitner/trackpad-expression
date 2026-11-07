import CoreMIDI
import Foundation

/// A virtual CoreMIDI source named "Trackpad Expression". DAWs see it as a MIDI input device.
final class MIDIOut {
    private var client = MIDIClientRef()
    private var source = MIDIEndpointRef()

    init() {
        MIDIClientCreateWithBlock("TouchpadExpression" as CFString, &client, nil)
        MIDISourceCreateWithProtocol(client, "Trackpad Expression" as CFString, ._1_0, &source)

        // Keep the same unique ID across launches so the DAW remembers the device.
        let key = "midiUniqueID"
        let saved = Int32(truncatingIfNeeded: UserDefaults.standard.integer(forKey: key))
        if saved == 0 || MIDIObjectSetIntegerProperty(source, kMIDIPropertyUniqueID, saved) != noErr {
            var assigned: Int32 = 0
            MIDIObjectGetIntegerProperty(source, kMIDIPropertyUniqueID, &assigned)
            UserDefaults.standard.set(Int(assigned), forKey: key)
        }
    }

    func sendCC(channel: UInt8, cc: UInt8, value: UInt8) {
        // UMP type 2 = MIDI 1.0 channel voice message, group 0.
        var word: UInt32 = 0x2000_0000
            | (UInt32(0xB0 | (channel & 0x0F)) << 16)
            | (UInt32(cc & 0x7F) << 8)
            | UInt32(value & 0x7F)
        var list = MIDIEventList()
        let packet = MIDIEventListInit(&list, ._1_0)
        // Stamp with the current host time. Timestamp 0 ("now") shows up in DAW MIDI monitors
        // but can be dropped by audio engines that schedule input against the host clock.
        _ = MIDIEventListAdd(&list, MemoryLayout<MIDIEventList>.size, packet, mach_absolute_time(), 1, &word)
        MIDIReceivedEventList(source, &list)
    }
}
