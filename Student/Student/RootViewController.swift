//
// This file is part of Canvas.
// Copyright (C) 2016-present  Instructure, Inc.
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

import Foundation
import UIKit
import ReactiveSwift
import CanvasCore
import Core

func rootViewController(_ session: Session) -> UIViewController {
    let tabs = CanvasTabBarController()
    tabs.viewControllers = [
        dashboardTab(session: session),
        calendarTab(session: session),
        todoTab(),
        NotificationsTab(),
        inboxTab(),
    ]

    let paths = [ "/", "/calendar", "/to-do", "/notifications", "/conversations" ]
    tabs.selectedIndex = AppEnvironment.shared.userDefaults?.landingPath
        .flatMap { paths.firstIndex(of: $0) } ?? 0
    tabs.tabBar.useGlobalNavStyle()
    return tabs
}

func dashboardTab(session: Session) -> UIViewController {
    let dashboardVC = HelmViewController(moduleName: "/", props: [:])
    let dashboardNav = HelmNavigationController(rootViewController: dashboardVC)
    let dashboardSplit = EnrollmentSplitViewController()
    let emptyNav = UINavigationController(rootViewController: EmptyViewController())
    dashboardNav.delegate = dashboardSplit
    dashboardNav.navigationBar.useGlobalNavStyle()
    dashboardSplit.viewControllers = [dashboardNav, emptyNav]
    dashboardSplit.tabBarItem.title = NSLocalizedString("Dashboard", comment: "dashboard page title")
    dashboardSplit.tabBarItem.image = .icon(.dashboard, .line)
    dashboardSplit.tabBarItem.selectedImage = .icon(.dashboard, .solid)
    dashboardSplit.tabBarItem.accessibilityIdentifier = "TabBar.dashboardTab"
    dashboardSplit.navigationItem.titleView = Brand.shared.headerImageView()
    return dashboardSplit
}

func calendarTab(session: Session) -> UIViewController {
    let calendar: UIViewController
    if ExperimentalFeature.studentCalendar.isEnabled {
        let split = HelmSplitViewController()
        split.viewControllers = [
            UINavigationController(rootViewController: PlannerViewController.create()),
            UINavigationController(rootViewController: EmptyViewController()),
        ]
        split.view.tintColor = Brand.shared.primary.ensureContrast(against: .named(.backgroundLightest))
        calendar = split
    } else {
        let month = CalendarMonthViewController.new(session)
        month.routeToURL = { url in
            AppEnvironment.shared.router.route(to: url, from: month)
        }
        calendar = UINavigationController(rootViewController: month)
    }
    calendar.tabBarItem.title = NSLocalizedString("Calendar", comment: "Calendar page title")
    calendar.tabBarItem.image = .icon(.calendarMonth, .line)
    calendar.tabBarItem.selectedImage = .icon(.calendarMonth, .solid)
    calendar.tabBarItem.accessibilityIdentifier = "TabBar.calendarTab"
    return calendar
}

func todoTab() -> UIViewController {
    let todo = HelmSplitViewController()
    todo.viewControllers = [
        UINavigationController(rootViewController: TodoListViewController.create()),
        UINavigationController(rootViewController: EmptyViewController()),
    ]
    todo.tabBarItem.title = NSLocalizedString("To Do", comment: "Title of the Todo screen")
    todo.tabBarItem.image = .icon(.todo)
    todo.tabBarItem.selectedImage = .icon(.todoSolid)
    todo.tabBarItem.accessibilityIdentifier = "TabBar.todoTab"
    return todo
}
