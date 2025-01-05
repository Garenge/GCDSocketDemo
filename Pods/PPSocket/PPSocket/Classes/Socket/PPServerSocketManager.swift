//
//  Server.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2023/5/17.
//

import Foundation
import CocoaAsyncSocket
import PPCustomAsyncOperation

public class PPServerSocketManager: PPSocketBaseManager {
    
    lazy var socket: GCDAsyncSocket = {
        let socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        return socket
    }()
    
    public func accept(port: UInt16 = 12123) {
        do {
            try socket.accept(onPort: port)
            print("Server 监听端口 \(port) 成功")
        } catch {
            print("Server 监听端口 \(port) 失败: \(error)")
        }
    }
    
    var clientSocket: GCDAsyncSocket?
    
    let rootPath = "/Users/garenge/Downloads"
    
    override func receiveRequestFileList(_ messageFormat: PPSocketMessageFormat) {
        print("Server 收到文件列表请求")
        print(messageFormat)
        
        self.sendFolderList(folderPath: messageFormat.content, messageKey: messageFormat.messageKey)
    }
    
    override func receiveRequestToDownloadFile(_ messageFormat: PPSocketMessageFormat) {
        print("Server 收到下载文件请求")
        print(messageFormat)
        guard let content = messageFormat.content else {
            self.sendDirectionData(socket: self.clientSocket, data: nil, messageKey: messageFormat.messageKey, receiveBlock: nil)
            return
        }
        self.sendFile(filePath: content, messageKey: messageFormat.messageKey)
    }
    
    override func receiveRequestToCancelTask(_ messageFormat: PPSocketMessageFormat) {
        print("Server 收到取消任务请求")
        print(messageFormat)
        self.cancelSendingTask(socket: self.clientSocket, content: messageFormat.content, messageKey: messageFormat.messageKey, receiveBlock: nil)
    }
    
}

extension PPServerSocketManager {
    
    /// 发送消息
    public func sendTestMessage() {
        // 模拟多任务队列
//        do {
//            // 构造一个json
//            let json = ["name": "Server", "age": 18] as [String : Any]
//            if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
//                self.sendDirectionData(socket: self.clientSocket, data: data)
//            }
//        }
//        do {
//            guard let filePath = Bundle.main.path(forResource: "okzxVsJNxXc.jpg", ofType: nil) else {
//                print("文件不存在")
//                return
//            }
//            if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
//                self.sendDirectionData(socket: self.clientSocket, data: data)
//            }
//        }
    }
    
    /// 发送文件夹下的文件列表 folderPath: 空表示根目录
    func sendFolderList(folderPath: String?, messageKey: String?) {
        let filePath = (rootPath as NSString).appendingPathComponent(folderPath ?? "")
        do {
            let fileList = try FileManager.default.contentsOfDirectory(atPath: filePath)
            var models: [PPFileModel] = fileList.map({ fileName in
                var fileModel = PPFileModel()
                fileModel.filePath = (filePath as NSString).appendingPathComponent(fileName)
                
                return fileModel
            })
            models.sort { (model1, model2) -> Bool in
                // 文件夹在前面, 文件大小按顺序
                let inte1 = model1.isFolder ? 1 : 0
                let inte2 = model2.isFolder ? 1 : 0
                if inte1 == inte2 {
                    if (inte1 == 1) {
                        return (model1.fileName ?? "") < (model2.fileName ?? "")
                    } else {
                        return model1.fileSize > model2.fileSize
                    }
                } else {
                    return inte1 > inte2
                }
            }
            
            guard let jsonData = models.pp_convertToJsonData(), let responseStr = String(data: jsonData, encoding: .utf8) else {
                self.sendDirectionData(socket: self.clientSocket, data: nil, messageKey: messageKey, receiveBlock: nil)
                return
            }
            let messageFormat = PPSocketMessageFormat.format(action: .responseFileList, content: responseStr, messageKey: messageKey)
            self.sendDirectionData(socket: self.clientSocket, data: messageFormat.pp_convertToJsonData(), messageKey: messageKey, receiveBlock: nil)
        } catch {
            print("Server 获取文件列表失败: \(error)")
            self.sendDirectionData(socket: self.clientSocket, data: nil, messageKey: messageKey, receiveBlock: nil)
        }
    }
    
    /// 发送文件信息
    public func sendFileInfo(filePath: String) {
        var fileModel = PPFileModel()
        fileModel.filePath = filePath
        
        guard let jsonDic = fileModel.pp_convertToDict(), let jsonData = try? JSONSerialization.data(withJSONObject: jsonDic, options: .prettyPrinted) else {
            return
        }
        self.sendDirectionData(socket: self.clientSocket, data: jsonData, receiveBlock: nil)
    }
    
    /// 发送文件流
    func sendFile(filePath: String, messageKey: String?) {
        self.sendFileData(socket: self.clientSocket, filePath: filePath, messageKey: messageKey)
    }
    
}

extension PPServerSocketManager: GCDAsyncSocketDelegate {
    
    public func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("Server 已连接 \(host):\(port)")
    }
    
    public func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        print("Server accept new socket")
        self.clientSocket = newSocket
        self.clientSocket?.readData(withTimeout: -1, tag: 10086)
    }
    
    public func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("Server 已断开: \(String(describing: err))")
        self.cancelAllSendOperation()
        self.cancelALLReceiveTask()
    }
    
    public func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        // 将新收到的数据追加到缓冲区
        receiveBuffer.append(data)
        
        while receiveBuffer.count >= prefixLength {
            // 读取包头，解析包体长度
            let lengthData = receiveBuffer.subdata(in: (20 + 8 + 8)..<(20 + 8 + 8 + 8))
            let length = Int(String(data: lengthData, encoding: .utf8) ?? "0") ?? 0
            if length == 0 {
                // 有异常数据混入, 这个包丢弃
                receiveBuffer.removeAll()
                break
            }
            
            if receiveBuffer.count >= length {
                // 获取完整包
                let completePacket = receiveBuffer.subdata(in: 0..<length)
                
                // 处理完整包数据
                self.didReceiveData(data: completePacket)
                
                // 移除已处理的包
                receiveBuffer.removeSubrange(0..<length)
            } else {
                // 数据不完整，等待更多数据
                break
            }
        }
        
        self.clientSocket?.readData(withTimeout: -1, tag: 10086)
    }
    
    public func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
//        print("Server 已发送消息, tag:\(tag)")
        self.sendBodyMessage(socket: self.clientSocket)
    }
}
