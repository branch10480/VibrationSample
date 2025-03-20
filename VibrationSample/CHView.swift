import CoreHaptics
import SwiftUI

struct ContentView: View {
    @StateObject private var hapticManager = HapticManager()

    var body: some View {
        VStack(spacing: 20) {
            Text("Core Haptics + Audio サンプル")
                .font(.headline)

            Button("Play Haptic and Sound") {
                hapticManager.playHapticAndSound()
            }
            .padding()
        }
        .onAppear {
            hapticManager.prepareHaptics()
        }
        .padding()
    }
}

class HapticManager: ObservableObject {
    private var engine: CHHapticEngine?

    /// Haptic Engine の初期化
    func prepareHaptics() {
        // CoreHaptics が利用可能かどうかをチェック
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("このデバイスでは Haptics がサポートされていません。")
            return
        }

        do {
            // Haptic Engine のインスタンス生成
            engine = try CHHapticEngine()

            // エンジンがリセットされた際に再起動を試みるハンドラ（任意）
            engine?.resetHandler = { [weak self] in
                print("Haptic Engine がリセットされました。再起動を試みます。")
                do {
                    try self?.engine?.start()
                } catch {
                    print("Haptic Engine の再起動に失敗: \(error.localizedDescription)")
                }
            }

            // エンジンが停止した際のハンドラ（任意）
            engine?.stoppedHandler = { reason in
                print("Haptic Engine が停止しました。理由: \(reason)")
            }

            // エンジンの起動
            try engine?.start()

        } catch {
            print("Haptic Engine の作成または起動に失敗: \(error.localizedDescription)")
        }
    }

    /// Haptic + Audio のパターンを再生
    func playHapticAndSound() {
        guard let engine = engine,
            CHHapticEngine.capabilitiesForHardware().supportsHaptics
        else {
            return
        }

        // イベントの配列
        var events = [CHHapticEvent]()

        // 1) バイブレーションのイベント
        // 例: 0.0秒から0.5秒間、Intensity=1.0 / Sharpness=0.2で連続振動
        let hapticEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
            ],
            relativeTime: 0.0,
            duration: 0.5
        )
        events.append(hapticEvent)

        // 2) Audio イベント (例: プロジェクトに追加した "sound.wav" を再生)

        guard let soundURL = Bundle.main.url(forResource: "gauge_recovery", withExtension: "wav") else {
            print("サウンドファイルが見つかりません")
            return
        }

        guard let resouceID = try? engine.registerAudioResource(soundURL) else {
            print("Audio Resource の登録に失敗")
            return
        }

        let audioEvent = CHHapticEvent(
            audioResourceID: resouceID,
            parameters: [],
            relativeTime: 0.0,
            duration: 0.5
        )
        events.append(audioEvent)

        // バイブレーションパラメータを途中で変化させる Dynamic Parameter
        var dynamicParameters = [CHHapticDynamicParameter]()

        // 0.3秒後に Sharpness=0.8 に変更
        let sharpnessParam = CHHapticDynamicParameter(
            parameterID: .hapticSharpnessControl,
            value: 0.8,
            relativeTime: 0.3
        )
        dynamicParameters.append(sharpnessParam)

        // 0.3秒後に Intensity=0.5 に変更
        let intensityParam = CHHapticDynamicParameter(
            parameterID: .hapticIntensityControl,
            value: 0.5,
            relativeTime: 0.3
        )
        dynamicParameters.append(intensityParam)

        do {
            // パターンの作成
            let pattern = try CHHapticPattern(events: events, parameters: dynamicParameters)

            // パターンプレイヤーの作成
            let player = try engine.makePlayer(with: pattern)

            // 念のためエンジンを再スタートしてから再生
            try engine.start()
            try player.start(atTime: 0)

        } catch {
            print("パターンの作成または再生に失敗: \(error.localizedDescription)")
        }
    }
}
