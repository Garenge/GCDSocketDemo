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
    @IBOutlet weak var connectBtn: UIButton!
    @IBOutlet weak var receivedMessageTextView: UITextView!
    
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        doLog("======== 当前客户端状态: \(client.socket.isConnected ? "已连接" : "未连接")")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.serverPortTF.text = UserDefaults.standard.string(forKey: GSPortKey)
        self.serverAddressTF.text = UserDefaults.standard.string(forKey: GSHostKey)
        
        client.doClientDidConnectedClosure = { [weak self] (manager, socket) in
            self?.doLog("======== 客户端连接成功: \(socket)")
            self?.connectBtn.setTitle("客户端已连接, 点击断开", for: .normal)
        }
        client.doClientDidDisconnectClosure = { [weak self] (manager, socket, error) in
            self?.doLog("======== 客户端断开连接: \(socket)" + (error != nil ? ", error: \(error!)" : ""))
            self?.connectBtn.setTitle("客户端未连接, 点击连接", for: .normal)
        }
    }
    
    func doLog(_ message: String?) {
        guard let message = message else {
            return
        }
        print("======== \(message)")
        let preString = self.receivedMessageTextView.text ?? ""
        self.receivedMessageTextView.text = preString + "\n" + message
    }

    @IBAction func doConnectServerBtnClickedAction(_ sender: Any) {
        self.view.endEditing(true)
        if self.client.socket.isConnected {
            doLog("======== 开始断开服务器: \(serverHost):\(serverPort)")
            self.client.socket.disconnect()
        } else {
            doLog("======== 开始连接服务器: \(serverHost):\(serverPort)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.client.connect(host: self.serverHost, port: UInt16(self.serverPort) ?? 12123)
                UserDefaults.standard.set(self.serverHost, forKey: GSHostKey)
                UserDefaults.standard.synchronize()
            }
        }
    }
}
