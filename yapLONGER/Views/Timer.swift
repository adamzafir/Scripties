//
//  startGame.swift
//  Challenge 2
//
//  Created by Ethan Soh on 16/8/25.
//

import SwiftUI
import MapKit
import Foundation

struct startGame: View {
    
    @Namespace private var animation
    @State private var imageScale: CGFloat = 1.0
    @State private var currentDate = Date.now
    @State private var elapsedTime: Int = 0
    @State private var timer: Timer? = nil
    @State var tapped = false
    
    @State private var showingAlert = false
    var formattedTime: String {
        let minutes = elapsedTime / 60
        let seconds = elapsedTime % 60
        return String(format: "%02d:%02d", minutes, seconds)
        
    }
    
    var body: some View {
        
    
            
            VStack {
                
                
                VStack{
                    Spacer()
                    Text("Time: \(formattedTime)")
                        .bold()
                        .monospaced()
                        .font(.largeTitle)
                        .padding(7)
                        .background(Color(red:12 , green:12 , blue: 12))
                        .clipShape(RoundedRectangle (cornerRadius: 10))
                        .padding()
                        .onAppear {
                            elapsedTime = 0
                            timer?.invalidate()
                            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                                elapsedTime += 1
                            }
                        }
                }
            }
        }
    }


func getDist(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let R = 6371e3; // metres
    let φ1 = lat1 * Double.pi/180; // φ, λ in radians
    let φ2 = lat2 * Double.pi/180;
    let Δφ = (lat2-lat1) * Double.pi/180;
    let Δλ = (lon2-lon1) * Double.pi/180;
    
    let a = sin(Δφ/2) * sin(Δφ/2) +
    cos(φ1) * cos(φ2) *
    sin(Δλ/2) * sin(Δλ/2);
    let c = 2 * atan2(sqrt(a), sqrt(1-a));
    
    let d = R * c; // in metres
    
    return d;
}


#Preview {
    startGame()
}
