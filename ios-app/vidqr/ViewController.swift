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
    var fileExtension = "jpg"
    var fileSize = 0
    var startTime = 0.0
    var finishedFirstRound = false
    var timeSinceLastCheck = 0.0
    
    var packets = [Int]()
    var packetData = [String]()

    @IBOutlet weak var cameraView: UIView!
    
    @IBOutlet weak var progressLabel: UILabel!
    
    @IBOutlet weak var progressBar: UIProgressView!
    
    @IBOutlet weak var missedPacketsLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    @IBOutlet weak var timeLeftLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    @IBAction func shareButtonClicked(_ sender: Any) {
        let url = getDocumentsDirectory().appendingPathComponent("tmp." + fileExtension)
        share(url: url)
    }
    func promptToSaveFile() {
        let ac = UIAlertController(title: "Save file", message: "Enter name to save file", preferredStyle: .alert)
        
        ac.addTextField()

        let submitAction = UIAlertAction(title: "Save", style: .default) { [unowned ac] _ in
            let tmpUrl = self.getDocumentsDirectory().appendingPathComponent("tmp." + self.fileExtension)
            
            
            let url = self.getDocumentsDirectory().appendingPathComponent((ac.textFields![0].text ?? "tmp") + "." + self.fileExtension)
            do{
                try FileManager.default.moveItem(at: tmpUrl, to: url)
            }catch{
                
            }
        }
        
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            
        })

        ac.addAction(submitAction)
        present(ac, animated: true)
    }
    var videoCaptureDevice: AVCaptureDevice?
    override func viewDidLoad() {
        super.viewDidLoad()
        

        view.backgroundColor = UIColor.black
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
        previewLayer.frame = cameraView.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        cameraView.layer.addSublayer(previewLayer)

        captureSession.startRunning()
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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        //captureSession.stopRunning()
        //print(output.metadataObjectTypes)

        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            
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
                            
                           
                            progressBar.progress = Float(packets.count) / Float(totalPackets)
                            if packets.count == totalPackets{
                                print("Done!")
                                statusLabel.text = "Done!"
                                captureSession.stopRunning()
                                processData()
                            }
                        }
                        let missedPackets = adjustedPacketIndex - packets.count
                        if missedPackets < 0{
                            finishedFirstRound = true
                            
                        }else if missedPackets > 0 && finishedFirstRound == false{
                            secondsLeft += (totalPackets / framerate)
                            missedPacketsLabel.text = "Missed " + String(missedPackets) + " packets"
                        }
                        
                        timeLeftLabel.text = String(secondsLeft) + " seconds"
                        //print(missedPackets)
                        
                    }
                    
                    
                    
                }
            }else if (output.metadataObjectTypes.contains(.code128)){
                print("Found vidqr")
                /*try! videoCaptureDevice!.lockForConfiguration()
                videoCaptureDevice!.focusMode = .autoFocus
                videoCaptureDevice!.unlockForConfiguration()*/
                statusLabel.text = "Scanning: Hold steady"
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
        
        saveFile(data: data)
        DispatchQueue.main.async {
            self.promptToSaveFile()
        }
        if (fileExtension == "png" || fileExtension == "jpg" || fileExtension == "gif" || fileExtension == "tif" || fileExtension == "bmp"){
            let image = UIImage(contentsOfFile: url.path)
            imageView.image = image
        }
        
    }
    
    func getDocumentsDirectory() -> URL {
        // find all possible documents directories for this user
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)

        // just send back the first one, which ought to be the only one
        return paths[0]
    }
    
    func saveFile(data: Data){
        let str = data
        let url = getDocumentsDirectory().appendingPathComponent("tmp." + fileExtension)

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
        activitycontroller.popoverPresentationController?.sourceView = self.imageView
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
    
    func found(code: String) {
        print(code)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    func detectQRCode(_ image: UIImage?) -> [CIFeature]? {
        if let image = image, let ciImage = CIImage.init(image: image){
            var options: [String: Any]
            let context = CIContext()
            options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
            let qrDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: options)
            if ciImage.properties.keys.contains((kCGImagePropertyOrientation as String)){
                options = [CIDetectorImageOrientation: ciImage.properties[(kCGImagePropertyOrientation as String)] ?? 1]
            } else {
                options = [CIDetectorImageOrientation: 1]
            }
            let features = qrDetector?.features(in: ciImage, options: options)
            return features

        }
        return nil
    }

}


