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
    
    @IBOutlet weak var serverPortTF: UITextField!
    @IBOutlet weak var currentClientLabel: UILabel!
    @IBOutlet weak var selectedRootPathLabel: UILabel!
    @IBOutlet weak var receivedMessageTextView: UITextView!
    
    let server = PPServerSocketManager()
    
    var serverPort: String {
        if let port = self.serverPortTF.text, port.count > 0 {
            return port
        }
        return "12123"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.serverPortTF.text = UserDefaults.standard.string(forKey: GSPortKey)
    }

    @IBAction func doStartServerBtnClickedAction(_ sender: Any) {
        server.accept(port: UInt16(serverPort) ?? 12123)
        UserDefaults.standard.set(serverPort, forKey: GSPortKey)
        UserDefaults.standard.synchronize()
    }
    
    @IBAction func doSelectRootFolderPathBtnClickedAction(_ sender: Any) {
        let result = PPCatalystHandle.shared().selectSingleFile(withFolderPath: "~/Desktop")
        selectedRootPathLabel.text = result?.path
    }
    
    
    @IBAction func doRemoveClientLabel(_ sender: Any) {
        
    }
    
    
    //    @IBAction func doSendFileAction(_ sender: Any) {
    //        guard let filePath = self.filePathTF.text, filePath.count > 0 else {
    //            return
    //        }
    //        server.sendFileInfo(filePath: filePath)
    //    }
    //    @IBAction func doShowFiles(_ sender: Any) {
    //        let filesVC = FilesListViewController()
    //        filesVC.client = client
    //        self.navigationController?.pushViewController(filesVC, animated: true)
    //    }
}
