import SwiftUI
import WidgetKit

private let groupId = "group.com.example.medicineApp.reminders"
private func widgetText(_ key: String, fallback: String) -> String {
    let raw = UserDefaults(suiteName: groupId)?.string(forKey: "widget_copy") ?? "{}"
    let values = (try? JSONSerialization.jsonObject(with: Data(raw.utf8))) as? [String: String] ?? [:]
    return values[key] ?? fallback
}
private var widgetLocale: Locale {
    Locale(identifier: UserDefaults(suiteName: groupId)?.string(forKey: "widget_locale") ?? "tr")
}

struct ReminderWidgetItem: Identifiable {
    let id: String
    let title: String
    let at: Date
}
struct ReminderWidgetEntry: TimelineEntry {
    let date: Date
    let items: [ReminderWidgetItem]
    var scope: String = "guest"
}
struct ReminderWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReminderWidgetEntry {
        ReminderWidgetEntry(date: Date(), items: [ReminderWidgetItem(id: "preview", title: "Hatırlatıcı", at: Date().addingTimeInterval(3600))])
    }
    func getSnapshot(in context: Context, completion: @escaping (ReminderWidgetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : load())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ReminderWidgetEntry>) -> Void) {
        completion(Timeline(entries: [load()], policy: .after(Date().addingTimeInterval(1800))))
    }
    private func load() -> ReminderWidgetEntry {
        let text = UserDefaults(suiteName: groupId)?.string(forKey: "reminders") ?? "[]"
        let raw = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [[String: Any]] ?? []
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let basicFormatter = ISO8601DateFormatter()
        basicFormatter.formatOptions = [.withInternetDateTime]
        let local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        local.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        let items = raw.prefix(3).compactMap { item -> ReminderWidgetItem? in
            guard let id = item["id"] as? String, let title = item["title"] as? String,
                  let date = (item["snoozedUntil"] as? String) ?? (item["dueAt"] as? String),
                  let at = formatter.date(from: date)
                    ?? basicFormatter.date(from: date)
                    ?? local.date(from: date) else { return nil }
            return ReminderWidgetItem(id: id, title: title, at: at)
        }
        return ReminderWidgetEntry(date: Date(), items: items, scope: UserDefaults(suiteName: groupId)?.string(forKey: "account_scope") ?? "guest")
    }
}
struct ReminderWidgetView: View {
    let entry: ReminderWidgetEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    private let accent = Color(red: 0.73, green: 0.31, blue: 0.20)
    private var ink: Color { colorScheme == .dark ? .white : Color(red: 0.16, green: 0.18, blue: 0.17) }
    private func url(_ host: String, id: String? = nil) -> URL {
        var parts = URLComponents()
        parts.scheme = "medapp-reminder"; parts.host = host
        parts.queryItems = [URLQueryItem(name: "homeWidget", value: nil), URLQueryItem(name: "scope", value: entry.scope)]
        if let id { parts.queryItems?.append(URLQueryItem(name: "id", value: id)) }
        return parts.url!
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(widgetText("widget_title", fallback: "Sıradaki hatırlatıcılar")).font(.system(size: 14, weight: .bold)).foregroundStyle(ink)
                Spacer(minLength: 4)
                Link(destination: url("add")) { Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(accent) }.accessibilityLabel(widgetText("new_reminder", fallback: "Yeni hatırlatıcı"))
            }
            if entry.items.isEmpty {
                Spacer(minLength: 0)
                Text(widgetText("widget_empty", fallback: "Bekleyen hatırlatıcı yok.")).font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(Array(entry.items.prefix(family == .systemSmall ? 2 : 3))) { item in
                    HStack(spacing: 10) {
                        Link(destination: url("detail", id: item.id)) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(ink).lineLimit(1)
                                Text(item.at, format: .dateTime.day().month(.abbreviated).hour().minute()).font(.system(size: 11)).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Link(destination: url("done", id: item.id)) {
                            Image(systemName: "circle").font(.title3).foregroundStyle(accent).padding(4)
                        }.accessibilityLabel("\(item.title), \(widgetText("complete", fallback: "Tamamla"))")
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(for: .widget) { colorScheme == .dark ? Color(red: 0.09, green: 0.11, blue: 0.10) : Color(red: 0.97, green: 0.96, blue: 0.95) }
        .environment(\.locale, widgetLocale)
        .widgetURL(url("add"))
    }
}
@main
struct ReminderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ReminderWidget", provider: ReminderWidgetProvider()) { entry in ReminderWidgetView(entry: entry) }
            .configurationDisplayName(widgetText("app_name", fallback: "Shien"))
            .description(widgetText("widget_description", fallback: "Yaklaşan hatırlatıcıları gör ve yeni hatırlatıcı ekle."))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
