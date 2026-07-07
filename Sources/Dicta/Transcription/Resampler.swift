import AVFoundation

/// Convierte los buffers del micrófono (48/44.1 kHz, 1-2 canales) al formato
/// que exige Whisper: 16 kHz, mono, Float32. Mantiene estado entre buffers
/// para que la conversión de tasa sea continua.
final class Resampler {
    static let whisperSampleRate: Double = 16000

    private let converter: AVAudioConverter?
    private let outputFormat: AVAudioFormat

    init(inputFormat: AVAudioFormat) {
        outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                     sampleRate: Self.whisperSampleRate,
                                     channels: 1,
                                     interleaved: false)!
        if inputFormat.sampleRate == outputFormat.sampleRate,
           inputFormat.channelCount == 1,
           inputFormat.commonFormat == .pcmFormatFloat32 {
            converter = nil
        } else {
            converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        }
    }

    func convert(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard let converter else {
            guard let data = buffer.floatChannelData else { return [] }
            return Array(UnsafeBufferPointer(start: data[0], count: Int(buffer.frameLength)))
        }
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return [] }

        var consumed = false
        let status = converter.convert(to: out, error: nil) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, let data = out.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: data[0], count: Int(out.frameLength)))
    }
}
