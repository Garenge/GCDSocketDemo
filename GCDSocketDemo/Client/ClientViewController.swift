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
    @IBOutlet weak var showFileListBtn: UIButton!
    
    let client = PPClientSocketManager()
    
    var disConnectManually: Bool = false
    
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
            self?.doLog("======== 客户端连接成功服务端: \(socket)")
            self?.connectBtn.setTitle("客户端已连接, 点击断开", for: .normal)
            self?.showFileListBtn.isHidden = false
        }
        client.doClientDidDisconnectClosure = { [weak self] (manager, socket, error) in
            self?.doLog("======== 客户端断开连接: \(socket)" + (error != nil ? ", error: \(error!)" : ""))
            self?.connectBtn.setTitle("客户端未连接, 点击连接", for: .normal)
            self?.showFileListBtn.isHidden = true
            if self?.disConnectManually != true {
                self?.doLog("检测到连接断开, 5s后自动重连服务器")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self?.tryToConnectAutomatically()
                }
            } else {
                self?.disConnectManually = true
                self?.doLog("手动断开连接, 不需要自动重连服务器")
            }
        }
        client.doClientDidRemovedByServerClosure = { [weak self] (manager, socket) in
            self?.disConnectManually = true
            self?.doLog("被server主动移除, 断开连接, 不需要自动重连服务器")
        }
    }
    
    func doLog(_ message: String?) {
        guard let message = message else {
            return
        }
        print("======== \(message)")
        let preString = self.receivedMessageTextView.text ?? ""
        self.receivedMessageTextView.text = preString + "\n" + message
        let range = NSMakeRange(self.receivedMessageTextView.text.count - 1, 1)
        self.receivedMessageTextView.scrollRangeToVisible(range)
    }

    @IBAction func doConnectServerBtnClickedAction(_ sender: Any) {
        self.view.endEditing(true)
        if self.client.socket.isConnected {
            doLog("======== 开始断开服务器: \(serverHost):\(serverPort)")
            self.client.socket.disconnect()
            self.disConnectManually = true
        } else {
            self.doConnectServer()
        }
    }
    
    func doConnectServer() {
        doLog("======== 开始连接服务器: \(serverHost):\(serverPort)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.client.connect(host: self.serverHost, port: UInt16(self.serverPort) ?? 12123)
            UserDefaults.standard.set(self.serverHost, forKey: GSHostKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    @IBAction func doTestAction(_ sender: Any) {
        let deviceName = UIDevice.current.name
        print("设备名称: \(deviceName)")
        self.client.sendDeviceName(deviceName) { [weak self] (responseMsg, error) in
            self?.doLog("发送设备名称, 收到回复: \(responseMsg ?? "--"), error: \(error?.description ?? "--")")
        }
        self.client.sendDirectionMessage(with: FileManager.default.getDocumentDirectory()) { [weak self] (message, error) in
            self?.doLog("发送消息, 收到回复: \(message ?? "--"), error: \(error?.description ?? "--")")
        }
    }
    // MARK: - timer
    
    @objc public func tryToConnectAutomatically() {
        doLog("开始自动重连服务器...")
        if self.client.socket.isConnected {
            doLog("检测到Socket已连接, 无需重连")
            return
        }
        self.doConnectServer()
    }
    
    @IBAction func doShowFiles(_ sender: Any) {
        let filesVC = FilesListViewController()
        filesVC.client = client
        self.navigationController?.pushViewController(filesVC, animated: true)
    }
}
