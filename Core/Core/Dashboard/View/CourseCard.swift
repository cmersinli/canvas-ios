//
// This file is part of Canvas.
// Copyright (C) 2020-present  Instructure, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import SwiftUI

struct CourseCard: View {
    @ObservedObject var card: DashboardCard
    let hideColorOverlay: Bool
    let showGrade: Bool
    let width: CGFloat

    @Environment(\.appEnvironment) var env
    @Environment(\.viewController) var controller

    var a11yGrade: String {
        guard let course = card.course, showGrade else { return "" }
        return course.displayGrade
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: {
                env.router.route(to: "/courses/\(card.id)", from: controller)
            }, label: {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack {
                        Color.accentColor.frame(width: width, height: 80)
                        card.imageURL.map { RemoteImage($0, width: width, height: 80) }?
                            .opacity(hideColorOverlay ? 1 : 0.4)
                            .clipped()
                            // Fix big course image consuming tap events.
                            .contentShape(Path(CGRect(x: 0, y: 0, width: width, height: 80)))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack { Spacer() }
                        Text(card.shortName)
                            .font(.semibold18).foregroundColor(.accentColor)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(card.courseCode)
                            .font(.semibold12).foregroundColor(.textDark)
                        Spacer()
                    }
                        .padding(.horizontal, 10).padding(.top, 8)
                }
                    .background(RoundedRectangle(cornerRadius: 4).stroke(Color(white: 0.89), lineWidth: 1 / UIScreen.main.scale))
                    .background(Color.white)
                    .cornerRadius(4)
                    .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
            })
                .buttonStyle(ScaleButtonStyle(scale: 1))
                .accessibility(label: Text(verbatim: "\(card.shortName) \(card.courseCode) \(a11yGrade)".trimmingCharacters(in: .whitespacesAndNewlines)))
                .identifier("DashboardCourseCell.\(card.id)")

            gradePill
                .accessibility(hidden: true) // handled in the button label
                .offset(x: 8, y: 8)

            customizeButton
                .offset(x: width - 44, y: 0)
        }
    }

    @ViewBuilder var customizeButton: some View {
        Button(action: {
            guard let course = card.course else { return }
            env.router.show(
                CoreHostingController(CustomizeCourseView(course: course, hideColorOverlay: hideColorOverlay)),
                from: controller,
                options: .modal(.formSheet, isDismissable: false, embedInNav: true)
            )
        }, label: {
            Image.moreSolid.foregroundColor(.white)
                .background(card.imageURL == nil || !hideColorOverlay ? nil :
                    Circle().fill(Color.accentColor).frame(width: 28, height: 28)
                )
                .frame(width: 44, height: 44)
        })
            .accessibility(label: Text("Open \(card.shortName) user preferences", bundle: .core))
            .identifier("DashboardCourseCell.\(card.id).optionsButton")
    }

    @ViewBuilder var gradePill: some View {
        if showGrade, let course = card.course {
            HStack {
                if course.hideTotalGrade {
                    Image.lockSolid.size(14)
                } else {
                    Text(course.displayGrade).font(.semibold14)
                }
            }
                .foregroundColor(.accentColor)
                .padding(.horizontal, 6).frame(height: 20)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                .frame(maxWidth: 120, alignment: .leading)
        }
    }
}
