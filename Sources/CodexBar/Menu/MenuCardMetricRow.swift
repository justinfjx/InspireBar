import SwiftUI

struct MetricRow: View {
    let title: String
    let value: String
    var emphasized = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(self.title).font(.body)
            Spacer(minLength: 12)
            Text(self.value)
                .font(self.emphasized ? .title3.weight(.semibold) : .body)
                .foregroundStyle(self.emphasized ? .primary : .secondary)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
