import SwiftUI

enum Page {
//    case main
    case canvas
}

func GetPage(_ type: Page) -> some View {
    switch type {
//    case .main:
//        MainPage()
    case .canvas:
        CanvasPage()
    }
}
