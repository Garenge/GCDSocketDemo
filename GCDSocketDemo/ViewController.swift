//
//  ViewController.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2023/5/17.
//

import UIKit
import SnapKit

class ViewController: UIViewController {
    
    let GSHostKey = "GSHostKey"
    let GSPortKey = "GSPortKey"
    
    @IBOutlet weak var serverPortTF: UITextField!
    @IBOutlet weak var serverHostTF: UITextField!
    
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
    }

    let server = ServerSocketManager()
    let client = ClientSocketManager()
    
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
        server.sendMessage()
    }

    @IBAction func send2Action(_ sender: Any) {
        client.sendMessage()
    }

}

