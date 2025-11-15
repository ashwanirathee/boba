//
//  NotepadView.swift
//  chatur
//
//  Created by ashwani on 15/08/25.
//


//
//  NotepadView.swift
//

import SwiftUI

struct NotepadView: View {
    // Persisted automatically in UserDefaults
    @AppStorage("notepad.text") private var text: String = ""
    @State private var showConfirm = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button(role: .destructive) {
                    showConfirm = true
                } label: {
                    Label("Clear", systemImage: "trash")
                }

                Spacer()

                // Hide keyboard button (optional)
                Button {
                    focused = false
                } label: {
                    Label("Done", systemImage: "keyboard.chevron.compact.down")
                }
                .disabled(!focused)
            }
            .padding()
            .background(.ultraThinMaterial)

            // Text area
            TextEditor(text: $text)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 8)
                .focused($focused)
//                .toolbar(.hidden, for: .navigationBar) // cleaner look
                .background(Color(white: 0.98))
        }
        .confirmationDialog("Clear all text?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { text = "" }
            Button("Cancel", role: .cancel) {}
        }
    }
}

#Preview {
    NotepadView()
}
