//
//  ContentView.swift
//  tesModelStrum
//
//  Created by Arif Fathurrahman on 04/06/26.
//
import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject var detector = MLStrumDetector()
    
    var body: some View {
        VStack(spacing: 40) {
            Text("🎶 Strum Master")
                .font(.system(size: 34, weight: .black, design: .rounded))
            
            // Area Permainan Visual
            ZStack {
                Circle()
                    // Lingkaran menyala hijau transparan jika terdeteksi dengan akurasi tinggi
                    .fill(detector.confidenceLevel > 0.8 ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 280, height: 280)
                
                VStack(spacing: 10) {
                    Text(detector.detectedStrum)
                        .font(.system(size: 45, weight: .bold, design: .rounded))
                        .foregroundColor(detector.confidenceLevel > 0.8 ? .green : .primary)
                        // Agar teks tidak terpotong jika namanya panjang
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, 20)
                    
                    if detector.confidenceLevel > 0 {
                        Text(String(format: "Akurasi: %.0f%%", detector.confidenceLevel * 100))
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                }
            }
            // Efek animasi membal saat teks berubah
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: detector.detectedStrum)
            
            Spacer()
        }
        .padding(.top, 50)
        .onAppear {
            requestMicrophoneAccess()
        }
    }
    
    // Meminta izin mikrofon saat aplikasi pertama kali dibuka
    func requestMicrophoneAccess() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    detector.start()
                } else {
                    print("Izin mic ditolak! Buka Settings untuk mengaktifkannya.")
                }
            }
        }
    }
}
