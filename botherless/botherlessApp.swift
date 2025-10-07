//
//  botherlessApp.swift
//  botherless
//
//  Created by Yeonjun Lee on 10/7/25.
//

import SwiftUI

@main
struct botherlessApp: App {
    @State var currentPage: Page = Page.canvas
    
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            GetPage(currentPage)
        }
    }
}
