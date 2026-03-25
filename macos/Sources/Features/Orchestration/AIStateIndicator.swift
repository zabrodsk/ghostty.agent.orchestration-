import SwiftUI

/// AI state indicator with animations
struct AIStateIndicator: View {
    enum State {
        case active
        case waitingInput
        case processing
        case done
    }
    
    let state: State
    let isAnimating: Bool
    
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            switch state {
            case .active:
                Image(systemName: "brain")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                
            case .waitingInput:
                ZStack {
                    Circle()
                        .strokeBorder(Color.orange, lineWidth: 2)
                    
                    Image(systemName: "questionmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.orange)
                }
                .scaleEffect(isAnimating ? pulseScale : 1.0)
                .onAppear {
                    if isAnimating {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            pulseScale = 1.2
                        }
                    }
                }
                
            case .processing:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(rotationAngle))
                    .onAppear {
                        if isAnimating {
                            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                                rotationAngle = 360
                            }
                        }
                    }
                
            case .done:
                ZStack {
                    Circle()
                        .fill(Color.green)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: 20, height: 20)
    }
}
