//
//  ContentView.swift
//  chatur
//
//  Created by ashwani on 07/07/25.
//

import SwiftUI



struct ContentView: View {
    @State private var showMenu = false
    @State private var selectedPage: Page? = .main
    @EnvironmentObject var loc: LocationController

    var body: some View {
        NavigationStack {
            ZStack(alignment: .leading) {
                // Main Content Area
                Group {
                    switch selectedPage {
                    case .main: MainPageView()
                    case .pageLocation: LocationView()
                    case .pageCamera: CameraView()
                    case .pageGeospatialAR: GeospatialScreen()
                    case .pageNotepad: NotepadView()
                    case .pageFinance: FinanceView()
                    case .pagePomodoro: PomodoroView()
                    case .none: MainPageView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)

                // Overlay Menu
                if showMenu {
                    SideMenuView(selectedPage: $selectedPage, showMenu: $showMenu)
                        .frame(width: 240)
                        .background(.ultraThinMaterial)
                        .cornerRadius(1)
                        .shadow(radius: 1)
                        .padding(.top, 10)
                        .padding(.leading, 0)
                        .transition(.move(edge: .leading))
                        .zIndex(1)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation {
                            showMenu.toggle()
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .imageScale(.large)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
