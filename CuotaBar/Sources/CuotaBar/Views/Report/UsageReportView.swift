import Charts
import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct UsageReportView: View {
    @ObservedObject var historyStore: UsageHistoryStore
    @ObservedObject var settings: SettingsStore
    @State private var period: ReportPeriod = .week

    private var language: AppLanguage { settings.appLanguage }

    enum ReportPeriod: CaseIterable {
        case week, month

        func label(in language: AppLanguage) -> String {
            language.text(english: "\(days) days", spanish: "\(days) días", japanese: "\(days)日間")
        }

        var days: Int {
            switch self {
            case .week: 7
            case .month: 30
            }
        }
    }

    private var cutoffDate: Date {
        Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: -(period.days - 1), to: Date())!
        )
    }

    private var filteredRecords: [UsageDailyRecord] {
        return historyStore.records.filter { $0.date >= cutoffDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // ヘッダー
            HStack {
                Text(AppStrings(language: language).openReport)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(CuotaBarTheme.strongText)

                Spacer()

                Picker("", selection: $period) {
                    ForEach(ReportPeriod.allCases, id: \.self) { p in
                        Text(p.label(in: language)).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            // グラフ
            if filteredRecords.isEmpty {
                ContentUnavailableView(
                    language.text(english: "No Data", spanish: "Sin datos", japanese: "データなし"),
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text(language.text(english: "No usage data recorded yet.", spanish: "Aún no se han registrado datos de uso.", japanese: "まだ使用量が記録されていません。"))
                )
                .frame(height: 200)
            } else {
                Chart {
                    ForEach(filteredRecords) { record in
                        LineMark(
                            x: .value(language.text(english: "Date", spanish: "Fecha", japanese: "日付"), record.date, unit: .day),
                            y: .value(language.text(english: "Usage", spanish: "Uso", japanese: "使用率"), record.maxPercent)
                        )
                        .foregroundStyle(by: .value(language.text(english: "Service", spanish: "Servicio", japanese: "サービス"), record.service.displayName))
                        .symbol(by: .value(language.text(english: "Service", spanish: "Servicio", japanese: "サービス"), record.service.displayName))
                        .interpolationMethod(.catmullRom)
                    }

                    RuleMark(y: .value(language.text(english: "Threshold", spanish: "Umbral", japanese: "しきい値"), settings.thresholdPercent))
                        .foregroundStyle(.red.opacity(0.5))
                        .lineStyle(StrokeStyle(dash: [4, 4]))
                        .annotation(position: .trailing) {
                            Text("\(Int(settings.thresholdPercent))%")
                                .font(.caption2)
                                .foregroundStyle(.red.opacity(0.7))
                        }
                }
                .chartXScale(domain: cutoffDate...Date())
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") }
                    }
                }
                .chartForegroundStyleScale([
                    "Codex": Color.blue,
                    "Claude Code": Color.orange
                ])
                .frame(height: 200)
            }

            // ハイライトカード
            HStack(spacing: 12) {
                ForEach(ServiceKind.allCases) { service in
                    highlightCard(for: service)
                }
            }

            // エクスポートボタン
            HStack {
                Spacer()
                Button {
                    exportData(as: "csv")
                } label: {
                    Label(language.text(english: "Export CSV", spanish: "Exportar CSV", japanese: "CSV でエクスポート"), systemImage: "tablecells")
                }
                .buttonStyle(.bordered)

                Button {
                    exportData(as: "json")
                } label: {
                    Label(language.text(english: "Export JSON", spanish: "Exportar JSON", japanese: "JSON でエクスポート"), systemImage: "curlybraces")
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .environment(\.locale, language.locale)
        .padding(24)
        .frame(width: 600, height: 500)
        .background(CuotaBarTheme.canvasBottom.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func highlightCard(for service: ServiceKind) -> some View {
        let serviceRecords = filteredRecords.filter { $0.service == service }
        let maxRecord = serviceRecords.max(by: { $0.maxPercent < $1.maxPercent })
        let avgPercent = serviceRecords.isEmpty
            ? 0
            : serviceRecords.map(\.maxPercent).reduce(0, +) / Double(serviceRecords.count)

        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ServiceLogoMark(service: service, size: 20)
                    Text(service.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CuotaBarTheme.strongText)
                }
                Divider()
                if let maxRecord {
                    LabeledContent(
                        language.text(english: "Peak", spanish: "Máximo", japanese: "最高"),
                        value: "\(Int(maxRecord.maxPercent))% (\(maxRecord.date.formatted(.dateTime.month().day().locale(language.locale))))"
                    )
                } else {
                    LabeledContent(language.text(english: "Peak", spanish: "Máximo", japanese: "最高"), value: "—")
                }
                LabeledContent(
                    language.text(english: "Average", spanish: "Media", japanese: "平均"),
                    value: serviceRecords.isEmpty ? "—" : "\(Int(avgPercent))%"
                )
                let count = serviceRecords.count
                LabeledContent(
                    language.text(english: "Recorded days", spanish: "Días registrados", japanese: "記録日数"),
                    value: language.text(
                        english: count == 1 ? "1 day" : "\(count) days",
                        spanish: count == 1 ? "1 día" : "\(count) días",
                        japanese: "\(count)日"
                    )
                )
            }
            .font(.system(size: 12))
        }
        .frame(maxWidth: .infinity)
    }

    private func exportData(as format: String) {
        let panel = NSSavePanel()
        panel.title = language.text(english: "Export", spanish: "Exportar", japanese: "エクスポート")
        panel.prompt = panel.title
        panel.nameFieldStringValue = "cuotabar_usage.\(format)"
        if format == "csv" {
            panel.allowedContentTypes = [.commaSeparatedText]
        } else {
            panel.allowedContentTypes = [.json]
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        if format == "csv" {
            let csv = buildCSV()
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        } else {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try? encoder.encode(historyStore.records)
            try? data?.write(to: url, options: .atomic)
        }
    }

    private func buildCSV() -> String {
        var lines = ["date,service,max_percent"]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        for record in historyStore.records.sorted(by: { $0.date < $1.date }) {
            lines.append("\(formatter.string(from: record.date)),\(record.service.rawValue),\(Int(record.maxPercent))")
        }
        return lines.joined(separator: "\n")
    }
}

#if DEBUG
private struct UsageReportViewPreview: PreviewProvider {
    static var previews: some View {
        UsageReportView(historyStore: UsageHistoryStore(), settings: PreviewSupport.settings)
            .previewDisplayName("Usage Report")
    }
}
#endif
