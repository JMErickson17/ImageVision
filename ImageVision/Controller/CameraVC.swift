//
//  ViewController.swift
//  ImageVision
//
//  Created by Justin Erickson on 10/21/17.
//  Copyright © 2017 Justin Erickson. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML
import Vision

enum FlashState {
    case off
    case on
}

enum SpeechState {
    case off
    case on
}

class CameraVC: UIViewController {
    
    // MARK: Properties
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var identificationLabel: UILabel!
    @IBOutlet weak var confidenceLabel: UILabel!
    @IBOutlet weak var captureImageView: RoundedShadowImageView!
    @IBOutlet weak var flashButton: RoundedShadowButton!
    @IBOutlet weak var speechButton: RoundedShadowButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private var captureSession: AVCaptureSession!
    private var cameraOutput: AVCapturePhotoOutput!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    private var photoData: Data?
    private var flashState: FlashState = .off
    private var speechState: SpeechState = .off
    private var speechSynthesizer = AVSpeechSynthesizer()
    
    // MARK: View Life Cycle
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        previewLayer.frame = cameraView.bounds
        speechSynthesizer.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupView()
    }
    
    // MARK: Setup
    
    private func setupView() {
        let takePhotoTap = UITapGestureRecognizer(target: self, action: #selector(didTapCameraView))
        takePhotoTap.numberOfTapsRequired = 1
        
        // Setup the captureSession
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        
        if let rearCamera = AVCaptureDevice.default(for: AVMediaType.video) {
            do {
                
                let input = try AVCaptureDeviceInput(device: rearCamera)
                if captureSession.canAddInput(input) {
                    captureSession.addInput(input)
                }
                
                cameraOutput = AVCapturePhotoOutput()
                
                if captureSession.canAddOutput(cameraOutput) {
                    captureSession.addOutput(cameraOutput)
                }
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
                previewLayer.connection?.videoOrientation = .portrait
                
                cameraView.layer.addSublayer(previewLayer)
                cameraView.addGestureRecognizer(takePhotoTap)
                captureSession.startRunning()
                
            } catch {
                debugPrint(error)
            }
        }
        activityDidFinish()
    }
    
    @objc func didTapCameraView() {
        activityInProgress()
        
        let settings = AVCapturePhotoSettings()
        settings.previewPhotoFormat = settings.embeddedThumbnailPhotoFormat
        settings.flashMode = flashState == .off ? .off : .on
        
        cameraOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func processImage(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNClassificationObservation] else { return }
        
        for classification in results {
            if classification.confidence < 0.5 {
                self.identificationLabel.text = Constants.unknownObjectMessage
                self.confidenceLabel.text = ""
                
                synthesizeSpeech(fromString: Constants.unknownObjectMessage)
                activityDidFinish()
                break
            } else {
                let identification = classification.identifier
                let confidence = Int(classification.confidence * 100)
                let speechSentence = "This looks like a \(identification) and I am \(confidence) percent sure"
                self.identificationLabel.text = identification
                self.confidenceLabel.text = "Confidence: \(confidence)%"
                
                synthesizeSpeech(fromString: speechSentence)
                activityDidFinish()
                break
            }
        }
    }
    
    func synthesizeSpeech(fromString string: String) {
        guard speechState == .on else { return }
        let speechUtterance = AVSpeechUtterance(string: string)
        speechSynthesizer.speak(speechUtterance)
    }
    
    private func activityInProgress() {
        self.cameraView.isUserInteractionEnabled = false
        self.activityIndicator.isHidden = false
        self.activityIndicator.startAnimating()
    }
    
    private func activityDidFinish() {
        self.cameraView.isUserInteractionEnabled = true
        self.activityIndicator.isHidden = true
        self.activityIndicator.stopAnimating()
    }
    
    // MARK: Actions
    
    @IBAction func toggleFlashButtonTapped(_ sender: Any) {
        switch flashState {
        case .off:
            self.flashButton.setTitle("Flash: On", for: .normal)
            self.flashState = .on
        case .on:
            self.flashButton.setTitle("Flash: Off", for: .normal)
            self.flashState = .off
        }
    }
    
    @IBAction func toggleSpeechButtonTapped(_ sender: Any) {
        switch speechState {
        case .off:
            self.speechButton.setTitle("Speech: On", for: .normal)
            self.speechState = .on
        case .on:
            self.speechButton.setTitle("Speech: Off", for: .normal)
            self.speechState = .off
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraVC: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else { return debugPrint(error!) }
        
        photoData = photo.fileDataRepresentation()
        if let photoData = self.photoData {
            let image = UIImage(data: photoData)
            
            // Process image
            do {
                let model = try VNCoreMLModel(for: SqueezeNet().model)
                let request = VNCoreMLRequest(model: model, completionHandler: processImage)
                let handler = VNImageRequestHandler(data: photoData)
                try handler.perform([request])
            } catch {
                debugPrint(error.localizedDescription)
            }

            self.captureImageView.image = image
        }
    }
}

extension CameraVC: AVSpeechSynthesizerDelegate {
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        activityDidFinish()
    }
}
