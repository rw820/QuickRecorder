@preconcurrency import AVFoundation

extension AVAudioPCMBuffer {
    func ownedCopy() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameLength
        ) else {
            return nil
        }
        copy.frameLength = frameLength

        let sourceBuffers = UnsafeMutableAudioBufferListPointer(
            UnsafeMutablePointer(mutating: audioBufferList)
        )
        let destinationBuffers = UnsafeMutableAudioBufferListPointer(
            copy.mutableAudioBufferList
        )

        for (source, destination) in zip(
            sourceBuffers,
            destinationBuffers
        ) {
            guard
                let sourceData = source.mData,
                let destinationData = destination.mData
            else {
                continue
            }
            memcpy(
                destinationData,
                sourceData,
                Int(min(source.mDataByteSize, destination.mDataByteSize))
            )
        }
        return copy
    }
}
