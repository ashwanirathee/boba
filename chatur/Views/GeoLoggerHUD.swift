//
//  GeoLoggerHUD.swift
//  chatur
//
//  Created by ashwani on 21/08/25.
//
import SwiftUI

struct GeoLoggerHUD: View {
    @ObservedObject var log: LogStore
    let geoStatus: GeoStatus
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Geo: \(String(describing: geoStatus.state)) • \(String(describing: geoStatus.accuracy))")
                    .font(.caption2).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.green.opacity(0.25), in: Capsule())
                Spacer()
                Button(expanded ? "Hide" : "Show") { expanded.toggle() }
                    .font(.caption2)
                Button("Clear") { log.clear() }
                    .font(.caption2)
            }
            if expanded {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(log.lines.suffix(20).enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(height: 160)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.1)))
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }
}
