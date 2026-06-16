//
//  SplashView.swift
//  Ar
//
//  Created by a on 2026/6/1.
//

import SwiftUI

struct SplashView: View {
    @State private var showText = false
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                Text("Scene Filter Camera")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.orange)
                    .scaleEffect(showText ? 1 : 0.5)
                    .opacity(showText ? 1 : 0)

                Text("Focus on Scenery · Architecture · Objects")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(showText ? 0.8 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showText = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onFinish()
            }
        }
    }
}

#Preview {
    SplashView() {}
}
