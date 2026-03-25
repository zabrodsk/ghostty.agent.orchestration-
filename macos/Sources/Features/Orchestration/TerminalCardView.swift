import SwiftUI
import GhosttyKit

/// Display card for individual terminal surface
struct TerminalCardView: View {
    let surface: SurfaceDisplayState
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // AI/Activity indicator
                stateIndicator
                    .frame(width: 20, height: 20)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(surface.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Process and CWD
                    HStack(spacing: 6) {
                        if !surface.activeProcess.isEmpty {
                            Text(surface.activeProcess)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        if !surface.cwd.isEmpty {
                            Text("·")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            Text(surface.cwdShort)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    // Last command or AI status
                    if let aiToolName = surface.aiToolName {
                        Text(aiToolName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue)
                    } else if !surface.lastCommand.isEmpty {
                        Text("$ \(surface.lastCommand)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var stateIndicator: some View {
        switch surface.aiState {
        case .ai_waiting_input:
            AIStateIndicator(state: .waitingInput, isAnimating: true)
        case .ai_processing:
            AIStateIndicator(state: .processing, isAnimating: true)
        case .ai_done:
            AIStateIndicator(state: .done, isAnimating: false)
        case .ai_active:
            AIStateIndicator(state: .active, isAnimating: false)
        default:
            activityIndicator
        }
    }
    
    @ViewBuilder
    private var activityIndicator: some View {
        switch surface.activityState {
        case .busy:
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
        case .waiting_input:
            Circle()
                .strokeBorder(Color.secondary, lineWidth: 1.5)
                .frame(width: 8, height: 8)
        default:
            Circle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 6, height: 6)
        }
    }
}
