//
//  CalendarHeatmap.swift
//  ForMe
//
//  Locale-aware calendar grid with priority badges. Future days disabled.
//

import SwiftUI
import SwiftData

struct CalendarHeatmap: View {
    let month: Date
    let completedTasks: [TaskItem]
    @Binding var selectedDate: Date

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let calendar = Calendar.current

    private var orderedDaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private var calendarCells: [Int?] {
        let offset = firstWeekdayOffset
        var cells: [Int?] = Array(repeating: nil, count: offset)
        cells += (1...daysInMonth).map { $0 as Int? }
        let remainder = cells.count % 7
        if remainder > 0 { cells += Array(repeating: nil as Int?, count: 7 - remainder) }
        return cells
    }

    var body: some View {
        VStack(spacing: 6) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(orderedDaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(height: 20)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(calendarCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        let isFuture = isFutureDay(day)
                        let tasks = isFuture ? [] : completedTasksOn(day: day)
                        dayCellView(day: day, tasks: tasks, isFuture: isFuture)
                            .onTapGesture {
                                guard !isFuture else { return }
                                withAnimation(.spring(response: 0.25)) {
                                    selectedDate = dateForDay(day)
                                }
                            }
                    } else {
                        Color.clear.frame(height: 46)
                    }
                }
            }
        }
    }

    // MARK: - Day Cell

    private func dayCellView(day: Int, tasks: [TaskItem], isFuture: Bool) -> some View {
        let isToday = isCurrentDay(day)
        let isSelected = isSelectedDay(day)
        let highCount = tasks.filter { $0.priority == .high }.count
        let medCount = tasks.filter { $0.priority == .medium }.count
        let lowCount = tasks.filter { $0.priority == .low }.count

        return VStack(spacing: 2) {
            Text("\(day)")
                .font(.system(size: 12, weight: (isToday || isSelected) ? .bold : .regular, design: .rounded))
                .foregroundStyle(
                    isFuture ? .white.opacity(0.15) :
                    isSelected ? .blue :
                    isToday ? .white : .white.opacity(0.7)
                )

            if !tasks.isEmpty {
                HStack(spacing: 2) {
                    if highCount > 0 { badge(highCount, .red) }
                    if medCount > 0 { badge(medCount, .yellow) }
                    if lowCount > 0 { badge(lowCount, .green) }
                }
            }
        }
        .frame(height: 38)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isFuture ? .clear : cellBg(tasks.count, isToday, isSelected))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isSelected ? Color.blue.opacity(0.6) : .clear, lineWidth: 1.5)
        )
    }

    private func badge(_ count: Int, _ color: Color) -> some View {
        Text("\(count)")
            .font(.system(size: 7, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 12, height: 12)
            .background(Circle().fill(color.opacity(0.8)))
    }

    // MARK: - Helpers

    private var firstWeekdayOffset: Int {
        let comp = calendar.dateComponents([.year, .month], from: month)
        guard let firstDay = calendar.date(from: comp) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDay)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: month)?.count ?? 30
    }

    private func dateForDay(_ day: Int) -> Date {
        var comp = calendar.dateComponents([.year, .month], from: month)
        comp.day = day
        return calendar.date(from: comp) ?? month
    }

    private func isCurrentDay(_ day: Int) -> Bool {
        calendar.isDate(dateForDay(day), inSameDayAs: Date())
    }

    private func isSelectedDay(_ day: Int) -> Bool {
        calendar.isDate(dateForDay(day), inSameDayAs: selectedDate)
            && calendar.component(.month, from: selectedDate) == calendar.component(.month, from: month)
    }

    private func isFutureDay(_ day: Int) -> Bool {
        let dayDate = calendar.startOfDay(for: dateForDay(day))
        let today = calendar.startOfDay(for: Date())
        return dayDate > today
    }

    private func completedTasksOn(day: Int) -> [TaskItem] {
        completedTasks.filter { task in
            guard let d = task.completedAt else { return false }
            return calendar.isDate(d, inSameDayAs: dateForDay(day))
        }
    }

    private func cellBg(_ count: Int, _ isToday: Bool, _ isSelected: Bool) -> Color {
        if isSelected { return .blue.opacity(0.2) }
        if isToday { return .blue.opacity(0.12) }
        if count > 0 { return .green.opacity(min(Double(count) * 0.04, 0.2)) }
        return .white.opacity(0.03)
    }
}
