//
//  TaskRow.swift
//  ForMe
//
//  Reusable task row with checkbox, priority dot, and selection state.
//

import SwiftUI
import SwiftData

struct TaskRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: TaskItem
    var isSelected: Bool = false

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Button {
                withAnimation(.spring(response: 0.35)) {
                    task.isCompleted.toggle()
                    task.completedAt = task.isCompleted ? .now : nil
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(task.isCompleted ? .green : .white.opacity(0.4))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            // Task title
            Text(task.title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(task.isCompleted ? .white.opacity(0.3) : .white.opacity(0.9))
                .strikethrough(task.isCompleted, color: .white.opacity(0.3))
                .lineLimit(2)
                .animation(.easeInOut(duration: 0.2), value: task.isCompleted)

            Spacer()

            // Priority dot
            Circle()
                .fill(task.priority.color)
                .frame(width: 8, height: 8)
                .opacity(task.isCompleted ? 0.3 : 0.9)

            // Delete button (hover)
            if isHovering || isSelected {
                Button {
                    withAnimation { modelContext.delete(task) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.blue.opacity(0.15) : (isHovering ? Color.white.opacity(0.06) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue.opacity(0.3) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
        }
    }
}
