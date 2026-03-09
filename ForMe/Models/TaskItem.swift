//
//  TaskItem.swift
//  ForMe
//
//  SwiftData model for task tracking with priority levels.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Priority Enum

enum Priority: Int, Codable, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2

    var color: Color {
        switch self {
        case .low:    return .green
        case .medium: return .yellow
        case .high:   return .red
        }
    }

    var label: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }

    var symbol: String {
        switch self {
        case .low:    return "arrow.down.circle.fill"
        case .medium: return "equal.circle.fill"
        case .high:   return "arrow.up.circle.fill"
        }
    }
}

// MARK: - TaskItem Model

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var priorityRaw: Int
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?

    init(
        title: String,
        priority: Priority = .medium,
        isCompleted: Bool = false,
        createdAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.priorityRaw = priority.rawValue
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    /// Convenience accessor for the Priority enum
    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }
}
