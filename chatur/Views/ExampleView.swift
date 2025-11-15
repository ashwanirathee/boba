//
//  ExampleView.swift
//  chatur
//
//  Created by ashwani on 12/07/25.
//

import SwiftUI

struct ExampleView: View {
    @EnvironmentObject var locationController: LocationController

    var body: some View {
        VStack(spacing: 8) {
            Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
        }
    }
}

#Preview {
    ExampleView()
}
