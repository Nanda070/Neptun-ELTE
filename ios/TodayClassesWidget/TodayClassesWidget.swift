import WidgetKit
import SwiftUI

/// Shared App Group — timetable snapshot only (no JWT / passwords).
enum TodayClassesStore {
  static let appGroupId = "group.com.nanda070.neptunmobile"
  static let jsonKey = "todayClassesJson"
  /// Opens calendar via the same shortcut id path as Quick Actions (item 13).
  static let openCalendarURL = URL(string: "neptunelte://shortcut/calendar")!

  static func loadPayload() -> TodayClassesPayload? {
    guard let defaults = UserDefaults(suiteName: appGroupId),
          let raw = defaults.string(forKey: jsonKey),
          let data = raw.data(using: .utf8) else {
      return nil
    }
    return try? JSONDecoder().decode(TodayClassesPayload.self, from: data)
  }
}

struct TodayClassItem: Codable, Identifiable {
  let title: String
  let start: String
  let end: String
  let location: String

  var id: String { "\(start)-\(title)" }

  var startDate: Date? { ISO8601DateFormatter.parse(start) }
  var endDate: Date? { ISO8601DateFormatter.parse(end) }

  var timeRangeLabel: String {
    let f = DateFormatter()
    f.locale = Locale.current
    f.dateFormat = "HH:mm"
    let a = startDate.map { f.string(from: $0) } ?? "--:--"
    let b = endDate.map { f.string(from: $0) } ?? "--:--"
    return "\(a)–\(b)"
  }
}

struct TodayClassesPayload: Codable {
  let hasCache: Bool?
  let updatedAt: String?
  let stale: Bool?
  let classes: [TodayClassItem]?
}

private extension ISO8601DateFormatter {
  static func parse(_ raw: String) -> Date? {
    let withFrac = ISO8601DateFormatter()
    withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = withFrac.date(from: raw) { return d }
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    return plain.date(from: raw)
  }
}

struct TodayClassesEntry: TimelineEntry {
  let date: Date
  let payload: TodayClassesPayload?
}

struct TodayClassesProvider: TimelineProvider {
  func placeholder(in context: Context) -> TodayClassesEntry {
    TodayClassesEntry(
      date: Date(),
      payload: TodayClassesPayload(
        hasCache: true,
        updatedAt: nil,
        stale: false,
        classes: [
          TodayClassItem(
            title: "Sample class",
            start: Date().toIso8601(),
            end: Date().addingTimeInterval(5400).toIso8601(),
            location: "Room 1"
          ),
        ]
      )
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (TodayClassesEntry) -> Void) {
    completion(TodayClassesEntry(date: Date(), payload: TodayClassesStore.loadPayload()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TodayClassesEntry>) -> Void) {
    let entry = TodayClassesEntry(date: Date(), payload: TodayClassesStore.loadPayload())
    // WidgetKit refresh cadence is OS-controlled; next policy nudges later today.
    let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
    completion(Timeline(entries: [entry], policy: .after(next)))
  }
}

struct TodayClassesWidget: Widget {
  let kind = "TodayClassesWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TodayClassesProvider()) { entry in
      Group {
        if #available(iOSApplicationExtension 17.0, *) {
          TodayClassesWidgetView(entry: entry)
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
          TodayClassesWidgetView(entry: entry)
            .padding(8)
            .background(Color(.secondarySystemBackground))
        }
      }
    }
    .configurationDisplayName("Today's classes")
    .description("Cached timetable for today. Open Neptun ELTE to refresh.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct TodayClassesWidgetView: View {
  var entry: TodayClassesEntry

  var body: some View {
    let payload = entry.payload
    let hasCache = payload?.hasCache == true
    let classes = payload?.classes ?? []
    let stale = payload?.stale == true

    Link(destination: TodayClassesStore.openCalendarURL) {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text("Today")
            .font(.headline)
            .foregroundStyle(.primary)
          Spacer(minLength: 0)
          if stale && hasCache {
            Text("Stale")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.orange)
          }
        }

        if !hasCache || payload == nil {
          Spacer(minLength: 0)
          Text("Open Neptun ELTE")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
          Spacer(minLength: 0)
          footer(text: "No cached timetable")
        } else if classes.isEmpty {
          Spacer(minLength: 0)
          Text("No classes today")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
          Spacer(minLength: 0)
          footer(text: stale ? "Stale cache · open app to refresh" : "Cached · open app to refresh")
        } else {
          ForEach(classes.prefix(familyLimit)) { item in
            VStack(alignment: .leading, spacing: 1) {
              Text(item.timeRangeLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
              Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
              if !item.location.isEmpty {
                Text(item.location)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
            }
          }
          Spacer(minLength: 0)
          footer(text: stale ? "Stale cache · open app to refresh" : "Cached · open app to refresh")
        }
      }
      .padding(.vertical, 2)
    }
  }

  private var familyLimit: Int {
    // Small shows 2 rows; medium up to 4.
    4
  }

  @ViewBuilder
  private func footer(text: String) -> some View {
    Text(text)
      .font(.caption2)
      .foregroundColor(.secondary)
      .lineLimit(1)
  }
}

private extension Date {
  func toIso8601() -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.string(from: self)
  }
}
