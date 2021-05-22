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
    
    var vidqrVersion = 0
    var fileName = ""
    var fileExtension = ""
    var fileSize = 0
    
    var fileDataPackets = [String]()
    var extendedMetadataPackets = [String]()
    
    var fileDataPacketCount = 0
    var extendedMetadataPacketCount = 0
    
    
    @IBOutlet weak var packetLabel: UILabel!
    
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
        
        //Setup video stream
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
        
        //Configure camera to scan for Code128 codes
        let metadataOutput = AVCaptureMetadataOutput()
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.code128]
        } else {
            failed()
            return
        }
        
        //Setup Camera view UI and start
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
    
    //Notify user if device can't scan codes
    func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }
    
    //Start running camera if view is visible
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if (captureSession?.isRunning == false) {
            captureSession.startRunning()
        }
    }
    
    //Stop running camera if view is not visible
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }
    
    //Adjust video for current orientation
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
    
    //Create progress ring
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
    
    //Update progress ring
    func changeProgress(progressCircle: CAShapeLayer, from: Float, to: Float){
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = 0.2
        animation.fillMode = CAMediaTimingFillMode.forwards
        animation.isRemovedOnCompletion = false
        
        progressCircle.add(animation, forKey: "ani")
    }
    
    //Get packet ID from header
    func getPacketID(headerBinary: Data, version: Int) -> Int{
        if (version == 2 && headerBinary.count == 4) {
            return Int(bigEndianBytesToInt32(array: [headerBinary[0], headerBinary[1], headerBinary[2], headerBinary[3]]))
        } else if (version == 3 && headerBinary.count == 4) {
            return Int(bigEndianBytesToInt32(array: [0, headerBinary[0], headerBinary[1], headerBinary[2]]))
        }
        return -1
    }
    
    //Get packet type from header (only for version 3, return 0 for v2)
    func getPacketType(headerBinary: Data, version: Int) -> Int{
        if (version == 2) {
            return 0
        } else if (version == 3 && headerBinary.count == 4) {
            return Int(headerBinary[3])
        }
        
        return -1
    }
    
    //Update progress ring and percentage label
    func updateProgress() {
        let currentCountFloat = Float(fileDataPacketCount)
        let totalCountFloat = Float(fileDataPackets.count)
        let percentage = Int((currentCountFloat / totalCountFloat) * 100)
        
        let strokeTextAttributes = [
            NSAttributedString.Key.strokeColor : UIColor.black,
            NSAttributedString.Key.foregroundColor : UIColor.white,
            NSAttributedString.Key.strokeWidth : -4.0,
            NSAttributedString.Key.font : UIFont.systemFont(ofSize: 16, weight: .heavy)
        ] as [NSAttributedString.Key : Any]
        percentageLabel.attributedText = NSMutableAttributedString(string: String(percentage) + "%", attributes: strokeTextAttributes)
        changeProgress(progressCircle: progressCircle, from: (currentCountFloat - 1.0) / totalCountFloat, to: currentCountFloat / totalCountFloat)
    }
    
    //Determine whether packet should be saved and save string value to memory, along
    //with making the appropriate UI updates
    func savePackets(packetID: Int, packetType: Int, packetDataString: String) {
        if (packetID != -1 && packetType == 0) {
            packetLabel.text = "Packet " + String(fileDataPacketCount) + " of " + String(fileDataPackets.count)
            
            //If packet wasn't added already, add to array until all have been populated
            if (fileDataPacketCount < fileDataPackets.count && (fileDataPackets[packetID - 1] == "" || packetDataString == "")) {
                fileDataPackets[packetID - 1] = packetDataString
                fileDataPacketCount += 1
                updateProgress()
            }
            
        } else if (packetID != -1 && packetType == 1 && vidqrVersion == 3) {
            
            //If packet wasn't added already, add to array until all have been populated
            if (extendedMetadataPacketCount < extendedMetadataPackets.count && (extendedMetadataPackets[packetID - 1] == "" || packetDataString == "")) {
                extendedMetadataPackets[packetID - 1] = packetDataString
                extendedMetadataPacketCount += 1
            }
            
        }
    }
    
    //Save QR code data to appropriate packets until all have been loaded
    func handleQRCode(dataString: String, metadataOutput: AVCaptureMetadataOutput) {
        
        //Convert Base64 String to binary
        guard let headerBinary = Data(base64Encoded: String(dataString.prefix(8)), options: .ignoreUnknownCharacters) else {
            return print("Error")
        }
        
        let packetID = getPacketID(headerBinary: headerBinary, version: vidqrVersion)
        let packetType = getPacketType(headerBinary: headerBinary, version: vidqrVersion)
        let packetDataString = String(dataString.suffix(from: dataString.index(dataString.startIndex, offsetBy: 8)))
        
        if (fileDataPacketCount < fileDataPackets.count || extendedMetadataPacketCount < extendedMetadataPackets.count) {
            savePackets(packetID: packetID, packetType: packetType, packetDataString: packetDataString)
        } else {
            //Done scanning
            metadataOutput.metadataObjectTypes = [.code128]
            captureSession.stopRunning()
            try! videoCaptureDevice!.lockForConfiguration()
            videoCaptureDevice!.focusMode = .continuousAutoFocus
            videoCaptureDevice!.unlockForConfiguration()
            processData()
        }
    }
    
    //Save metadata stored in Code128 barcode, depending on the version
    func handleCode128(dataString: String) {
        progressRingView.isHidden = false
        statusLabel.text = "Hold steady"
        let metadata = dataString.components(separatedBy: ":")
        
        if metadata[0] == "2" && metadata.count == 4 {
            vidqrVersion = Int(metadata[0])!
            fileExtension = metadata[2]
            fileSize = Int(metadata[3]) ?? 0
            
            let totalFilePackets = Int(metadata[1]) ?? 0
            
            for _ in 0...totalFilePackets {
                fileDataPackets.append("")
            }
            
        } else if metadata[0] == "3" && metadata.count == 3 {
            vidqrVersion = Int(metadata[0])!
            
            let totalFilePackets = Int(metadata[1]) ?? 0
            
            for _ in 0...(totalFilePackets - 1) {
                fileDataPackets.append("")
            }
            
            let totalextendedMetadataPackets = Int(metadata[2]) ?? 0
            
            for _ in 0...(totalextendedMetadataPackets - 1) {
                extendedMetadataPackets.append("")
            }
        }
    }
    
    //Handle metadata (codes) picked up by camera
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        
        if metadataObjects.count == 0{
            qrCodeFrameView.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        }
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            if (output.metadataObjectTypes[0] == .qr){
                //Show QR code outline
                let barCodeObject = previewLayer.transformedMetadataObject(for: metadataObject as! AVMetadataMachineReadableCodeObject) as! AVMetadataMachineReadableCodeObject
                qrCodeFrameView.frame = barCodeObject.bounds
                
                //Process QR data
                if metadataObjects.count == 1 && stringValue.count > 8 && (vidqrVersion == 2 || vidqrVersion == 3){
                    handleQRCode(dataString: stringValue, metadataOutput: output)
                }
            }else if (output.metadataObjectTypes.contains(.code128)){
                print("Found vidqr")
                try! videoCaptureDevice!.lockForConfiguration()
                videoCaptureDevice!.focusMode = .autoFocus
                videoCaptureDevice!.unlockForConfiguration()
                handleCode128(dataString: stringValue)
                
                output.metadataObjectTypes = [.qr]
                print(stringValue)
            }
        }
        dismiss(animated: true)
    }
    
    //Reset variables and UI elements to prepare for the next scan
    func resetForNextScan(){
        
        //Variables
        vidqrVersion = 0
        fileName = ""
        fileExtension = ""
        fileSize = 0
        fileDataPackets = [String]()
        extendedMetadataPackets = [String]()
        fileDataPacketCount = 0
        extendedMetadataPacketCount = 0
        
        //UI
        progressRingView.isHidden = true
        statusLabel.text = "Searching for code"
        packetLabel.text = "Packet --"
        percentageLabel.text = "0%"
        progressCircle.strokeEnd = 0
        progressLabel.text = ""
        qrCodeFrameView.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        captureSession.startRunning()
    }
    
    //Combine packets and retrieve data, then prompt user to save
    func processData(){
        let data = convertPacketsToBinary(packets: fileDataPackets)
        if (vidqrVersion == 3) {
            let extendedMetadata: ExtendedMetadata = try! JSONDecoder().decode(ExtendedMetadata.self, from: convertPacketsToBinary(packets: extendedMetadataPackets))
            fileName = extendedMetadata.name
            fileExtension = extendedMetadata.ext
        }
        let url = getDocumentsDirectory().appendingPathComponent(fileName + "." + fileExtension)
        
        DispatchQueue.main.async {
            self.promptToSaveFile(data: data)
        }
        
    }
    
    //Show alert to save file
    func promptToSaveFile(data: Data) {
        var fileType = "file"
        let ac = UIAlertController(title: "Scan successful", message: "Enter name to save " + fileExtension + " file", preferredStyle: .alert)
        
        ac.addTextField()
        ac.textFields![0].text = fileName
        
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
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
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
        
        self.present(activitycontroller, animated: true, completion: nil)
    }
    
    func convertPacketsToBinary(packets: [String]) -> Data{
        var base64String = ""
        for packet in packets {
            base64String += packet
        }
        guard let data = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) else { return
            Data()
        }
        return data
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

struct ExtendedMetadata: Decodable {
    let name: String
    let ext: String
    let size: Int
}


