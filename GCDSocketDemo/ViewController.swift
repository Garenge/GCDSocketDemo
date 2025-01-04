//
//  ViewController.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2023/5/17.
//

import UIKit
import SnapKit
import PPCatalystTool

class ViewController: UIViewController {
    
    let GSHostKey = "GSHostKey"
    let GSPortKey = "GSPortKey"
    
    @IBOutlet weak var serverPortTF: UITextField!
    @IBOutlet weak var serverHostTF: UITextField!
    @IBOutlet weak var selectFileView: UIView!
    @IBOutlet weak var filePathTF: UITextField!
    
    var serverPort: String {
        if let port = self.serverPortTF.text, port.count > 0 {
            return port
        }
        return "12123"
    }
    var serverHost: String {
        if let host = self.serverHostTF.text, host.count > 0 {
            return host
        }
        return "127.0.0.1"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.serverPortTF.text = UserDefaults.standard.string(forKey: GSPortKey)
        self.serverHostTF.text = UserDefaults.standard.string(forKey: GSHostKey)
        
#if targetEnvironment(macCatalyst)
        self.selectFileView.isHidden = false
#endif
    }

    let server = PPServerSocketManager()
    let client = PPClientSocketManager()
    
    @IBAction func startServer(_ sender: Any) {
        self.view.endEditing(true)
        server.accept(port: UInt16(serverPort) ?? 12123)
        UserDefaults.standard.set(serverPort, forKey: GSPortKey)
        UserDefaults.standard.synchronize()
    }
    
    @IBAction func clientConnectServer(_ sender: Any) {
        self.view.endEditing(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.client.connect(host: self.serverHost, port: UInt16(self.serverPort) ?? 12123)
            UserDefaults.standard.set(self.serverHost, forKey: self.GSHostKey)
            UserDefaults.standard.synchronize()
        }
    }

    @IBAction func send1Action(_ sender: Any) {
        server.sendTestMessage()
    }

    @IBAction func send2Action(_ sender: Any) {
        client.sendTestMessage()
    }

    @IBAction func doSendFileAction(_ sender: Any) {
        guard let filePath = self.filePathTF.text, filePath.count > 0 else {
            return
        }
        server.sendFileInfo(filePath: filePath)
    }
    @IBAction func doShowFiles(_ sender: Any) {
        let filesVC = FilesListViewController()
        filesVC.client = client
        self.navigationController?.pushViewController(filesVC, animated: true)
    }
}

extension ViewController: UITextFieldDelegate {
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        
        let result = PPCatalystHandle.shared().selectSingleFile(withFolderPath: "~/Desktop")
        textField.text = result?.path

        return false
    }
}
