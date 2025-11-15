//
//  SideMenuView.swift
//  chatur
//
//  Created by ashwani on 07/07/25.
//


import SwiftUI

enum Page {
    case main, pageLocation, pageCamera, pageGeospatialAR, pageNotepad, pageFinance, pagePomodoro
}

struct SideMenuView: View {
    @Binding var selectedPage: Page?
    @Binding var showMenu: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            menuItem(title: "Home", page: .main)
            menuItem(title: "Location Tracker", page: .pageLocation)
            menuItem(title: "Camera", page: .pageCamera)
            menuItem(title: "GeospatialAR", page: .pageGeospatialAR)
            menuItem(title: "Notepad", page: .pageNotepad)
            menuItem(title: "Finance", page: .pageFinance)
            menuItem(title: "Pomodoro", page: .pagePomodoro)
            Spacer()
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    func menuItem(title: String, page: Page) -> some View {
        Button(action: {
            withAnimation {
                selectedPage = page
                showMenu = false
            }
        }) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}


#Preview {
    SideMenuView(selectedPage: .constant(.main), showMenu: .constant(true))
}

