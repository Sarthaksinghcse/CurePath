import SwiftUI

struct ResultsView: View {
    let image: UIImage
    let classification: InjuryClassification
    @Environment(\.dismiss) var dismiss
    @State private var showAnimatedGuidance = false
    @State private var showLocationInput = false
    @State private var injuryLocation = ""
    @State private var savedSuccessfully = false
    @State private var appeared = false
    @State private var showCancelConfirm = false
    @ObservedObject private var dataManager = InjuryDataManager.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    calmHeader.padding(.horizontal).padding(.top, 4)
                        .opacity(appeared ? 1 : 0).animation(.easeOut.delay(0.05), value: appeared)

                    ZStack {
                        Image(uiImage: image).resizable().scaledToFit()
                            .frame(maxHeight: 280).cornerRadius(18)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                        if let region = classification.woundRegion,
                           classification.type != .normal, classification.type != .unknown {
                            WoundBoundaryOverlay(region: region).frame(maxHeight: 280).cornerRadius(18).clipped()
                        }
                    }
                    .padding(.horizontal)
                    .opacity(appeared ? 1 : 0).scaleEffect(appeared ? 1 : 0.96)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appeared)

                    resultCard.padding(.horizontal)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 14)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.18), value: appeared)

                    actionSection
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 14)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: appeared)

                    if savedSuccessfully {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("Saved! Daily check-ins will track your healing.").fontWeight(.semibold).foregroundColor(.green)
                        }
                        .padding().frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1)).cornerRadius(12)
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill").foregroundColor(.secondary).font(.caption)
                        Text("Educational guidance only — not a substitute for medical advice. For emergencies, call your local emergency number.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(12).background(Color(.systemGray6)).cornerRadius(12)
                    .padding(.horizontal).padding(.bottom)
                }
                .padding(.top)
            }
            .navigationTitle("Scan Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if savedSuccessfully {
                            dismiss()
                        } else {
                            showCancelConfirm = true
                        }
                    }
                }
            }
            .confirmationDialog(
                "Go back without saving?",
                isPresented: $showCancelConfirm,
                titleVisibility: .visible
            ) {
                Button("Discard & Go Home", role: .destructive) { dismiss() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your scan result won't be saved to History.")
            }
            .fullScreenCover(isPresented: $showAnimatedGuidance) {
                AnimatedGuidanceView(
                    image: image, injuryType: classification.type,
                    woundRegion: classification.woundRegion,
                    onComplete: { shouldSave in if shouldSave { showLocationInput = true } }
                )
            }
            .alert("Where is the injury?", isPresented: $showLocationInput) {
                TextField("e.g., Right Knee, Left Palm", text: $injuryLocation)
                Button("Save to History") { saveInjury() }
                Button("Skip", role: .cancel) { dismiss() }
            } message: { Text("This helps track your recovery") }
        }
        .onAppear {
            if classification.type == .unknown { HapticFeedback.warning() }
            else if classification.type == .normal { HapticFeedback.success() }
            else { HapticFeedback.medium() }
            withAnimation { appeared = true }
        }
    }

    private var calmHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: classification.type == .unknown ? "questionmark.circle.fill"
                  : classification.type == .normal ? "checkmark.circle.fill" : "heart.circle.fill")
                .font(.title3)
                .foregroundColor(classification.type == .unknown ? .orange : classification.type == .normal ? .green : .blue)
            Text(classification.type == .unknown ? "Let's try a clearer photo."
                 : classification.type == .normal ? "Good news — no wound detected."
                 : "We've got you. Let's take care of this together.")
                .font(.subheadline).fontWeight(.medium)
            Spacer()
        }
        .padding(12)
        .background((classification.type == .unknown ? Color.orange : classification.type == .normal ? Color.green : Color.blue).opacity(0.07))
        .cornerRadius(12)
    }

    private var resultCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(classification.type.color.opacity(0.12)).frame(width: 56, height: 56)
                    Image(systemName: classification.type.icon).font(.system(size: 24)).foregroundColor(classification.type.color)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(classification.type.displayName).font(.title3).fontWeight(.bold)
                    ConfidenceBadge(confidence: classification.confidence, isRejected: classification.isRejected)
                }
                Spacer()
            }
            if let reason = classification.rejectionReason {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text(reason.userMessage).font(.subheadline).foregroundColor(.secondary)
                }.padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08)).cornerRadius(12)
            }
            if classification.woundRegion != nil && classification.type != .normal && classification.type != .unknown {
                HStack(spacing: 8) {
                    Image(systemName: "viewfinder.circle.fill").foregroundColor(.cyan)
                    Text("Wound region highlighted in image above").font(.caption).foregroundColor(.cyan)
                }.padding(.horizontal, 12).padding(.vertical, 8).background(Color.cyan.opacity(0.08)).cornerRadius(10)
            }
            if !classification.allResults.isEmpty && !classification.isRejected {
                VStack(alignment: .leading, spacing: 7) {
                    Text("All Predictions").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                    ForEach(classification.allResults.prefix(4), id: \.label) { result in
                        HStack {
                            Text(result.label).font(.caption)
                            Spacer()
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.15))
                                    RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.5))
                                        .frame(width: geo.size.width * CGFloat(result.confidence))
                                }
                            }.frame(width: 80, height: 6)
                            Text(result.percentage).font(.caption).foregroundColor(.secondary).frame(width: 40, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding().background(Color(.systemBackground)).cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private var actionSection: some View {
        if classification.type != .normal && classification.type != .unknown {
            Button { HapticFeedback.medium(); showAnimatedGuidance = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle.fill").font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start Guided Treatment").fontWeight(.semibold)
                        Text("Step-by-step · then save & track daily").font(.caption).opacity(0.8)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption)
                }
                .foregroundColor(.white).padding()
                .background(LinearGradient(colors: [.blue, Color(red:0.1,green:0.3,blue:0.8)], startPoint: .leading, endPoint: .trailing))
                .cornerRadius(16).shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal)
        } else if classification.type == .unknown {
            VStack(spacing: 12) {
                Image(systemName: "questionmark.circle.fill").font(.system(size: 48)).foregroundColor(.orange)
                Text("No Wound Found").font(.title3).fontWeight(.bold)
                Text(classification.rejectionReason?.userMessage ?? "Please retake the photo closer to the wound.")
                    .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                VStack(alignment: .leading, spacing: 8) {
                    TipRow(icon: "camera.macro", text: "Hold camera 15-30cm from wound")
                    TipRow(icon: "sun.max.fill", text: "Use good lighting (natural is best)")
                    TipRow(icon: "hand.raised.fill", text: "Keep hand steady to avoid blur")
                }.padding().background(Color(.systemGray6)).cornerRadius(12).padding(.horizontal)
            }.padding()
        } else {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 48)).foregroundColor(.green)
                Text("No Wound Detected").font(.title3).fontWeight(.bold)
                Text("Skin appears healthy. If you feel pain or notice changes, consult a healthcare professional.")
                    .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            }.padding()
        }
    }

    private func saveInjury() {
        let location = injuryLocation.trimmingCharacters(in: .whitespaces)
        let boxArea = classification.woundRegion.map { Double($0.width * $0.height) } ?? 0.0
        let pixelDensity = classification.woundRegion.map {
            quickPixelDensity(image: image, region: $0, type: classification.type)
        } ?? 0.0
        let woundScore = (boxArea + pixelDensity) / 2.0

        dataManager.saveInjury(
            type: classification.type, image: image, confidence: classification.confidence,
            location: location.isEmpty ? "Body" : location,
            woundScore: woundScore, boundingBoxArea: boxArea, woundPixelDensity: pixelDensity
        )
        HapticFeedback.success()
        withAnimation { savedSuccessfully = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: .switchToHomeTab, object: nil)
            }
        }
    }

    private func quickPixelDensity(image: UIImage, region: CGRect, type: InjuryType) -> Double {
        guard let cgImage = image.cgImage else { return 0 }
        let w = 80, h = 80
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &pixels, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        let rx = Int(region.minX * CGFloat(w)); let ry = Int(region.minY * CGFloat(h))
        let rw = max(1, Int(region.width * CGFloat(w))); let rh = max(1, Int(region.height * CGFloat(h)))
        var wound = 0, total = 0
        for y in ry..<min(ry+rh,h) { for x in rx..<min(rx+rw,w) {
            let i = (y*w+x)*4; let r = Int(pixels[i]); let g = Int(pixels[i+1]); let b = Int(pixels[i+2])
            let isW: Bool
            switch type {
            case .cut: isW = r>120 && g<80 && b<80 && r>g+50
            case .burn: isW = (r>160 && g<100 && b<100)||(r<60 && g<40 && b<40)
            case .abrasion: isW = r>140 && g>60 && b>50 && r>g+30 && r>b+40
            default: isW = false
            }
            if isW { wound += 1 }; total += 1
        }}
        return total > 0 ? Double(wound)/Double(total) : 0
    }
}

struct TipRow: View {
    let icon: String; let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.subheadline).foregroundColor(.blue).frame(width: 20)
            Text(text).font(.subheadline)
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: Float; let isRejected: Bool
    var color: Color { isRejected ? .orange : confidence >= 0.82 ? .green : confidence >= 0.65 ? .orange : .red }
    var label: String { isRejected ? "No wound found" : "\(Int(confidence * 100))% confidence" }
    var icon: String { isRejected ? "xmark.circle.fill" : confidence >= 0.82 ? "checkmark.circle.fill" : "exclamationmark.circle.fill" }
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption)
            Text(label).font(.caption).fontWeight(.semibold)
        }
        .foregroundColor(color).padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.12)).cornerRadius(8)
    }
}

#Preview {
    ResultsView(
        image: UIImage(systemName: "photo")!,
        classification: InjuryClassification(
            type: .cut, confidence: 0.89,
            allResults: [ClassificationResult(label: "Cut", confidence: 0.89)],
            rejectionReason: nil, woundRegion: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.35))
    )
}
