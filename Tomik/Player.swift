import AVFoundation
import SwiftUI

class TomikPlayer: ObservableObject {
    private var windupSound: AVAudioPlayer
    private var tickingSound: AVAudioPlayer
    private var soundPlayers: [String: AVAudioPlayer] = [:]

    @AppStorage("windupVolume") var windupVolume: Double = 1.0 {
        didSet {
            setVolume(windupSound, windupVolume)
        }
    }
    @AppStorage("dingVolume") var dingVolume: Double = 1.0 {
        didSet {
            updateDingVolumes()
        }
    }
    @AppStorage("tickingVolume") var tickingVolume: Double = 0.0 {
        didSet {
            setVolume(tickingSound, tickingVolume)
        }
    }
    @AppStorage("soundTheme") var soundThemeRaw: String = TomikSoundTheme.ding.rawValue

    public var currentSoundTheme: TomikSoundTheme {
        get { TomikSoundTheme(rawValue: soundThemeRaw) ?? .ding }
        set { soundThemeRaw = newValue.rawValue }
    }

    public var dingVolume100: Int {
        get { min(100, max(0, Int((dingVolume * 100).rounded()))) }
        set { dingVolume = Double(newValue) / 100.0 }
    }

    public var windupVolume100: Int {
        get { min(100, max(0, Int((windupVolume * 100).rounded()))) }
        set { windupVolume = Double(newValue) / 100.0 }
    }

    public var tickingVolume100: Int {
        get { min(100, max(0, Int((tickingVolume * 100).rounded()))) }
        set { tickingVolume = Double(newValue) / 100.0 }
    }

    private func setVolume(_ sound: AVAudioPlayer, _ volume: Double) {
        sound.setVolume(Float(volume), fadeDuration: 0)
    }

    private func updateDingVolumes() {
        for (_, p) in soundPlayers {
            setVolume(p, dingVolume)
        }
    }

    init() {
        // Register default 0.0 for ticking if first run
        UserDefaults.standard.register(defaults: [
            "tickingVolume": 0.0,
            "soundTheme": TomikSoundTheme.ding.rawValue,
            "appLanguage": "vi"
        ])

        let wav = AVFileType.wav.rawValue

        // Windup & Ticking
        guard let windupAsset = NSDataAsset(name: "windup"),
              let tickingAsset = NSDataAsset(name: "ticking") else {
            fatalError("Essential audio assets missing")
        }

        do {
            windupSound = try AVAudioPlayer(data: windupAsset.data, fileTypeHint: wav)
            tickingSound = try AVAudioPlayer(data: tickingAsset.data, fileTypeHint: wav)
        } catch {
            fatalError("Error initializing essential players: \(error)")
        }

        windupSound.prepareToPlay()
        tickingSound.numberOfLoops = -1
        tickingSound.prepareToPlay()

        setVolume(windupSound, windupVolume)
        setVolume(tickingSound, tickingVolume)

        // Initialize completion sound variants
        for theme in TomikSoundTheme.allCases {
            if let asset = NSDataAsset(name: theme.assetName) {
                do {
                    let p = try AVAudioPlayer(data: asset.data, fileTypeHint: wav)
                    p.prepareToPlay()
                    setVolume(p, dingVolume)
                    soundPlayers[theme.assetName] = p
                } catch {
                    print("Could not load sound asset \(theme.assetName): \(error)")
                }
            }
        }
    }

    func playWindup() {
        windupSound.play()
    }

    func playDing() {
        let theme = currentSoundTheme
        playThemeSound(theme)
    }

    func playThemeSound(_ theme: TomikSoundTheme) {
        // Stop all other sounds immediately so they don't overlap
        for (_, p) in soundPlayers {
            if p.isPlaying {
                p.stop()
                p.currentTime = 0
            }
        }
        if let player = soundPlayers[theme.assetName] {
            player.currentTime = 0
            player.play()
        }
    }

    func startTicking() {
        if tickingVolume > 0 {
            tickingSound.play()
        }
    }

    func stopTicking() {
        tickingSound.stop()
    }
}
