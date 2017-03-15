//
//  ViewController.swift
//  VoiceCommander
//
//  Copyright © 2017年 Cerevo Inc. All rights reserved.
//

//  This file is based on github.com/shu223/iOS-10-Sampler
//  https://github.com/shu223/iOS-10-Sampler/blob/master/iOS-10-Sampler/Samples/SpeechRecognitionViewController.swift


import UIKit
import Speech

class ViewController: UIViewController, SFSpeechRecognizerDelegate {

    private var speechRecognizer: SFSpeechRecognizer!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest!
    private var recognitionTask: SFSpeechRecognitionTask!
    private let audioEngine = AVAudioEngine()

    @IBOutlet private weak var recordButton: UIButton!
    @IBOutlet private weak var transcriptTextView: UITextView!
    @IBOutlet weak var commandLabel: UILabel!

    // 音声認識する言語
    private let defaultLocale = Locale(identifier: "ja-JP")

    private enum Direction {
        case Neutral
        case Back
        case Forward
    }
    // 現在の進行方向
    private var direction = Direction.Neutral

    // 現在のコマンド
    private var currentCommand = ""

    // コマンドと、それを発動するキーワード
    private var commandSet = [
        Mkz4ApiCaller.Command.Forward: ["進", "行", "いけ", "スタート"],
        Mkz4ApiCaller.Command.Back: ["後", "下"],
        Mkz4ApiCaller.Command.Left: ["左"],
        Mkz4ApiCaller.Command.Right: ["右"],
        Mkz4ApiCaller.Command.Stop: ["止", "ストップ"],
    ]

    // コマンドと、それを発動するキーワード（中国語）
    private let commandSetZh = [
        Mkz4ApiCaller.Command.Forward: ["前进"],
        Mkz4ApiCaller.Command.Back: ["倒车"],
        Mkz4ApiCaller.Command.Left: ["左转"],
        Mkz4ApiCaller.Command.Right: ["右转"],
        Mkz4ApiCaller.Command.Stop: ["停"],
    ]

    // コマンドと、それを発動するキーワード（英語）
    private let commandSetEn = [
        Mkz4ApiCaller.Command.Forward: ["Forward", "forward", "Go", "go", "Start", "start"],
        Mkz4ApiCaller.Command.Back: ["Back", "back"],
        Mkz4ApiCaller.Command.Left: ["Left", "left"],
        Mkz4ApiCaller.Command.Right: ["Right", "right"],
        Mkz4ApiCaller.Command.Stop: ["Stop", "stop", "Halt", "halt"],
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        // 画面の初期化処理
        recordButton.isEnabled = false
        recordButton.setTitle(LocalizedString("Start Recording"), for: [])
        transcriptTextView.text = LocalizedString("Please Tap Start Recording")
        commandLabel.text = ""

        // iPhoneの言語設定に応じて、「コマンドと、それを発動するキーワード」を切り替える
        if Locale.current.languageCode == "zh" {
            prepareRecognizer(locale: Locale(identifier: "zh-CN"))
            commandSet = commandSetZh
            print("zh-CN")
        } else if Locale.current.languageCode == "en" {
            prepareRecognizer(locale: Locale.current)
            commandSet = commandSetEn
            print(Locale.current.identifier)
        } else {
            prepareRecognizer(locale: defaultLocale)
            print(defaultLocale.identifier)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // 音声認識へのアクセス許可を求める
        SFSpeechRecognizer.requestAuthorization { authStatus in
            /*
             The callback may not be called on the main thread. Add an
             operation to the main queue to update the record button's state.
             */
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true

                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle(LocalizedString("User denied access to speech recognition"), for: .disabled)

                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle(LocalizedString("Speech recognition restricted on this device"), for: .disabled)

                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle(LocalizedString("Speech recognition not yet authorized"), for: .disabled)
                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // 音声認識エンジンの準備
    private func prepareRecognizer(locale: Locale) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer.delegate = self
    }

    // 「音声認識を開始する」ボタンのタップ開始時に呼ばれる。録音を開始する。
    @IBAction func recordButtonDownAction(_ sender: UIButton) {
        try! startRecording()
    }

    // 「音声認識を開始する」ボタンのタップ終了時に呼ばれる。録音を停止して、音声認識を実行する。
    @IBAction func recordButtonUpAction(_ sender: UIButton) {
        if audioEngine.isRunning {
            stopRecording()
        }
    }

    private func startRecording() throws {
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)

        guard let inputNode = audioEngine.inputNode else {
            fatalError("Audio engine has no input node")
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object")
        }

        // Configure request so that results are returned before audio recording is finished
        recognitionRequest.shouldReportPartialResults = true

        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let `self` = self else {
                return
            }

            let finish = {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                self.recordButton.isEnabled = true
                self.recordButton.setTitle(LocalizedString("Start Recording"), for: [])
                if self.transcriptTextView.text == LocalizedString("(listening...)") {
                    self.transcriptTextView.text = LocalizedString("Please Tap Start Recording")
                }
            }

            if let error = error {
                print(error.localizedDescription)
                finish()
                return
            }

            guard let result = result else {
                finish()
                return
            }

            let transcript = result.bestTranscription.formattedString
            self.transcriptTextView.text = transcript

            if result.isFinal {
                self.onRecognized(transcript: transcript)
                finish()
                return
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        transcriptTextView.text = LocalizedString("(listening...)")
        commandLabel.text = ""
        recordButton.setTitle(LocalizedString("Stop recording"), for: [])
    }

    private func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recordButton.isEnabled = false
        recordButton.setTitle(LocalizedString("Stopping..."), for: .disabled)
    }

    // 音声認識した文字からMKZ4に送信するコマンドを選択する
    private func extractCommand(text: String) -> Mkz4ApiCaller.Command {
        var command = Mkz4ApiCaller.Command.None
        var maxBound = text.index(text.startIndex, offsetBy: 0)
        for (c, v) in commandSet {
            v.forEach { (s) in
                guard let range = text.range(of: s, options: [.backwards], range: nil, locale: nil) else {
                    return
                }
                if range.lowerBound >= maxBound {
                    maxBound = range.lowerBound
                    command = c
                }
            }
        }
        return command
    }

    // 音声認識した結果を処理する
    private func onRecognized(transcript: String) {
        let command = extractCommand(text: transcript)
        var sendingCommand = Mkz4ApiCaller.Command.None;

        switch command {
        case .Forward:
            sendingCommand = .Forward
            direction = .Forward
        case .Back:
            sendingCommand = .Back
            direction = .Back
        case .Right:
            switch direction {
            case .Neutral:
                sendingCommand = .Right
            case .Back:
                sendingCommand = .RightBack
            case .Forward:
                sendingCommand = .RightForward
            }
        case .Left:
            switch direction {
            case .Neutral:
                sendingCommand = .Left
            case .Back:
                sendingCommand = .LeftBack
            case .Forward:
                sendingCommand = .LeftForward
            }
        case .Stop:
            sendingCommand = .Stop
            direction = .Neutral
        default:
            break
        }

        if sendingCommand != Mkz4ApiCaller.Command.None {
            // MKZ4にコマンドを送信する
            Mkz4ApiCaller.sharedInstance.sendCommand(command: sendingCommand)
        }
        commandLabel.text = sendingCommand.rawValue
    }

    // MARK: - SFSpeechRecognizerDelegate
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle(LocalizedString("Start Recording"), for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle(LocalizedString("Recognition not available"), for: .disabled)
        }
    }
}
