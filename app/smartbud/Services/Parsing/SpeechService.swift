//
//  SpeechService.swift
//  smartbud
//
//  One-shot speech recognition for hands-free entry. Transcription is handed
//  to `ExpenseTextParser` by the caller. Ported from SmartExpense.
//

import Speech
import AVFoundation
import Observation

@MainActor
@Observable
final class SpeechService {
    var isRecording = false
    var errorMessage: String?

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    init() {
        // Follow the app language; fall back to English for other locales.
        let identifier = Locale.appLocale.identifier
        let candidates = [identifier, "zh-CN", "en-US"]
        recognizer = candidates.lazy.compactMap { SFSpeechRecognizer(locale: Locale(identifier: $0)) }.first
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startRecording(completion: @escaping (String) -> Void) {
        guard !audioEngine.isRunning else { return }
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = String.appLocalized("语音识别不可用，请检查网络或系统设置。")
            return
        }

        task?.cancel()
        task = nil

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = String.appLocalized("无法开始录音。")
            return
        }

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { return }
        request.shouldReportPartialResults = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let error {
                self?.errorMessage = error.localizedDescription
                self?.stopRecording()
                return
            }
            if let result, result.isFinal {
                completion(result.bestTranscription.formattedString)
                self?.stopRecording()
            }
        }

        let input = audioEngine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            errorMessage = String.appLocalized("无法启动录音。")
        }
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        isRecording = false
    }
}
