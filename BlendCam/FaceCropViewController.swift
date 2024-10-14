import UIKit
import AVFoundation
import Vision

class FaceCropViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
  
  let multiCamSession = AVCaptureMultiCamSession()
  
  private var frontCameraPreviewLayer: AVCaptureVideoPreviewLayer!
  private var backCameraPreviewLayer: AVCaptureVideoPreviewLayer!
  
  var captureSession: AVCaptureSession!
  var previewLayer: AVCaptureVideoPreviewLayer!
  
  let cameraView: UIImageView = {
    let imageView = UIImageView()
    imageView.contentMode = .scaleAspectFill
    imageView.translatesAutoresizingMaskIntoConstraints = false
    return imageView
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // インカメラの設定
    if let frontCameraInput = createCameraInput(position: .front) {
      multiCamSession.addInput(frontCameraInput)
    }
    
    let frontCameraOutput = AVCaptureVideoDataOutput()
    frontCameraOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
    multiCamSession.addOutput(frontCameraOutput)
    
    // アウトカメラの設定
    if let backCameraInput = createCameraInput(position: .back) {
      multiCamSession.addInput(backCameraInput)
    }
    
    setupPreviewLayers()
    setupCameraView()
    
    DispatchQueue.global(qos: .userInitiated).async {
      self.multiCamSession.startRunning()
    }
  }
  
  private func createCameraInput(position: AVCaptureDevice.Position) -> AVCaptureDeviceInput? {
    guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
      print("\(position == .back ? "アウトカメラ" : "インカメラ")が見つかりません")
      return nil
    }
    
    do {
      return try AVCaptureDeviceInput(device: camera)
    } catch {
      print("カメラ入力の作成に失敗しました: \(error.localizedDescription)")
      return nil
    }
  }
  
  // カメラプレビューのレイヤーをセットアップ
  private func setupPreviewLayers() {
    // インカメラのプレビュー
    frontCameraPreviewLayer = AVCaptureVideoPreviewLayer(session: multiCamSession)
    frontCameraPreviewLayer.videoGravity = .resizeAspectFill
    frontCameraPreviewLayer.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
    view.layer.addSublayer(frontCameraPreviewLayer)

    // アウトカメラのプレビュー
    backCameraPreviewLayer = AVCaptureVideoPreviewLayer(session: multiCamSession)
    backCameraPreviewLayer.videoGravity = .resizeAspectFill
    backCameraPreviewLayer.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
    view.layer.addSublayer(backCameraPreviewLayer)
  }
  
  // カメラの映像をUIImageViewに表示する
  func setupCameraView() {
    view.addSubview(cameraView)
    NSLayoutConstraint.activate([
      cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      cameraView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      cameraView.heightAnchor.constraint(equalTo: cameraView.widthAnchor),
    ])
  }
  
  // フレームごとの映像を処理する
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    detectImageSubject(in: pixelBuffer)
  }
  
  func detectImageSubject(in pixelBuffer: CVPixelBuffer) {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    
    let imageRequestHandler = ImageRequestHandler(pixelBuffer)
    
    //　GenerateForegroundInstanceMaskRequestの生成
    let request = GenerateForegroundInstanceMaskRequest()
    
    // セッション開始
    Task {
      if let result = try? await request.perform(on: ciImage) {
        if let buffer =  try? result.generateMaskedImage(for: result.allInstances, imageFrom: imageRequestHandler, croppedToInstancesExtent: false) {
          if let resultImage = UIImage(pixelBuffer: buffer)?.rotate(by: 90) {
            cameraView.image = resultImage
          }
        }
      }
    }
  }
}

extension UIImage {
  public convenience init?(pixelBuffer: CVPixelBuffer) {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext()
    
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
    self.init(cgImage: cgImage)
  }
  
  func rotate(by degrees: CGFloat) -> UIImage? {
    let radians = degrees * .pi / 180
    var newSize = CGRect(origin: .zero, size: size)
      .applying(CGAffineTransform(rotationAngle: radians))
      .integral.size
    
    UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
    guard let context = UIGraphicsGetCurrentContext() else { return nil }
    
    context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
    context.scaleBy(x: -1.0, y: 1.0)
    context.rotate(by: radians)
    draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
    
    let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return rotatedImage
  }
}
