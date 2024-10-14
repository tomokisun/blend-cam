import SwiftUI

@main
struct BlendCamApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}

struct ContentView: UIViewControllerRepresentable {
  typealias UIViewControllerType = FaceCropViewController
  
  func makeUIViewController(context: Context) -> UIViewControllerType {
    UIViewControllerType(nibName: nil, bundle: nil)
  }
  
  func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
}
