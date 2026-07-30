@preconcurrency import AVFoundation
import CoreMedia

extension CMSampleBuffer {
    var ownedPCMBuffer: AVAudioPCMBuffer? {
        try? withAudioBufferList { audioBufferList, _ in
            guard
                let description = formatDescription,
                let basic = description.audioStreamBasicDescription,
                let format = AVAudioFormat(
                    standardFormatWithSampleRate: basic.mSampleRate,
                    channels: basic.mChannelsPerFrame
                ),
                let borrowed = AVAudioPCMBuffer(
                    pcmFormat: format,
                    bufferListNoCopy: audioBufferList.unsafePointer
                )
            else {
                return nil
            }
            return borrowed.ownedCopy()
        }
    }
}
