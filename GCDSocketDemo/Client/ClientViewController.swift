//
//  ClientViewController.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2025/3/8.
//

import UIKit
import PPSocket

class ClientViewController: UIViewController {

    @IBOutlet weak var serverPortTF: UITextField!
    @IBOutlet weak var serverAddressTF: UITextField!
    
    let client = PPClientSocketManager()
    
    var serverPort: String {
        if let port = self.serverPortTF.text, port.count > 0 {
            return port
        }
        return "12123"
    }
    var serverHost: String {
        if let host = self.serverAddressTF.text, host.count > 0 {
            return host
        }
        return "127.0.0.1"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.serverPortTF.text = UserDefaults.standard.string(forKey: GSPortKey)
        self.serverAddressTF.text = UserDefaults.standard.string(forKey: GSHostKey)
    }

    @IBAction func doConnectServerBtnClickedAction(_ sender: Any) {
        self.view.endEditing(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.client.connect(host: self.serverHost, port: UInt16(self.serverPort) ?? 12123)
            UserDefaults.standard.set(self.serverHost, forKey: GSHostKey)
            UserDefaults.standard.synchronize()
        }
    }
}
