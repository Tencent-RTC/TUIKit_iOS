import Foundation
import AudioToolbox

final class TtsOpusDecoder {
    private static let maximumFrameSamples = 1920
    private static let maximumPacketBytes = 64 * 1024
    private static let maximumConversionIterations = 4
    private static let inputTemporarilyEmpty: OSStatus = 1
    private static let bitsPerByte: UInt32 = 8
    private static let opusClockRate: UInt32 = 48000
    private static let configurationShift: UInt8 = 3
    private static let packetCodeMask: UInt8 = 3
    private static let frameCountMask: UInt8 = 63
    private static let celtConfigurationStart: UInt8 = 16
    private static let hybridConfigurationStart: UInt8 = 12
    private static let celtFrameSamples: UInt32 = 120
    private static let silkFrameSamples: UInt32 = 480
    private static let maximumSilkFrameSamples: UInt32 = 2880

    private var converter: AudioConverterRef?
    private var currentInput: PacketInput?
    private var hasReachedEndOfStream = false

    init?() {
        converter = Self.createConverter()
        guard converter != nil else { return nil }
    }

    deinit {
        if let converter {
            AudioConverterDispose(converter)
        }
    }

    func decode(packet: Data) -> [Int16]? {
        guard !hasReachedEndOfStream, let frames = Self.frameCount(for: packet) else { return nil }
        return convert(input: PacketInput(packet: packet, frames: frames, isEndOfStream: false))
    }

    func finish() -> [Int16]? {
        guard !hasReachedEndOfStream else { return nil }
        let output = convert(input: PacketInput(packet: nil, frames: 0, isEndOfStream: true))
        hasReachedEndOfStream = true
        return output
    }

    func reset() {
        if let converter {
            AudioConverterDispose(converter)
        }
        converter = nil
        currentInput = nil
        hasReachedEndOfStream = false
        converter = Self.createConverter()
    }

    private func convert(input: PacketInput) -> [Int16]? {
        guard let converter else { return nil }
        let previousInput = currentInput
        currentInput = input
        defer { withExtendedLifetime(previousInput) {} }
        var output: [Int16] = []
        for _ in 0 ..< Self.maximumConversionIterations {
            let result = convertBuffer(converter: converter, input: input)
            guard result.status == noErr || result.status == Self.inputTemporarilyEmpty else {
                TtsPlaybackLog("system Opus decode failed: \(result.status)")
                reset()
                return nil
            }
            output.append(contentsOf: result.samples)
            if result.status == Self.inputTemporarilyEmpty || result.samples.isEmpty {
                return output
            }
        }
        TtsPlaybackLog("system Opus conversion exceeded output limit")
        reset()
        return nil
    }

    private func convertBuffer(converter: AudioConverterRef, input: PacketInput) -> (status: OSStatus, samples: [Int16]) {
        var samples = [Int16](repeating: 0, count: Self.maximumFrameSamples)
        var producedFrames: UInt32 = 0
        let status = samples.withUnsafeMutableBufferPointer { buffer -> OSStatus in
            var buffers = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(
                mNumberChannels: TtsAudioConstants.channels,
                mDataByteSize: UInt32(buffer.count * MemoryLayout<Int16>.size),
                mData: buffer.baseAddress
            ))
            var frames = UInt32(buffer.count)
            let status = AudioConverterFillComplexBuffer(
                converter, Self.supplyInput, Unmanaged.passUnretained(input).toOpaque(),
                &frames, &buffers, nil
            )
            producedFrames = min(frames, buffers.mBuffers.mDataByteSize / UInt32(MemoryLayout<Int16>.size))
            return status
        }
        guard producedFrames <= UInt32(samples.count) else {
            return (kAudio_ParamError, [])
        }
        return (status, Array(samples.prefix(Int(producedFrames))))
    }

    private static func createConverter() -> AudioConverterRef? {
        var input = AudioStreamBasicDescription()
        input.mSampleRate = Double(TtsAudioConstants.sampleRate)
        input.mFormatID = kAudioFormatOpus
        input.mChannelsPerFrame = TtsAudioConstants.channels
        var output = AudioStreamBasicDescription()
        output.mSampleRate = input.mSampleRate
        output.mFormatID = kAudioFormatLinearPCM
        output.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
        output.mBytesPerPacket = UInt32(MemoryLayout<Int16>.size)
        output.mFramesPerPacket = 1
        output.mBytesPerFrame = output.mBytesPerPacket
        output.mChannelsPerFrame = input.mChannelsPerFrame
        output.mBitsPerChannel = output.mBytesPerFrame * Self.bitsPerByte
        var codec = AudioClassDescription(
            mType: kAudioDecoderComponentType, mSubType: kAudioFormatOpus,
            mManufacturer: kAppleSoftwareAudioCodecManufacturer
        )
        var converter: AudioConverterRef?
        let status = AudioConverterNewSpecific(&input, &output, 1, &codec, &converter)
        guard status == noErr else {
            if let converter { AudioConverterDispose(converter) }
            TtsPlaybackLog("system Opus decoder creation failed: \(status)")
            return nil
        }
        return converter
    }

    private static func frameCount(for packet: Data) -> UInt32? {
        guard !packet.isEmpty, packet.count <= Self.maximumPacketBytes else { return nil }
        return packet.withUnsafeBytes { raw -> UInt32? in
            let bytes = raw.bindMemory(to: UInt8.self)
            let configuration = bytes[0] >> Self.configurationShift
            let packetCode = bytes[0] & Self.packetCodeMask
            var frameSamples: UInt32
            if configuration >= Self.celtConfigurationStart {
                frameSamples = Self.celtFrameSamples << UInt32(configuration & Self.packetCodeMask)
            } else if configuration >= Self.hybridConfigurationStart {
                frameSamples = Self.silkFrameSamples << UInt32(configuration & 1)
            } else {
                let durationCode = configuration & Self.packetCodeMask
                frameSamples = durationCode == Self.packetCodeMask
                    ? Self.maximumSilkFrameSamples : Self.silkFrameSamples << UInt32(durationCode)
            }
            let frames: UInt32
            if packetCode == Self.packetCodeMask {
                guard bytes.count > 1 else { return nil }
                frames = UInt32(bytes[1] & Self.frameCountMask)
            } else {
                frames = packetCode == 0 ? 1 : 2
            }
            let count = frameSamples * frames * UInt32(TtsAudioConstants.sampleRate) / Self.opusClockRate
            guard count > 0, count <= UInt32(Self.maximumFrameSamples) else { return nil }
            return count
        }
    }

    private static let supplyInput: AudioConverterComplexInputDataProc = { _, count, buffers, descriptions, context in
        count.pointee = 0
        buffers.pointee.mNumberBuffers = 1
        buffers.pointee.mBuffers = AudioBuffer(
            mNumberChannels: TtsAudioConstants.channels, mDataByteSize: 0, mData: nil
        )
        descriptions?.pointee = nil
        guard let context else { return kAudio_ParamError }
        let input = Unmanaged<PacketInput>.fromOpaque(context).takeUnretainedValue()
        guard !input.hasProvidedPacket, let packet = input.packet else {
            return input.isEndOfStream ? noErr : TtsOpusDecoder.inputTemporarilyEmpty
        }
        input.hasProvidedPacket = true
        count.pointee = 1
        buffers.pointee.mBuffers.mData = UnsafeMutableRawPointer(mutating: packet.bytes)
        buffers.pointee.mBuffers.mDataByteSize = UInt32(packet.length)
        descriptions?.pointee = input.description
        return noErr
    }

    private final class PacketInput {
        let packet: NSData?
        let description: UnsafeMutablePointer<AudioStreamPacketDescription>
        let isEndOfStream: Bool
        var hasProvidedPacket = false

        init(packet: Data?, frames: UInt32, isEndOfStream: Bool) {
            self.packet = packet.map { $0 as NSData }
            self.isEndOfStream = isEndOfStream
            description = .allocate(capacity: 1)
            description.initialize(to: AudioStreamPacketDescription(
                mStartOffset: 0, mVariableFramesInPacket: frames,
                mDataByteSize: UInt32(packet?.count ?? 0)
            ))
        }

        deinit {
            description.deinitialize(count: 1)
            description.deallocate()
        }
    }
}
