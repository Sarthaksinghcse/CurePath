import SwiftUI
import PhotosUI

struct ScannerView: View {
    @Binding var isPresented: Bool
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showCamera = false
    @StateObject private var mlService = MLService()
    @State private var showResults = false
    @State private var classification: InjuryClassification?
    @State private var scanDots: Int = 0
    @State private var dotTimer: Timer?
    @State private var calmMessageIndex = Int.random(in: 0..<4)
    @State private var showCancelConfirm = false

    private var calmMessage: String {
        EncouragementSystem.calmMessages[calmMessageIndex % EncouragementSystem.calmMessages.count]
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.1), lineWidth: 2)
                        .frame(width: 150, height: 150)
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color.blue.opacity(0.12), Color.blue.opacity(0.04)],
                            center: .center, startRadius: 0, endRadius: 75))
                        .frame(width: 130, height: 130)
                    if mlService.isAnalyzing {
                        ScanningRingView()
                    } else {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 54))
                            .foregroundColor(.blue)
                    }
                }

                Spacer().frame(height: 28)

                // ── Status Text ────────────────────────────────────────────
                VStack(spacing: 10) {
                    if mlService.isAnalyzing {
                        Text(calmMessage)
                            .font(.title3).fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .transition(.opacity)

                        Text("Running analysis on device" + String(repeating: ".", count: scanDots))
                            .font(.subheadline).foregroundColor(.secondary)
                            .animation(.none, value: scanDots)

                        VStack(spacing: 8) {
                            AnalysisStep(label: "Checking for skin",          done: true)
                            AnalysisStep(label: "Running wound classifier",   done: scanDots > 1)
                            AnalysisStep(label: "Detecting wound region",     done: scanDots > 2)
                        }
                        .padding(.top, 8).padding(.horizontal, 40)

                    } else {
                        Text("Scan a Wound")
                            .font(.title2).fontWeight(.bold).multilineTextAlignment(.center)

                        Text(calmMessage)
                            .font(.callout).foregroundColor(.blue)                    .multilineTextAlignment(.center).padding(.horizontal, 32)

                        Text("Take a clear, close up photo of the injury. Use good lighting for best results.")
                            .font(.subheadline).foregroundColor(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 32).padding(.top, 2)
                    }

                    if let error = mlService.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                            Text(error).font(.caption).foregroundColor(.red)
                        }
                        .padding().background(Color.red.opacity(0.08)).cornerRadius(10).padding(.horizontal)
                    }
                }

                Spacer()

                // ── Buttons ────────────────────────────────────────────────
                if !mlService.isAnalyzing {
                    VStack(spacing: 14) {
                        // Camera button
                        Button {
                            HapticFeedback.medium()
                            showCamera = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "camera.fill").font(.title3)
                                Text("Take Photo").fontWeight(.semibold).font(.title3)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.85)],
                                startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white).cornerRadius(15)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }

                        // Photo library button
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            HStack(spacing: 12) {
                                Image(systemName: "photo.stack.fill").font(.title3)
                                Text("Choose from Library").fontWeight(.semibold).font(.title3)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Color(.systemGray6)).foregroundColor(.blue).cornerRadius(15)
                        }

                       
                    }
                    .padding(.horizontal, 24).padding(.bottom, 36)
                }
            }
            .navigationTitle("Scan Injury")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        if selectedImage != nil || mlService.isAnalyzing {
                            showCancelConfirm = true
                        } else {
                            isPresented = false
                        }
                    }
                    .disabled(mlService.isAnalyzing && selectedImage == nil)
                }
            }
            .confirmationDialog(
                "Discard this scan?",
                isPresented: $showCancelConfirm,
                titleVisibility: .visible
            ) {
                Button("Discard & Go Home", role: .destructive) { isPresented = false }
                Button("Continue Scanning", role: .cancel) { }
            } message: {
                Text("Your scan will be discarded.")
            }
            // ── Photo library picker ──
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        analyzeImage(image)
                    }
                }
            }
            // ── Camera sheet ──
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView(isPresented: $showCamera, selectedImage: $selectedImage)
                    .ignoresSafeArea()
            }
            // ── Trigger analysis when camera delivers image ──
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage { analyzeImage(image) }
            }
            .onChange(of: mlService.isAnalyzing) { _, analyzing in
                if analyzing { startDots() } else { stopDots() }
            }
            .sheet(isPresented: $showResults) {
                if let image = selectedImage, let result = classification {
                    ResultsView(image: image, classification: result)
                }
            }
        }
    }

    private func analyzeImage(_ image: UIImage) {
        HapticFeedback.light()
        mlService.analyzeWound(image: image) { result in
            switch result {
            case .success(let c):
                self.classification = c
                switch c.type {
                case .unknown: HapticFeedback.warning()
                case .normal:  HapticFeedback.success()
                default:       HapticFeedback.medium()
                }
                self.showResults = true
            case .failure(let error):
                HapticFeedback.error()
                print("Analysis failed: \(error.localizedDescription)")
            }
        }
    }

    private func startDots() {
        scanDots = 1
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            scanDots = (scanDots % 3) + 1
        }
    }

    private func stopDots() {
        dotTimer?.invalidate(); dotTimer = nil; scanDots = 0
    }
}

// MARK: - Scanning Ring
struct ScanningRingView: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat   = 0.8

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(AngularGradient(colors: [Color.blue.opacity(0), Color.blue], center: .center),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) { rotation = 360 }
                }
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 28)).foregroundColor(.blue)
                .scaleEffect(scale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { scale = 1.1 }
                }
        }
    }
}

// MARK: - Analysis Step Row
struct AnalysisStep: View {
    let label: String; let done: Bool
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.caption).foregroundColor(done ? .green : .gray.opacity(0.4))
            Text(label).font(.caption).foregroundColor(done ? .primary : .secondary)
            Spacer()
        }
        .animation(.easeIn(duration: 0.3), value: done)
    }
}

// MARK: - Quick Tip Badge
struct QuickTip: View {
    let icon: String; let text: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.headline).foregroundColor(.blue)
            Text(text).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Color(.systemGray6)).cornerRadius(10)
    }
}

#Preview { ScannerView(isPresented: .constant(true)) }
