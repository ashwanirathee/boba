//
//  PomodoroView.swift
//  chatur
//
//  Created by ashwani on 20/08/25.
//


//
//  PomodoroView.swift
//

import SwiftUI

struct PomodoroView: View {
    // lengths (seconds)
    private let focusLength: Int = 25 * 60
    private let breakLength: Int = 5 * 60

    enum Phase: String { case focus = "Focus", `break` = "Break" }

    @State private var phase: Phase = .focus
    @State private var remaining: Int = 25 * 60
    @State private var isRunning: Bool = false

    // tick every second
    @State private var lastTick = Date()

    var body: some View {
        VStack(spacing: 20) {
            HStack{
                Text(phase.rawValue)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.black)
                
                // big mm:ss
                Text(timeString(remaining))
                    .font(.system(size: 40, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(.black)
                
                Button(isRunning ? "Pause" : "Start") {
                    if isRunning {
                        pause()
                    } else {
                        start()
                    }
                }
                .buttonStyle(.borderedProminent)

            }

            
            // with this:
            ProgressView(value: Double(totalForPhase - remaining),
                         total: Double(totalForPhase))
                .progressViewStyle(.linear)
                .tint(.black)
                .padding(.horizontal)

            HStack(spacing: 2) {

                Button("Reset", role: .destructive) { reset() }
                    .buttonStyle(.bordered)
                
                Button("25/5") { setPreset(focus: 25*60, brk: 5*60) }.buttonStyle(.bordered)
                Button("50/10") { setPreset(focus: 50*60, brk: 10*60) }.buttonStyle(.bordered)
                Button("90/15") { setPreset(focus: 90*60, brk: 15*60) }.buttonStyle(.bordered)
            } .font(.system(size: 20, weight: .light))

            // Optional: make preset buttons text black instead of secondary gray
            HStack(spacing: 12) {

            }
            .font(.caption)
            .foregroundStyle(.black)         // ← was .secondary

        }
        .padding(16) // inner padding for breathing room
        .background(Color.white) // or .ultraThinMaterial
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black, lineWidth: 2)   // ← the boundary line
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4) // optionalv      
        .padding()
        .tint(.black)                     // makes borderedProminent buttons black
        // simple ticking loop — avoids drift when the app hiccups for a moment
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { now in
            guard isRunning else { lastTick = now; return }
            let delta = now.timeIntervalSince(lastTick)
            if delta >= 1 {
                tick(seconds: Int(delta.rounded()))
                lastTick = now
            }
        }
    }

    // MARK: - Logic

    private var totalForPhase: Int {
        phase == .focus ? focusLength : breakLength
    }

    private var progress: Double {
        guard totalForPhase > 0 else { return 0 }
        return 1 - Double(remaining) / Double(totalForPhase)
    }

    private func start() {
        if remaining <= 0 { // if already finished, restart current phase
            remaining = totalForPhase
        }
        isRunning = true
        lastTick = Date()
    }

    private func pause() {
        isRunning = false
    }

    private func reset() {
        isRunning = false
        phase = .focus
        remaining = focusLength
    }

    private func tick(seconds: Int) {
        guard remaining > 0 else {
            // flip phase and keep running
            phase = (phase == .focus) ? .break : .focus
            remaining = totalForPhase
            return
        }
        remaining = max(0, remaining - seconds)
    }

    private func setPreset(focus: Int, brk: Int) {
        // super simple: keep current phase, swap lengths by updating remaining proportionally if running
        let wasRunning = isRunning
        isRunning = false
        let oldTotal = totalForPhase
        let newTotal = (phase == .focus) ? focus : brk
        if oldTotal > 0 {
            // keep the same percentage left
            let pct = Double(remaining) / Double(oldTotal)
            remaining = max(1, Int(round(Double(newTotal) * pct)))
        } else {
            remaining = newTotal
        }
        // resume if it was running
        isRunning = wasRunning
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

#Preview {
    PomodoroView()
}
