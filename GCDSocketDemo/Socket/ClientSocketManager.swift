//
//  Client.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2023/5/17.
//

import Foundation

class ClientSocketManager: SocketBaseManager {
    
    lazy var socket: GCDAsyncSocket = {
        let socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        return socket
    }()
    
    func connect(host: String = "127.0.0.1", port: UInt16 = 12123) {
        if !self.socket.isConnected {
            do {
                try self.socket.connect(toHost: host, onPort: port, withTimeout: -1)
                print("Client: \(host):\(port) 开始连接")
            } catch {
                print("Client connect to socket: \(host):\(port) error: \(error)")
            }
        } else {
            print("Client: \(host):\(port) 已连接, 无需重复连接")
        }
    }
    
    override func receiveResponseFileList(_ messageFormat: SocketMessageFormat) {
        print("Client 收到文件列表响应")
        print(messageFormat)
    }
    
}

extension ClientSocketManager {
    
    /// 发送消息
    func sendTestMessage() {
//        // 模拟多任务队列
//        do {
//            // 构造一个json
//            let json = ["name": "Client", "age": 18] as [String : Any]
//            if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
//                self.sendDirectionData(socket: self.socket, data: data)
//            }
//        }
//        do {
//            guard let filePath = Bundle.main.path(forResource: "okzxVsJNxXc.jpg", ofType: nil) else {
//                print("文件不存在")
//                return
//            }
//            self.sendFileData(socket: self.socket, filePath: filePath)
//        }
        self.sendQueryFileList()
    }
    
    /// 获取文件列表
    func sendQueryFileList() {
        let format = SocketMessageFormat.format(action: .requestFileList, content: nil)
        self.sendDirectionData(socket: self.socket, data: format.convertToJsonData(), receiveBlock: { messageTask in
            print("Client 发送文件列表请求, 收到回复, \(messageTask?.description ?? "")");
            guard let messageTask = messageTask, let messageFormat = SocketMessageFormat.format(from: messageTask.directionData!, messageKey: messageTask.messageKey), messageFormat.action == GSActions.responseFileList.getActionString() else {
                return
            }
            let jsonDecoder = JSONDecoder()
            guard let content = messageFormat.content, let data = content.data(using: .utf8), let fileList = try? jsonDecoder.decode([FileModel].self, from: data) else {
                return
            }
            if fileList.count > 0 {
                // 尝试下载第一个文件
                self.sendDownloadRequest(filePath: fileList[0].filePath)
            }
        })
    }
    
    func sendDownloadRequest(filePath: String?) {
        guard let filePath = filePath else {
            return
        }
        let format = SocketMessageFormat.format(action: .requestToDownloadFile, content: filePath)
        self.sendDirectionData(socket: self.socket, data: format.convertToJsonData()) { messageTask in
            guard let messageTask = messageTask else { return }
            print("Client 下载文件 进度: \(messageTask.progress)")
        } receiveBlock: { [weak self] messageTask in
            guard let self = self else { return }
            print("Client 下载文件 结束 \(messageTask?.description ?? "")");
            
            guard let messageTask = messageTask, let localPath = messageTask.filePath else {
                return
            }
            
            let fileName = String.GenerateRandomString() + "." + (filePath as NSString).pathExtension
            let finalPath = self.getDocumentDirectory() + "/" + fileName
            do {
                try FileManager.default.copyItem(atPath: localPath, toPath: finalPath)
                print("Client 下载文件成功: \(finalPath)")
            } catch {
                print("Client 下载文件失败: \(error)")
            }
        }
    }
}

extension ClientSocketManager: GCDAsyncSocketDelegate {
    
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("Client 已连接 \(host):\(port)")
        self.socket.readData(withTimeout: -1, tag: 10086)
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("Client 已断开: \(String(describing: err))")
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        
        print("Client 已收到消息:")
        // 将新收到的数据追加到缓冲区
        receiveBuffer.append(data)
        
        while receiveBuffer.count >= prefixLength {
            // 读取包头，解析包体长度
            let lengthData = receiveBuffer.subdata(in: (20 + 8 + 8)..<(20 + 8 + 8 + 8))
            let length = Int(String(data: lengthData, encoding: .utf8) ?? "0") ?? 0
            
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
        
        // 继续读取数据
        sock.readData(withTimeout: -1, tag: tag)
    }
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        print("Client 已发送消息")
        self.sendBodyMessage(socket: self.socket)
    }
}
