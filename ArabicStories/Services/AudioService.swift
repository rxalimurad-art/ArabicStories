//
//  AudioService.swift
//  Hikaya
//  Audio narration with word-by-word highlighting support
//

import Foundation
import AVFoundation
import Combine

@Observable
class AudioService: NSObject {
    static let shared = AudioService()
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    // Published state
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var progress: Double = 0.0
    
    // Word highlighting
    var currentWordIndex: Int = -1
    var wordTimings: [WordTiming] = []
    
    // Callbacks
    var onWordHighlighted: ((Int, WordTiming) -> Void)?
    var onPlaybackFinished: (() -> Void)?
    var onPlaybackError: ((Error) -> Void)?
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Audio session setup error: \(error)")
        }
    }
    
    // MARK: - Playback Control
    
    func loadAudio(from urlString: String, wordTimings: [WordTiming] = []) async throws {
        // Check if it's a base64 data URI
        if urlString.hasPrefix("data:audio") {
            try await loadAudioFromBase64(urlString, wordTimings: wordTimings)
            return
        }
        
        // Regular URL
        guard let url = URL(string: urlString) else {
            throw AudioError.invalidURL
        }
        
        try await loadAudio(from: url, wordTimings: wordTimings)
    }
    
    func loadAudio(from url: URL, wordTimings: [WordTiming] = []) async throws {
        stop()
        
        self.wordTimings = wordTimings
        
        // Check if local file or remote URL
        if url.isFileURL {
            player = try AVAudioPlayer(contentsOf: url)
        } else {
            // Download remote audio
            let (localURL, _) = try await URLSession.shared.download(from: url)
            player = try AVAudioPlayer(contentsOf: localURL)
        }
        
        player?.delegate = self
        player?.prepareToPlay()
        
        duration = player?.duration ?? 0
        currentTime = 0
        progress = 0
        currentWordIndex = -1
    }
    
    private func loadAudioFromBase64(_ dataURI: String, wordTimings: [WordTiming]) async throws {
        stop()
        
        self.wordTimings = wordTimings
        
        // Parse data URI: data:audio/x-m4a;base64,AAAA...
        guard let commaIndex = dataURI.firstIndex(of: ",") else {
            throw AudioError.invalidBase64Data
        }
        
        let base64String = String(dataURI[dataURI.index(after: commaIndex)...])
        
        guard let audioData = Data(base64Encoded: base64String) else {
            throw AudioError.invalidBase64Data
        }
        
        // Try to play directly from data
        do {
            player = try AVAudioPlayer(data: audioData)
        } catch {
            // If direct playback fails, save to temp file and try again
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_audio_\(UUID().uuidString).m4a")
            try audioData.write(to: tempURL)
            player = try AVAudioPlayer(contentsOf: tempURL)
        }
        
        player?.delegate = self
        player?.prepareToPlay()
        
        duration = player?.duration ?? 0
        currentTime = 0
        progress = 0
        currentWordIndex = -1
        
        print("✅ Loaded base64 audio, duration: \(duration)s")
    }
    
    func loadAudio(from data: Data, wordTimings: [WordTiming] = []) throws {
        stop()
        
        self.wordTimings = wordTimings
        player = try AVAudioPlayer(data: data)
        player?.delegate = self
        player?.prepareToPlay()
        
        duration = player?.duration ?? 0
        currentTime = 0
        progress = 0
        currentWordIndex = -1
    }
    
    func play() {
        player?.play()
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        stopTimer()
        currentTime = 0
        progress = 0
        currentWordIndex = -1
    }
    
    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
        progress = duration > 0 ? time / duration : 0
        updateCurrentWord()
    }
    
    func seekToWord(at index: Int) {
        guard index < wordTimings.count else { return }
        let timing = wordTimings[index]
        seek(to: timing.startTime)
    }
    
    // MARK: - Timer & Word Highlighting
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updatePlaybackState()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updatePlaybackState() {
        guard let player = player else { return }
        
        currentTime = player.currentTime
        progress = duration > 0 ? currentTime / duration : 0
        
        // Update current word based on timing
        updateCurrentWord()
    }
    
    private func updateCurrentWord() {
        let newIndex = wordTimings.firstIndex { timing in
            currentTime >= timing.startTime && currentTime <= timing.endTime
        } ?? -1
        
        if newIndex != currentWordIndex && newIndex >= 0 {
            currentWordIndex = newIndex
            onWordHighlighted?(newIndex, wordTimings[newIndex])
        }
    }
    
    // MARK: - Speed Control
    
    var playbackRate: Float {
        get { player?.rate ?? 1.0 }
        set {
            player?.rate = newValue
            player?.enableRate = true
        }
    }
    
    func setSpeed(_ speed: AudioSpeed) {
        playbackRate = speed.rawValue
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        stopTimer()
        currentWordIndex = -1
        onPlaybackFinished?()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            onPlaybackError?(error)
        }
    }
}

// MARK: - Audio Errors

enum AudioError: Error {
    case invalidURL
    case invalidBase64Data
    case playbackFailed
}

// MARK: - Audio Speed

enum AudioSpeed: Float, CaseIterable {
    case slow = 0.5
    case normal = 1.0
    case fast = 1.25
    case faster = 1.5
    
    var displayName: String {
        switch self {
        case .slow: return "0.5x"
        case .normal: return "1x"
        case .fast: return "1.25x"
        case .faster: return "1.5x"
        }
    }
}

// MARK: - Pronunciation Service

class PronunciationService {
    static let shared = PronunciationService()
    
    private var audioPlayer: AVAudioPlayer?
    
    private init() {}
    
    func playPronunciation(for word: Word) async {
        // Try to load from local cache first
        if let localURL = getLocalPronunciationURL(for: word) {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: localURL)
                audioPlayer?.play()
                return
            } catch {
                print("Error playing local pronunciation: \(error)")
            }
        }
        
        // Check if it's a base64 data URI
        if let audioURL = word.audioPronunciationURL {
            if audioURL.hasPrefix("data:audio") {
                do {
                    try await playBase64Audio(audioURL, for: word)
                    return
                } catch {
                    print("Error playing base64 pronunciation: \(error)")
                }
            } else if let url = URL(string: audioURL) {
                // Try to download from remote
                do {
                    let (localURL, _) = try await URLSession.shared.download(from: url)
                    cachePronunciation(word: word, from: localURL)
                    
                    audioPlayer = try AVAudioPlayer(contentsOf: localURL)
                    audioPlayer?.play()
                } catch {
                    print("Error downloading pronunciation: \(error)")
                }
            }
        }
    }
    
    private func playBase64Audio(_ dataURI: String, for word: Word) async throws {
        // Parse data URI: data:audio/x-m4a;base64,AAAA...
        guard let commaIndex = dataURI.firstIndex(of: ",") else {
            throw AudioError.invalidBase64Data
        }
        
        let base64String = String(dataURI[dataURI.index(after: commaIndex)...])
        
        guard let audioData = Data(base64Encoded: base64String) else {
            throw AudioError.invalidBase64Data
        }
        
        // Save to cache
        let cacheURL = getCacheURL(for: word)
        try audioData.write(to: cacheURL)
        
        // Play
        audioPlayer = try AVAudioPlayer(data: audioData)
        audioPlayer?.play()
        
        print("✅ Played base64 pronunciation for: \(word.arabicText)")
    }
    
    private func getCacheURL(for word: Word) -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let pronunciationDir = cacheDir.appendingPathComponent("pronunciations", isDirectory: true)
        try? FileManager.default.createDirectory(at: pronunciationDir, withIntermediateDirectories: true)
        return pronunciationDir.appendingPathComponent("\(word.id.uuidString).m4a")
    }
    
    private func getLocalPronunciationURL(for word: Word) -> URL? {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let pronunciationDir = cacheDir.appendingPathComponent("pronunciations", isDirectory: true)
        
        let fileURL = pronunciationDir.appendingPathComponent("\(word.id.uuidString).mp3")
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    private func cachePronunciation(word: Word, from url: URL) {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let pronunciationDir = cacheDir.appendingPathComponent("pronunciations", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: pronunciationDir, withIntermediateDirectories: true)
        
        let destinationURL = pronunciationDir.appendingPathComponent("\(word.id.uuidString).mp3")
        try? FileManager.default.copyItem(at: url, to: destinationURL)
    }
}
