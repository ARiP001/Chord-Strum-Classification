//
//  MLStrumDetector.swift
//  tesModelStrum
//
//  Created by Arif Fathurrahman on 04/06/26.
//

import Foundation
import AVFoundation
import SoundAnalysis
import CoreML
import Combine

class MLStrumDetector: NSObject, ObservableObject, SNResultsObserving {
    private let engine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer?
    private var request: SNClassifySoundRequest?
    
    @Published var detectedStrum: String = "Menyiapkan AI..."
    @Published var confidenceLevel: Double = 0.0
    
    private var resetWorkItem: DispatchWorkItem?
    
    override init() {
        super.init()
        setupAudioAndModel()
    }
    
    private func setupAudioAndModel() {
        // 1. Memanggil Model AI (Pastikan nama 'StrumClassifier' sesuai dengan file .mlmodel milikmu)
        guard let modelClass = try? StrumChordDetection_2chord(configuration: MLModelConfiguration()),
              let customRequest = try? SNClassifySoundRequest(mlModel: modelClass.model) else {
            print("Gagal memuat model ML. Periksa nama file .mlmodel kamu!")
            return
        }
        self.request = customRequest
        
        // 2. Setup Mikrofon
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.allowBluetoothHFP])
            try session.setActive(true)
        } catch {
            print("Gagal mengatur AVAudioSession: \(error)")
        }
        
        let inputNode = engine.inputNode
        var inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Workaround jika dijalankan di Simulator
        if inputFormat.sampleRate == 0 {
            if let standardFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) {
                inputFormat = standardFormat
            }
        }
        
        // 3. Setup Analyzer
        analyzer = SNAudioStreamAnalyzer(format: inputFormat)
        
        inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) { [weak self] (buffer, time) in
            guard let self = self else { return }
            self.analyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
        }
        
        // 4. Memulai Request
        do {
            try analyzer?.add(customRequest, withObserver: self)
            DispatchQueue.main.async {
                self.detectedStrum = "Siap! Mainkan Gitarmu 🎸"
            }
        } catch {
            print("Gagal menambahkan request analisis: \(error)")
        }
    }
    
    func start() {
        try? engine.start()
    }
    
    func stop() {
        engine.stop()
    }
    
    // MARK: - Penerima Hasil AI
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classificationResult = result as? SNClassificationResult else { return }
        
        // Ambil tebakan dengan keyakinan paling tinggi
        guard let topClassification = classificationResult.classifications.first else { return }
        
        DispatchQueue.main.async {
            // Hanya bereaksi jika AI yakin > 80% dan bukan mendeteksi suara Noise/Diam
            if topClassification.confidence > 0.8 && topClassification.identifier != "Noise" {
                
                self.detectedStrum = topClassification.identifier
                self.confidenceLevel = topClassification.confidence
                
                // --- Logika Reset Tampilan ---
                self.resetWorkItem?.cancel()
                let workItem = DispatchWorkItem { [weak self] in
                    self?.detectedStrum = "Menunggu..."
                    self?.confidenceLevel = 0.0
                }
                self.resetWorkItem = workItem
                
                // Reset setelah 1 detik
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
            }
        }
    }
    
    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("SoundAnalysis error: \(error)")
    }
}
