//
//  MainPageView.swift
//  chatur
//
//  Created by ashwani on 12/07/25.
//

import SwiftUI

struct MainPageView: View {
    @State private var now = Date()
    private let startDate: Date
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Provide locationController in the parent with .environmentObject(...)
    @EnvironmentObject var locationController: LocationController
    
    // friday
    @State private var isDone = false
    private let taskText = "brita cleanup, common space vacuum done"
    
    init() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        // ✅ Use a valid fallback if parsing fails
        self.startDate = formatter.date(from: "2000-12-10 09:00") ?? Date()
    }

    // Precompute lines to keep body simple
    private func nowLine(_ d: Date) -> String {
        "Now: \(d.formatted(.dateTime.hour().minute().second())), " +
        "\(d.formatted(.dateTime.weekday(.wide))), " +
        "\(d.formatted(.dateTime.day().month().year()))"
    }

    private func pbLine(_ d: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: startDate, to: d)
        let years = comps.year ?? 0
        let months = (comps.month ?? 0) + years * 12
        let days = cal.dateComponents([.day], from: startDate, to: d).day ?? 0
        return "PB-> Y: \(years), M: \(months), D: \(days)"
    }

    private func latLongLine() -> String {
        let lat = locationController.location.latitude
        let lon = locationController.location.longitude
        return String(format: "Lat: %.2f, Long: %.2f", lat, lon)
    }

    
    private var isFriday: Bool {
        Calendar.current.component(.weekday, from: now) == 6 // 1=Sun … 6=Fri
    }
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                Text(nowLine(now))
                Text(pbLine(now))
                Text(latLongLine())
            }
            .onReceive(timer) { now = $0 }
            .padding(12)
            .foregroundStyle(.primary)                         // adapts to light/dark
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) // denser than ultraThin
            
            if isFriday {
                VStack(spacing:8){
                    Button { isDone.toggle()
                        UIPasteboard.general.string = taskText   // copies text to clipboard
                    } label: {
                        Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                        Text(taskText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .foregroundStyle(.primary)                         // adapts to light/dark
                .background((isDone ? Color.green : Color.red), in: RoundedRectangle(cornerRadius: 12)) // lighter
            }
            
            WaterView()
            OutdoorTimeView()
        }}
    
}

#Preview {
    MainPageView()
}

struct WaterView: View {
    private let store = WaterDataController()
    @State private var amountML = 0

    // flexible amount picker
    @State private var stepML: Int = 250
    private let presets = [50, 100, 150, 200, 250, 300, 500, 750, 1000]

    // custom sheet
    @State private var showingCustom = false
    @State private var customText = "250"

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Today’s Water").font(.headline)

                HStack(spacing: 4) {
                    Text("\(amountML)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("ml")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                // Amount picker (menu-style dropdown)
                Menu {
                    ForEach(presets, id: \.self) { v in
                        Button("\(v) ml") { stepML = v }
                    }
                    Divider()
                    Button {
                        customText = "\(stepML)"
                        showingCustom = true
                    } label: {
                        Label("Custom…", systemImage: "slider.horizontal.3")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("\(stepML) ml")
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(.thinMaterial))
                }

                HStack(spacing: 12) {
                    Button {
                        amountML = store.changeToday(by: +stepML)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                    }
                    .buttonStyle(.bordered)

                    Button {
                        amountML = store.changeToday(by: -stepML)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 32))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThickMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.quaternary))
        .padding(.horizontal)
        .onAppear { amountML = store.amountToday() }
        .sheet(isPresented: $showingCustom) {
            NavigationStack {
                Form {
                    Section("Custom Amount (ml)") {
                        TextField("Amount in ml", text: $customText)
                            .keyboardType(.numberPad)
                    }
                }
                .navigationTitle("Set Amount")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingCustom = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            if let v = Int(customText), v > 0 { stepML = v }
                            showingCustom = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}


struct OutdoorTimeView: View {
    
    private let outside_time_store = OutsideDataController()
    @State private var minutes = 0
    private let step = 10   // minutes per tap

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Outside Time")
                    .font(.headline)

                HStack(spacing: 6) {
                    Text(formatted(minutes))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("today")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 12) {
                Button {
                    minutes = outside_time_store.changeToday(byMinutes: -step)
                } label: {
                    Image(systemName: "minus.circle.fill").font(.system(size: 32))
                }
                .buttonStyle(.bordered)

                Button {
                    minutes = outside_time_store.changeToday(byMinutes: +step)
                } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 32))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThickMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.quaternary))
        .padding(.horizontal)
        .onAppear { minutes = outside_time_store.minutesToday() }
    }
    
    private func formatted(_ m: Int) -> String {
        let h = m / 60, r = m % 60
        if h > 0 && r > 0 { return "\(h)h \(r)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}
