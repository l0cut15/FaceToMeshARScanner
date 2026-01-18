//
//  ContentView.swift
//  FaceScanner
//
//  Main navigation view with tab interface
//

import SwiftUI
import ARKit
import UIKit

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showingCompatibilityAlert = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)

            // Scan Tab
            if ARFaceTrackingConfiguration.isSupported {
                ScanView()
                    .tabItem {
                        Label("Scan", systemImage: "faceid")
                    }
                    .tag(1)
            } else {
                UnsupportedDeviceView()
                    .tabItem {
                        Label("Scan", systemImage: "faceid")
                    }
                    .tag(1)
            }

            // History Tab
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(2)
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // App icon/logo
                Image(systemName: "faceid")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)

                Text("FaceScanner")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Capture high-quality 3D face scans\nfor 3D printing")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                // Quick actions
                VStack(spacing: 16) {
                    QuickActionButton(
                        title: "New Scan",
                        icon: "plus.circle.fill",
                        color: .blue
                    ) {
                        // Navigate to scan tab
                        selectedTab = 1
                    }

                    HStack(spacing: 16) {
                        InfoCard(
                            title: "Scans",
                            value: "\(StorageManager.shared.getScanCount())",
                            icon: "cube.fill"
                        )

                        InfoCard(
                            title: "Storage",
                            value: StorageManager.shared.getStorageUsedString(),
                            icon: "externaldrive.fill"
                        )
                    }
                }
                .padding()

                Spacer()

                // Device compatibility notice
                if !ARFaceTrackingConfiguration.isSupported {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Face tracking requires a device with TrueDepth camera")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .foregroundColor(.white)
            .padding()
            .background(color.gradient)
            .cornerRadius(12)
            .shadow(color: color.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Info Card
struct InfoCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Unsupported Device View
struct UnsupportedDeviceView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                
                Text("Face Tracking Not Supported")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("This device does not have a TrueDepth camera required for face scanning.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("Face scanning requires:")
                    .font(.headline)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("iPhone X or newer (front camera)", systemImage: "checkmark.circle.fill")
                    Label("iPad Pro with Face ID", systemImage: "checkmark.circle.fill")
                }
                .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Scan")
        }
    }
}

#Preview {
    ContentView()
}
