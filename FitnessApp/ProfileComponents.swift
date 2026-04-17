import SwiftUI
import UIKit

// MARK: - Reusable Profile Avatar
struct ProfileAvatar: View {
    let imageData: Data?
    let initials: String

    var body: some View {
        Group {
            if let data = imageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Color(.systemGray5))
                    Text(initials)
                        .font(.system(size: 34, weight: .black))
                        .foregroundColor(.secondary)
                }
            }
        }
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(.systemGray4), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Reusable Profile Name Label
struct ProfileNameLabel: View {
    let fullName: String

    var body: some View {
        Text(fullName)
            .font(.headline)
            .foregroundColor(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

// MARK: - Reusable Profile Status Label
struct ProfileStatusLabel: View {
    let status: String?

    var body: some View {
        if let status = status, !status.isEmpty {
            Text(status)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

// MARK: - Reusable Profile Stack (Avatar + Name + Status)
struct ProfileStack: View {
    let imageData: Data?
    let initials: String
    let fullName: String
    let status: String?

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatar(imageData: imageData, initials: initials)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 4) {
                ProfileNameLabel(fullName: fullName)
                ProfileStatusLabel(status: status)
            }
        }
    }
}

