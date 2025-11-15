//
//  FinanceView.swift
//  chatur
//
//  Created by ashwani on 15/08/25.
//


//
//  RentSplitView.swift
//  chatur
//
//  Created by ashwani on 15/08/25.
//


import SwiftUI

struct FinanceView: View {
    // Inputs
       @State private var totalBill: Double = 5545        // full bill: rent + utilities
       @State private var totalRent: Double = 5545        // sum of everyone's rent
       @State private var myRentShare: Double = 1195      // your base rent share

       private let peopleCount: Int = 5

       // Computed
       private var utilities: Double { totalBill - totalRent }
       private var perPersonUtility: Double { utilities / Double(peopleCount) }
       private var myTotalDue: Double { myRentShare + perPersonUtility }
       private var isShort: Bool { utilities < 0 } // bill < rent

        @StateObject private var store = HardCostController()

//        private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

        private var monthlyTotal: Double {
            store.items.filter(\.included).reduce(0) { $0 + $1.amount * $1.cadence.monthlyMultiplier }
        }
        private var yearlyTotal: Double { monthlyTotal * 12 }
    // Track focus for any amount field by row ID
    @FocusState private var focusedAmountID: UUID?
       var body: some View {
           VStack(spacing: 8) {
               // Summary
               VStack(alignment: .leading, spacing: 8) {
                   labeledField("Total Bill", value: $totalBill)
                   labeledField("Total Rent (all 5)", value: $totalRent)
                   labeledField("My Rent Share", value: $myRentShare)
                   row("Utilities (Bill − Rent)", value: utilities, highlight: isShort)
                   row("Utility Share / person", value: perPersonUtility, highlight: isShort)
                   Divider()
                   row("My Total = Rent + Share", value: myTotalDue, bold: true)
               }
               .padding(12)
               .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

               if isShort {
                   Text("⚠️ Bill is less than total rent — utilities are negative.")
                       .font(.footnote)
                       .foregroundStyle(.red)
               }

               Spacer(minLength: 0)
               
               // Summary card
               VStack(alignment: .leading, spacing: 8) {
                   HStack {
                       Text("Monthly Total")
                       Spacer()
                       Text(monthlyTotal, format: .currency(code: currencyCode)).bold().monospacedDigit()
                   }
                   HStack {
                       Text("Yearly Total")
                       Spacer()
                       Text(yearlyTotal, format: .currency(code: currencyCode)).monospacedDigit()
                   }
               }
               .padding(12)
               .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
               .shadow(radius: 3)

               // Table-like grid
               ScrollView {
                   Grid(verticalSpacing: 8) {
                       // Header
                       GridRow {
                           Text("No").fontWeight(.semibold)
                           Text("Itm").fontWeight(.semibold)
                           Text("Amt").fontWeight(.semibold)
                           Text("Reo").fontWeight(.semibold)
                           Spacer()
                       }
                       .padding(.horizontal, 6)

                       Divider()

                       // Rows (editable)
                       ForEach($store.items) { $item in
                           GridRow {
                               // New checkbox-style
                               Button {
                                   item.included.toggle()
                               } label: {
                                   Image(systemName: item.included ? "checkmark.square" : "square")
                                       .font(.title3)
                               }
                               .buttonStyle(.plain)

                               TextField("Name", text: $item.name)
                                   .textFieldStyle(.roundedBorder)
                                   .frame(width: 60)

                               TextField("0", value: $item.amount, format: .number)
                                   .keyboardType(.decimalPad)
                                   .multilineTextAlignment(.trailing)
                                   .textFieldStyle(.roundedBorder)
                                   .focused($focusedAmountID, equals: item.id) // 👈 tie focus to this row
                                   .frame(width: 60)

                               Picker("", selection: $item.cadence) {
                                   ForEach(Cadence.allCases) { c in
                                       Text(c.label).tag(c)
                                   }
                               }
                               .pickerStyle(.menu)
                               .frame(width: 40)
                               
                               // Delete button
                               Button(role: .destructive) {
                                   if let idx = store.items.firstIndex(where: { $0.id == item.id }) {
                                       store.items.remove(at: idx)
                                   }
                               } label: {
                                   Image(systemName: "trash")
                               }
                               .buttonStyle(.plain)
                               .frame(width: 5)
                           }
                       }
                   }
                   .padding(12)
                   .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                   .shadow(radius: 3)
               }
               .scrollDismissesKeyboard(.interactively)     // 👈 swipe to dismiss
               .onTapGesture { focusedAmountID = nil }       // 👈 tap outside to dismiss


               // Add row
               Button {
                   store.items.append(CostItem(name: "", amount: 0, cadence: .monthly))
               } label: {
                   Label("Add Cost", systemImage: "plus.circle.fill")
                       .font(.headline)
               }
               .buttonStyle(.borderedProminent)
           }
           .padding()
           .toolbar {
//               // Optional: quick toggle to count one-time costs (amortize over 12 months)
//               Menu {
//                   Button("Count One-time (amortize/12)") {
//                       // convert any one-time items to yearly to spread cost:
//                       for i in store.items.indices {
//                           if store.items[i].cadence == .oneTime {
//                               store.items[i].cadence = .yearly
//                           }
//                       }
//                   }
//               } label: {
//                   Image(systemName: "gearshape")
//               }
               
               // Keyboard toolbar with Done button
               ToolbarItemGroup(placement: .keyboard) {
                   Spacer()
                   Button("Done") { focusedAmountID = nil } // 👈 dismiss keyboard
               }
           }
           .padding()
       }

       // MARK: - Helpers
       private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

       @ViewBuilder
       private func labeledField(_ title: String, value: Binding<Double>) -> some View {
           HStack {
               Text(title)
               Spacer()
               TextField("0", value: value, format: .number)
                   .keyboardType(.decimalPad)
                   .multilineTextAlignment(.trailing)
                   .textFieldStyle(.roundedBorder)
                   .frame(width: 160)
           }
       }

       @ViewBuilder
       private func row(_ title: String, value: Double, highlight: Bool = false, bold: Bool = false) -> some View {
           HStack {
               Text(title)
               Spacer()
               Text(value.formatted(.currency(code: currencyCode)))
                   .monospacedDigit()
                   .fontWeight(bold ? .semibold : .regular)
                   .foregroundStyle(highlight ? .red : .primary)
           }
       }
}

#Preview {
    NavigationStack { FinanceView() }
}
