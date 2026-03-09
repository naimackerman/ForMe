//
//  FloatingIslandView.swift
//  ForMe
//
//  Menu bar popup with inline Task List / Calendar toggle (⌘D).
//
//  Task mode:  ⌘1/2/3 priority  ↑↓ navigate  Space complete  ⌫ delete
//  Calendar:   ←→ days  ⌘D back  Escape back
//

import SwiftUI
import SwiftData
import AppKit

struct FloatingIslandView: View {
    @Environment(PrayerTimeManager.self) private var prayerManager
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<TaskItem> { !$0.isCompleted },
        sort: [SortDescriptor(\TaskItem.priorityRaw, order: .reverse), SortDescriptor(\TaskItem.createdAt)]
    )
    private var pendingTasks: [TaskItem]

    @Query(
        filter: #Predicate<TaskItem> { $0.isCompleted },
        sort: [SortDescriptor(\TaskItem.completedAt, order: .reverse)]
    )
    private var completedTasks: [TaskItem]

    @State private var showingCalendar = false
    @State private var newTaskTitle = ""
    @State private var selectedPriority: Priority = .medium
    @State private var selectedIndex: Int? = nil
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var keyMonitor: Any?
    @State private var isRefreshing = false

    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if showingCalendar {
                calendarMode
            } else {
                taskMode
            }

            Divider()
            hints
        }
        .frame(width: 360)
        .preferredColorScheme(.dark)
        .task { await prayerManager.startFetching() }
        .onAppear { installKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━ HEADER ━━━━━━━━━━━━━━━━━━━━━━━━━

    private var header: some View {
        VStack(spacing: 6) {
            // Prayer times row
            if let schedule = prayerManager.schedule {
                HStack(spacing: 0) {
                    ForEach(schedule.all, id: \.name) { prayer in
                        let isNext = isNextPrayer(prayer.name)
                        VStack(spacing: 2) {
                            Text(prayer.name)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(isNext ? .yellow : .white.opacity(0.45))
                            Text(prayer.time, format: .dateTime.hour().minute())
                                .font(.system(size: 11, weight: isNext ? .bold : .medium, design: .monospaced))
                                .foregroundStyle(isNext ? .white : .white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isNext ? Color.yellow.opacity(0.12) : .clear)
                        )
                    }
                }
                .padding(.horizontal, 10)
            }

            // Next prayer countdown + toggle button
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.yellow)
                Text(prayerManager.nextPrayerString)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Spacer()

                if !prayerManager.cityName.isEmpty {
                    Text("\(prayerManager.cityName) (\(prayerManager.locationSource))")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .help(prayerManager.latitude != nil ? String(format: "Lat: %.4f, Lng: %.4f", prayerManager.latitude!, prayerManager.longitude!) : "Coordinates loading…")
                }

                Button {
                    Task {
                        isRefreshing = true
                        await prayerManager.startFetching(force: true)
                        isRefreshing = false
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)

                Button {
                    toggleCalendar()
                } label: {
                    Image(systemName: showingCalendar ? "checklist" : "calendar")
                        .font(.system(size: 13))
                        .foregroundStyle(showingCalendar ? .blue : .white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 8)
    }

    private func isNextPrayer(_ name: String) -> Bool {
        guard let schedule = prayerManager.schedule else { return false }
        let now = Date()
        if let next = schedule.all.first(where: { $0.time > now }) {
            return next.name == name
        }
        return name == "Fajr" // After Isha, Fajr is next
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━ TASK MODE ━━━━━━━━━━━━━━━━━━━━━━━━━

    private var taskMode: some View {
        VStack(spacing: 0) {
            // Input
            HStack(spacing: 8) {
                Menu {
                    ForEach(Priority.allCases, id: \.rawValue) { p in
                        Button { selectedPriority = p } label: {
                            Label("\(p.label) (⌘\(p.rawValue + 1))", systemImage: p.symbol)
                        }
                    }
                } label: {
                    Image(systemName: selectedPriority.symbol)
                        .font(.system(size: 14))
                        .foregroundStyle(selectedPriority.color)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 20)

                TextField("Add a task…", text: $newTaskTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .rounded))
                    .onSubmit { addTask() }

                if !newTaskTitle.isEmpty {
                    Button { addTask() } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16)).foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)

            Divider()

            // Task list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        if pendingTasks.isEmpty {
                            emptyView("checkmark.seal.fill", "All clear!", "Add a task above")
                        } else {
                            ForEach(Array(pendingTasks.enumerated()), id: \.element.id) { i, task in
                                TaskRow(task: task, isSelected: selectedIndex == i)
                                    .id(task.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedIndex = (selectedIndex == i) ? nil : i
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                }
                .onChange(of: selectedIndex) { _, idx in
                    if let idx, idx < pendingTasks.count {
                        withAnimation { proxy.scrollTo(pendingTasks[idx].id, anchor: .center) }
                    }
                }
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━ CALENDAR MODE ━━━━━━━━━━━━━━━━━━━━━━━━━

    private var calendarMode: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Month nav
                HStack {
                    Button { navMonth(-1) } label: {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                    }.buttonStyle(.plain)
                    Spacer()
                    Text(monthStr)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Spacer()
                    Button { navMonth(1) } label: {
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 6)

                CalendarHeatmap(
                    month: displayedMonth,
                    completedTasks: completedTasks,
                    selectedDate: $selectedDate
                )
                .padding(.horizontal, 10)

                Divider().padding(.top, 4)

                // Selected day header
                HStack {
                    Text(dayStr)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("\(tasksForDay.count) done")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Color(nsColor: .windowBackgroundColor))

                // Completed tasks
                if tasksForDay.isEmpty {
                    emptyView("tray", "No tasks", "completed on this day")
                } else {
                    LazyVStack(spacing: 1) {
                        ForEach(tasksForDay) { task in
                            HStack(spacing: 6) {
                                Circle().fill(task.priority.color).frame(width: 6, height: 6)
                                Text(task.title)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .lineLimit(1)
                                Spacer()
                                if let t = task.completedAt {
                                    Text(t, format: .dateTime.hour().minute())
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.35))
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(.white.opacity(0.05))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━ HINTS ━━━━━━━━━━━━━━━━━━━━━━━━━

    private var hints: some View {
        HStack(spacing: 8) {
            if showingCalendar {
                hk("←→", "Days"); hk("⌘D", "Tasks")
            } else {
                hk("↑↓", "Nav"); hk("⎵", "Done"); hk("⌫", "Del"); hk("⌘D", "Cal")
            }
            Spacer()
            hk("⌘1/2/3", "Pri")
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
    }

    private func hk(_ key: String, _ label: String) -> some View {
        HStack(spacing: 2) {
            Text(key)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 3).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.07)))
            Text(label)
                .font(.system(size: 8, design: .rounded))
                .foregroundStyle(.white.opacity(0.25))
        }
    }

    private func emptyView(_ icon: String, _ t: String, _ s: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(.white.opacity(0.15))
            Text(t).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.3))
            Text(s).font(.system(size: 9, design: .rounded)).foregroundStyle(.white.opacity(0.2))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━ HELPERS ━━━━━━━━━━━━━━━━━━━━━━━━━

    private func toggleCalendar() {
        showingCalendar.toggle()
        if showingCalendar {
            selectedDate = Date()
            displayedMonth = Date()
        }
    }

    private var monthStr: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f.string(from: displayedMonth)
    }

    private func navMonth(_ v: Int) {
        if let m = cal.date(byAdding: .month, value: v, to: displayedMonth) { displayedMonth = m }
    }

    private var tasksForDay: [TaskItem] {
        completedTasks.filter { t in
            guard let d = t.completedAt else { return false }
            return cal.isDate(d, inSameDayAs: selectedDate)
        }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    private var dayStr: String {
        let f = DateFormatter(); f.dateFormat = "EEE, d MMM"
        let s = f.string(from: selectedDate)
        return cal.isDateInToday(selectedDate) ? "\(s) (Today)" : s
    }

    private func addTask() {
        let t = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        modelContext.insert(TaskItem(title: t, priority: selectedPriority))
        newTaskTitle = ""
    }

    private func completeSelected() {
        guard let i = selectedIndex, i >= 0, i < pendingTasks.count else { return }
        pendingTasks[i].isCompleted = true
        pendingTasks[i].completedAt = .now
        if pendingTasks.count <= 1 { selectedIndex = nil }
        else if i >= pendingTasks.count - 1 { selectedIndex = max(0, pendingTasks.count - 2) }
    }

    private func deleteSelected() {
        guard let i = selectedIndex, i >= 0, i < pendingTasks.count else { return }
        modelContext.delete(pendingTasks[i])
        if pendingTasks.count <= 1 { selectedIndex = nil }
        else if i >= pendingTasks.count - 1 { selectedIndex = max(0, pendingTasks.count - 2) }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━ KEYBOARD ━━━━━━━━━━━━━━━━━━━━━━━━━

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            if e.modifierFlags.contains(.command) {
                switch e.characters {
                case "1": selectedPriority = .low; return nil
                case "2": selectedPriority = .medium; return nil
                case "3": selectedPriority = .high; return nil
                case "d", "D": toggleCalendar(); return nil
                default: break
                }
            }
            return showingCalendar ? calKey(e) : taskKey(e)
        }
    }

    private func taskKey(_ e: NSEvent) -> NSEvent? {
        switch e.keyCode {
        case 125: // ↓
            if let i = selectedIndex { selectedIndex = pendingTasks.isEmpty ? nil : max(0, min(i + 1, pendingTasks.count - 1)) }
            else if !pendingTasks.isEmpty { selectedIndex = 0 }
            return nil
        case 126: // ↑
            if let i = selectedIndex { selectedIndex = max(i - 1, 0) }
            else if !pendingTasks.isEmpty { selectedIndex = pendingTasks.count - 1 }
            return nil
        case 49: // Space
            if selectedIndex != nil { completeSelected(); return nil }
        case 51: // ⌫
            if selectedIndex != nil && newTaskTitle.isEmpty { deleteSelected(); return nil }
        case 53: // Esc
            if selectedIndex != nil { selectedIndex = nil; return nil }
        default: break
        }
        return e
    }

    private func calKey(_ e: NSEvent) -> NSEvent? {
        switch e.keyCode {
        case 123: // ←
            let prev = cal.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            selectedDate = prev
            if cal.component(.month, from: prev) != cal.component(.month, from: displayedMonth) {
                displayedMonth = prev
            }
            return nil
        case 124: // →
            let today = cal.startOfDay(for: Date())
            if cal.startOfDay(for: selectedDate) < today {
                let next = cal.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                selectedDate = next
                if cal.component(.month, from: next) != cal.component(.month, from: displayedMonth) {
                    displayedMonth = next
                }
            }
            return nil
        case 53: // Esc
            showingCalendar = false; return nil
        default: break
        }
        return e
    }

    private func removeKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }
}
