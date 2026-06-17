//
//  ConfigurationIssueRows.swift
//  Ortto iOS SDK Push Demo
//

import SwiftUI

struct ConfigurationIssueRows: View {
    let issues: [SDKConfigurationIssue]

    var body: some View {
        ForEach(issues) { issue in
            VStack(alignment: .leading, spacing: 3) {
                Text(issue.title)
                    .foregroundStyle(issue.severity.tint)
                Text(issue.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
