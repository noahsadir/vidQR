//
//  ViewController.swift
//  vidqr
//
//  Created by Noah Sadir on 11/19/20.
//

import UIKit
import AVFoundation

class ViewController: UIViewController , AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var metadata = ""
    var packetID = 0
    var totalPackets = 0
    var firstPacket = 0
    var framerate = 0
    var fileExtension = ""
    var fileSize = 0
    var startTime = 0.0
    var finishedFirstRound = false
    var timeSinceLastCheck = 0.0
    
    var packets = [Int]()
    var packetData = [String]()
    
    
    @IBOutlet weak var percentageLabel: UILabel!
    
    @IBOutlet weak var cameraView: UIView!
    
    @IBOutlet weak var progressLabel: UILabel!
    
    @IBOutlet weak var statusLabel: UILabel!
    
    
    @IBOutlet weak var progressRingView: UIView!
    
    var progressCircle = CAShapeLayer()
    var qrCodeFrameView = UIImageView()
    
    
    var videoCaptureDevice: AVCaptureDevice?
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Prepare UI elements
        progressLabel.text = ""
        progressCircle = createCircularPath(view: progressRingView)
        progressRingView.layer.cornerRadius = progressRingView.bounds.height / 2
        progressRingView.isHidden = true
        
        qrCodeFrameView.image = UIImage(imageLiteralResourceName: "qr_frame")
        cameraView.addSubview(qrCodeFrameView)
        
        
        captureSession = AVCaptureSession()
        
        guard let videoCap = AVCaptureDevice.default(for: .video) else { return }
        
        videoCaptureDevice = videoCap
        let videoInput: AVCaptureDeviceInput
        
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice!)
        } catch {
            return
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.code128]
        } else {
            failed()
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        cameraView.layer.addSublayer(previewLayer)
        cameraView.bringSubviewToFront(qrCodeFrameView)
        captureSession.startRunning()
        DispatchQueue.main.async {
            self.previewLayer.frame = self.cameraView.bounds
            self.previewLayer.cornerRadius = 16
        }
    }
    
    func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if (captureSession?.isRunning == false) {
            captureSession.startRunning()
           
            
        }
    }
    
    override func viewDidLayoutSubviews() {
        if UIApplication.shared.statusBarOrientation == .landscapeLeft{
            previewLayer.connection?.videoOrientation = .landscapeLeft
        }else if UIApplication.shared.statusBarOrientation == .landscapeRight{
            previewLayer.connection?.videoOrientation = .landscapeRight
        }else if UIApplication.shared.statusBarOrientation == .portrait{
            previewLayer.connection?.videoOrientation = .portrait
        }else if UIApplication.shared.statusBarOrientation == .portraitUpsideDown{
            previewLayer.connection?.videoOrientation = .portraitUpsideDown
        }
        previewLayer.frame = self.cameraView.bounds
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }
    
    func createCircularPath(view: UIView) -> CAShapeLayer {
        let circle = view
        
        var progCircle = CAShapeLayer()
        let circlePath = UIBezierPath(ovalIn: CGRect(x: circle.bounds.minX - 2.5, y: circle.bounds.minY - 2.5, width: circle.bounds.width + 5, height: circle.bounds.height + 5))
        
        progCircle = CAShapeLayer ()
        progCircle.path = circlePath.cgPath
        progCircle.strokeColor = UIColor.systemBlue.cgColor
        progCircle.strokeEnd = 0
        progCircle.fillColor = UIColor.clear.cgColor
        progCircle.lineWidth = 5.0
        progCircle.lineCap = .round
        circle.layer.addSublayer(progCircle)
        return progCircle
    }
    
    func changeProgress(progressCircle: CAShapeLayer, from: Float, to: Float){
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = 0.2
        animation.fillMode = CAMediaTimingFillMode.forwards
        animation.isRemovedOnCompletion = false
        
        progressCircle.add(animation, forKey: "ani")
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        //captureSession.stopRunning()
        //print(output.metadataObjectTypes)
        if metadataObjects.count == 0{
            qrCodeFrameView.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        }
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            if (output.metadataObjectTypes[0] == .qr){
                let barCodeObject = previewLayer.transformedMetadataObject(for: metadataObject as! AVMetadataMachineReadableCodeObject) as! AVMetadataMachineReadableCodeObject
                
                qrCodeFrameView.frame = barCodeObject.bounds
                print(qrCodeFrameView.bounds)
            }
            
            
            if (output.metadataObjectTypes[0] == .qr){
                
               
                
                if metadataObjects.count == 1 && stringValue.count > 8{
                    var base64Binary = String(stringValue.prefix(8))
                    guard let data = Data(base64Encoded: base64Binary, options: .ignoreUnknownCharacters) else { return print("Error") }
                    
                    
                    
                    if (data.count == 4){
                        
                        var currentPacketID = -1
                        var currentQRData = String(stringValue.suffix(from: stringValue.index(stringValue.startIndex, offsetBy: 8)))
                        currentPacketID = Int(bigEndianBytesToInt32(array: [data[0],data[1],data[2],data[3]]))
                        
                        
                        
                        var adjustedPacketIndex = (totalPackets - firstPacket) + currentPacketID
                        if packets.count == 0{
                            firstPacket = currentPacketID
                            startTime = Date().timeIntervalSince1970
                            timeSinceLastCheck = startTime
                        }else if currentPacketID > firstPacket && timeSinceLastCheck + 1 < Date().timeIntervalSince1970{
                            
                            timeSinceLastCheck = Date().timeIntervalSince1970
                            let duration = timeSinceLastCheck - startTime
                            let packetSize = fileSize / totalPackets
                            let kilobytesPerSecond = String(format: "%.1f",(Double(packetSize * packets.count) / duration) / 1000)
                            statusLabel.text = kilobytesPerSecond + " KB/s"
                            //print(kilobytesPerSecond)
                            
                            adjustedPacketIndex = currentPacketID - firstPacket
                        }
                        
                        var secondsLeft = (totalPackets - adjustedPacketIndex) / framerate
                        
                        
                        
                        if !packets.contains(currentPacketID) && currentPacketID != -1{
                            
                            packets.append(currentPacketID)
                            packetData[currentPacketID - 1] = currentQRData
                            progressLabel.text = String(packets.count) + " of " + String(totalPackets)
                            
                            
                            //progressBar.progress = Float(packets.count) / Float(totalPackets)
                            
                            let percentage = Int((Float(packets.count) / Float(totalPackets)) * 100)
                            
                            let strokeTextAttributes = [
                                NSAttributedString.Key.strokeColor : UIColor.black,
                                NSAttributedString.Key.foregroundColor : UIColor.white,
                                NSAttributedString.Key.strokeWidth : -4.0,
                                NSAttributedString.Key.font : UIFont.systemFont(ofSize: 16, weight: .heavy)
                            ] as [NSAttributedString.Key : Any]

                            percentageLabel.attributedText = NSMutableAttributedString(string: String(percentage) + "%", attributes: strokeTextAttributes)
                            
                            changeProgress(progressCircle: progressCircle, from: Float(packets.count - 1) / Float(totalPackets), to: Float(packets.count) / Float(totalPackets))
                            if packets.count == totalPackets{
                                print("Done!")
                                
                                statusLabel.text = "Done!"
                                captureSession.stopRunning()
                                
                                try! videoCaptureDevice!.lockForConfiguration()
                                videoCaptureDevice!.focusMode = .continuousAutoFocus
                                 videoCaptureDevice!.unlockForConfiguration()
                                
                                //Prepare scan for next session
                                output.metadataObjectTypes = [.code128]
                                
                                processData()
                            }
                        }
                        let missedPackets = adjustedPacketIndex - packets.count
                        if missedPackets < 0{
                            finishedFirstRound = true
                            
                        }else if missedPackets > 0 && finishedFirstRound == false{
                            secondsLeft += (totalPackets / framerate)
                            //missedPacketsLabel.text = "Missed " + String(missedPackets) + " packets"
                        }
                        
                        //timeLeftLabel.text = String(secondsLeft) + " seconds"
                        //print(missedPackets)
                        
                    }
                    
                    
                    
                }
            }else if (output.metadataObjectTypes.contains(.code128)){
                print("Found vidqr")
                /**/try! videoCaptureDevice!.lockForConfiguration()
                 videoCaptureDevice!.focusMode = .autoFocus
                 videoCaptureDevice!.unlockForConfiguration()/**/
                progressRingView.isHidden = false
                statusLabel.text = "Hold steady"
                var vidqrMetadata = stringValue.components(separatedBy: ":")
                if vidqrMetadata.count >= 4{
                    
                    framerate = Int(vidqrMetadata[0]) ?? 0
                    totalPackets = Int(vidqrMetadata[1]) ?? 0
                    fileExtension = vidqrMetadata[2]
                    fileSize = Int(vidqrMetadata[3]) ?? 0
                    
                    for _ in 0...totalPackets{
                        packetData.append("")
                    }
                    
                }
                
                output.metadataObjectTypes = [.qr]
                print(stringValue)
            }
            
            
            // found(code: stringValue)
        }
        
        dismiss(animated: true)
    }
    
    func processData(){
        var base64Binary = ""
        for packet in packetData{
            base64Binary += packet
        }
        print(base64Binary)
        guard let data = Data(base64Encoded: base64Binary, options: .ignoreUnknownCharacters) else { return
            
            print("Error")
        }
        let url = getDocumentsDirectory().appendingPathComponent("tmp." + fileExtension)
        
        DispatchQueue.main.async {
            self.promptToSaveFile(data: data)
        }
        if (fileExtension == "png" || fileExtension == "jpg" || fileExtension == "gif" || fileExtension == "tif" || fileExtension == "bmp"){
            let image = UIImage(contentsOfFile: url.path)
            //imageView.image = image
        }
        
    }
    
    func promptToSaveFile(data: Data) {
        var fileType = "file"
        let ac = UIAlertController(title: "Scan successful", message: "Enter name to save " + fileExtension + " file", preferredStyle: .alert)
        
        ac.addTextField()
        
        let submitAction = UIAlertAction(title: "Save", style: .default) { [unowned ac] _ in
            
            self.saveFile(data: data, name: (ac.textFields![0].text ?? "tmp"))
            
            self.resetForNextScan()
        }
        
        ac.addAction(UIAlertAction(title: "Delete", style: .cancel) { _ in
            self.resetForNextScan()
        })
        
        ac.addAction(submitAction)
        present(ac, animated: true)
    }
    
    func resetForNextScan(){
        packets = [Int]()
        packetData = [String]()
        metadata = ""
        packetID = 0
        totalPackets = 0
        firstPacket = 0
        framerate = 0
        fileExtension = ""
        fileSize = 0
        startTime = 0.0
        finishedFirstRound = false
        timeSinceLastCheck = 0.0
        progressRingView.isHidden = true
        statusLabel.text = "Searching for code"
        percentageLabel.text = "0%"
        progressCircle.strokeEnd = 0
        progressLabel.text = ""
        qrCodeFrameView.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        captureSession.startRunning()
    }
    
    func getDocumentsDirectory() -> URL {
        // find all possible documents directories for this user
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        
        // just send back the first one, which ought to be the only one
        return paths[0]
    }
    
    func saveFile(data: Data, name: String){
        let str = data
        let url = getDocumentsDirectory().appendingPathComponent(name + "." + fileExtension)
        
        do {
            try data.write(to: url)
            let input = try Data(contentsOf: url)
            print(input)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func share(url: URL){
        let activitycontroller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if activitycontroller.responds(to: #selector(getter: activitycontroller.completionWithItemsHandler))
        {
            activitycontroller.completionWithItemsHandler = {(type, isCompleted, items, error) in
                if isCompleted
                {
                    print("completed")
                }
            }
        }
        //activitycontroller.popoverPresentationController?.sourceView = self.imageView
        self.present(activitycontroller, animated: true, completion: nil)
    }
    
    func bigEndianBytesToInt32(array: [UInt8]) -> UInt32{
        if array.count == 4{
            let bigEndianValue = array.withUnsafeBufferPointer {
                ($0.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) { $0 })
            }.pointee
            return UInt32(bigEndian: bigEndianValue)
        }
        return 0
    }
    
}


