import SwiftUI
import Charts

/// Line chart that always plots against the selected lookback, so 7 vs 30 days is visible
/// even when HealthKit only has points on some of those days.
struct TrendChart: View {
    let points: [ChartPoint]
    let color: Color
    let height: CGFloat
    var domain: ClosedRange<Date>
    var showXAxis: Bool = false
    var showYAxis: Bool = false
    var pointSize: CGFloat = 16

    var body: some View {
        let chart = Chart(points) { p in
            LineMark(x: .value("date", p.date), y: .value("value", p.value))
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)
            PointMark(x: .value("date", p.date), y: .value("value", p.value))
                .foregroundStyle(color)
                .symbolSize(pointSize)
        }
        .frame(height: height)
        .chartXScale(domain: domain)
        .chartYAxis(showYAxis ? .automatic : .hidden)

        if showXAxis {
            chart.chartXAxis {
                AxisMarks(values: .stride(by: xStride))
            }
        } else {
            chart.chartXAxis(.hidden)
        }
    }

    private var xStride: Calendar.Component {
        let days = Calendar.current.dateComponents([.day], from: domain.lowerBound, to: domain.upperBound).day ?? 0
        if days <= 8 { return .day }
        if days <= 45 { return .weekOfYear }
        return .month
    }
}
