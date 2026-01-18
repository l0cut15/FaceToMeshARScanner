//
//  ScanView.swift
//  FaceScanner
//
//  AR scanning interface with face mesh capture
//

import SwiftUI
import ARKit
import SceneKit
import ModelIO
import AVFoundation

struct ScanView: View {
    @StateObject private var scanner = ARFaceScanner()
    @State private var showingPreview = false
    @State private var capturedMesh: MDLMesh?
    @State private var isCapturing = false
    @State private var captureProgress: Double = 0
    @State private var progressTimer: Timer?
    @State private var isSessionReady = false
    @State private var sessionError: String?
    @State private var initializationTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if let error = sessionError {
                // Error state
                ErrorView(message: error)
            } else if isSessionReady {
                // AR Camera view
                ARViewContainer(scanner: scanner)
                    .ignoresSafeArea()
            } else {
                // Loading state
                LoadingView()
            }

            // Overlay UI (only show when session is ready)
            if isSessionReady && sessionError == nil {
                VStack {
                // Top bar with quality indicator and instructions
                VStack(spacing: 8) {
                    HStack {
                        QualityIndicator(quality: scanner.scanQuality)

                        Text(scanner.faceDetected ? "Face Detected" : "No Face")
                            .font(.caption)
                            .foregroundColor(scanner.faceDetected ? .green : .red)

                        Spacer()

                        // Frame counter
                        Text("\(scanner.capturedFrames.count)/\(Constants.ScanQuality.targetFrameCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)

                    Text(scanner.instructionText)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
                .padding(.top, 60)

                Spacer()

                // Capture progress (when capturing)
                if isCapturing {
                    VStack(spacing: 12) {
                        ProgressView(value: captureProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                            .frame(width: 200)

                        Text("Processing scan...")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }

                // Capture button
                CaptureButton(
                    enabled: scanner.canCapture && !isCapturing,
                    isCapturing: isCapturing
                ) {
                    captureCurrentMesh()
                }
                .padding(.bottom, 40)
            }
        }
        }
        .task {
            // Initialize AR session asynchronously with timeout
            initializationTask = Task {
                await initializeARSession()
            }
        }
        .onDisappear {
            // Cancel initialization if still running
            initializationTask?.cancel()
            initializationTask = nil
            
            // Clean up timer and scanning session
            progressTimer?.invalidate()
            progressTimer = nil
            scanner.stopScanning()
            isSessionReady = false
        }
        .fullScreenCover(isPresented: $showingPreview) {
            if let mesh = capturedMesh {
                PreviewView(mesh: mesh, onDismiss: {
                    showingPreview = false
                    capturedMesh = nil
                    scanner.startScanning()
                })
            }
        }
    }
    
    private func initializeARSession() async {
        print("🔍 Checking camera authorization...")
        
        // Add timeout protection
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            if !Task.isCancelled && !isSessionReady {
                await MainActor.run {
                    sessionError = "Camera initialization timed out. Please check camera permissions in Settings."
                    print("⏱️ Session initialization timed out")
                }
            }
        }
        
        defer {
            timeoutTask.cancel()
        }
        
        // Check camera authorization first
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch authStatus {
        case .notDetermined:
            print("📷 Requesting camera permission...")
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                await MainActor.run {
                    sessionError = "Camera access denied. Please enable in Settings."
                }
                return
            }
            print("✅ Camera permission granted")
            
        case .denied, .restricted:
            print("❌ Camera permission denied")
            await MainActor.run {
                sessionError = "Camera access denied. Go to Settings → FaceScanner → Camera to enable."
            }
            return
            
        case .authorized:
            print("✅ Camera already authorized")
            
        @unknown default:
            break
        }
        
        // Check if device supports AR face tracking
        guard ARFaceTrackingConfiguration.isSupported else {
            print("❌ Face tracking not supported")
            await MainActor.run {
                sessionError = "Face tracking requires a device with TrueDepth camera (iPhone X or newer)"
            }
            return
        }
        
        print("✅ Face tracking supported")
        
        // Start the AR session on main thread (ARKit requirement)
        await MainActor.run {
            print("🚀 Starting AR session...")
            scanner.startScanning()
            isSessionReady = true
            print("✅ Session ready - UI should now display")
        }
    }

    private func captureCurrentMesh() {
        isCapturing = true
        captureProgress = 0

        // Invalidate any existing timer
        progressTimer?.invalidate()
        
        // Simulate processing progress with retained timer
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] timer in
            captureProgress += 0.1
            if captureProgress >= 1.0 {
                timer.invalidate()
                progressTimer = nil
            }
        }

        // Process mesh on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            let mesh = scanner.captureMesh()

            DispatchQueue.main.async {
                // Clean up timer
                progressTimer?.invalidate()
                progressTimer = nil
                
                isCapturing = false
                captureProgress = 1.0

                if let mesh = mesh {
                    capturedMesh = mesh
                    showingPreview = true
                    scanner.stopScanning()
                } else {
                    // Handle error case - restart scanning
                    print("❌ Failed to capture mesh")
                    scanner.startScanning()
                }
            }
        }
    }
}

// MARK: - AR View Container (UIViewRepresentable)
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var scanner: ARFaceScanner

    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.session = scanner.session
        arView.delegate = context.coordinator
        arView.automaticallyUpdatesLighting = true
        arView.rendersContinuously = true

        // Configure scene
        arView.scene = SCNScene()
        arView.backgroundColor = .black

        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // View updates handled by coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, ARSCNViewDelegate {
        private var faceNode: SCNNode?

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard anchor is ARFaceAnchor else { return nil }

            // Create face mesh node
            let faceGeometry = ARSCNFaceGeometry(device: renderer.device!)
            faceGeometry?.firstMaterial?.fillMode = .lines
            faceGeometry?.firstMaterial?.diffuse.contents = UIColor(red: 0, green: 1, blue: 1, alpha: 0.8)

            let node = SCNNode(geometry: faceGeometry)
            faceNode = node

            return node
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor,
                  let faceGeometry = node.geometry as? ARSCNFaceGeometry else {
                return
            }

            // Update face geometry with new data
            faceGeometry.update(from: faceAnchor.geometry)
        }
    }
}

// MARK: - Quality Indicator
struct QualityIndicator: View {
    let quality: ScanQuality

    var body: some View {
        Circle()
            .fill(quality.color)
            .frame(width: Constants.UI.qualityIndicatorSize,
                   height: Constants.UI.qualityIndicatorSize)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(color: quality.color.opacity(0.5), radius: 4)
    }
}

// MARK: - Capture Button
struct CaptureButton: View {
    let enabled: Bool
    let isCapturing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(enabled ? Color.white : Color.gray, lineWidth: Constants.UI.captureButtonStrokeWidth)
                    .frame(width: Constants.UI.captureButtonSize,
                           height: Constants.UI.captureButtonSize)

                // Inner circle
                Circle()
                    .fill(enabled ? Color.white : Color.gray)
                    .frame(width: Constants.UI.captureButtonInnerSize,
                           height: Constants.UI.captureButtonInnerSize)

                // Capture icon or spinner
                if isCapturing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                } else {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .foregroundColor(.black)
                }
            }
        }
        .disabled(!enabled || isCapturing)
        .animation(.easeInOut(duration: 0.2), value: enabled)
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Initializing Camera...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - Error View
struct ErrorView: View {
    let message: String
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Cannot Start Camera")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                if message.contains("Settings") {
                    Button {
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsURL)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
                }
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ScanView()
}
