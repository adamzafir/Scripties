//
//  Screen2_5.swift
//  yapLONGER
//
//  Created by                              gelato for gelato on 17/11/25.
//
import SwiftUI
struct Screen2_5: View {
    @Binding var title: String
    @Binding var script: String
    
    var body: some View {
        Text("Screen 2.5 - Beta Feature")
            .navigationTitle(title)
    }
}
