//
//  ServerViewController.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2025/3/8.
//

import UIKit
import PPSocket
import PPCatalystTool

class ServerViewController: UIViewController {
    
    @IBOutlet weak var startServerBtn: UIButton!
    @IBOutlet weak var serverPortTF: UITextField!
    @IBOutlet weak var selectRootPathBtn: UIButton!
    @IBOutlet weak var currentClientLabel: UILabel!
    @IBOutlet weak var selectedRootPathLabel: UILabel!
    @IBOutlet weak var receivedMessageTextView: UITextView!
    
    var isServerOn: Bool = false
    
    lazy var server: PPServerSocketManager = {
        let manager = PPServerSocketManager()
        
//        var isDir: ObjCBool = true
//        if rootPath.count > 0 {
//            let exist = FileManager.default.fileExists(atPath: rootPath, isDirectory: &isDir)
//            if exist && isDir.boolValue {
//                manager.rootPath = rootPath
//            }
//        }
        return manager
    }()
    
    /// 由于Mac catalyst有沙盒机制, 每次启动需要重新手动选择文件夹, 否则会无法访问本地文件夹
    var selectedRootPath: String?
    
    var serverPort: String {
        if let port = self.serverPortTF.text, port.count > 0 {
            return port
        }
        return "12123"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        doLog("======== 当前服务端状态: \(isServerOn ? "已开启服务" : "未开启")")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.serverPortTF.text = UserDefaults.standard.string(forKey: GSPortKey)
        
        self.server.doServerAcceptPortClosure = { [weak self] (manager, port, error) in
            self?.doLog("======== 服务端监听端口: \(port)" + (error != nil ? ", error: \(error!)" : ""))
            if error == nil {
                self?.startServerBtn.setTitle("服务端已开启", for: .normal)
                self?.isServerOn = true
                self?.startServerBtn.isEnabled = false
            } else {
                self?.startServerBtn.setTitle("服务端未开启, 点击开启", for: .normal)
                self?.isServerOn = false
                self?.startServerBtn.isEnabled = true
            }
        }
        self.server.doServerAcceptNewSocketClosure = { [weak self] (manager, socket) in
            self?.doLog("======== 服务端接受新连接: \(socket)")
            self?.currentClientLabel.text = "\(socket.connectedHost ?? "未知")"
        }
        self.server.doServerLossClientSocketClosure = { [weak self] (manager, socket, error) in
            self?.doLog("======== 服务端失去客户端连接: \(socket)" + (error != nil ? ", error: \(error!)" : ""))
            self?.currentClientLabel.text = "--"
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

    @IBAction func doStartServerBtnClickedAction(_ sender: Any) {
        
        guard let _ = selectedRootPath else {
            
            // 弹窗, 提示用户必须选择文件夹
            let alert = UIAlertController(title: "提示", message: "请先选择服务器目录", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { [weak self] _ in
                guard let self = self else {
                    return
                }
                self.doSelectRootFolderPathBtnClickedAction(self.selectRootPathBtn)
            }))
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        server.accept(port: UInt16(serverPort) ?? 12123)
        UserDefaults.standard.set(serverPort, forKey: GSPortKey)
        UserDefaults.standard.synchronize()
        
        doLog("======== 打开服务, 开始监听端口: \(serverPort)")
    }
    
    @IBAction func doSelectRootFolderPathBtnClickedAction(_ sender: UIButton) {
        doLog("======== 开始选择服务器目录")
        let result = PPCatalystHandle.shared().selectFolder(withPath: "~/Desktop")
        selectedRootPathLabel.text = result?.path
        
        doLog("======== 选择服务器目录: \(result?.path ?? "未选择")")
        if let rootPath = result?.path, rootPath.count > 0 {
            self.selectedRootPath = result?.path
            self.server.rootPath = rootPath
        }
    }
    
    
    @IBAction func doRemoveClientLabel(_ sender: Any) {
        self.server.clientSocket?.disconnect()
    }

}
