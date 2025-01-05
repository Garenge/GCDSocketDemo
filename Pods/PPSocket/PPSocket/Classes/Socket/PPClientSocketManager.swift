//
//  Client.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2023/5/17.
//

import Foundation
import CocoaAsyncSocket

public class PPClientSocketManager: PPSocketBaseManager {
    
    lazy var socket: GCDAsyncSocket = {
        let socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        return socket
    }()
    
    public func connect(host: String = "127.0.0.1", port: UInt16 = 12123) {
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
    
    
    /// 这个方法其实不会相应, 因为一对一的任务, 基本已经在block中回调了, 如果实现了block, 就不会走这个自定义方法
    override func receiveResponseFileList(_ messageFormat: PPSocketMessageFormat) {
        print("Client 收到文件列表响应")
        print(messageFormat)
    }
    /// 这个方法其实不会相应, 因为一对一的任务, 基本已经在block中回调了, 如果实现了block, 就不会走这个自定义方法
    override func receiveResponseToCancelTask(_ messageFormat: PPSocketMessageFormat) {
        print("Client 收到取消任务响应")
        print(messageFormat)
    }
    
    /// 取消任务
    public func cancelRequest(_ messageKey: String?, receiveBlock: PPReceiveMessageTaskBlock?) {
        self.cancelSendingTask(socket: self.socket, content: messageKey, messageKey: nil, receiveBlock: receiveBlock)
    }
    
}

extension PPClientSocketManager {
    
    /// 发送消息
    public func sendTestMessage() {
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
        //        self.sendQueryFileList()
    }
    
    /// 获取文件列表
    public func sendQueryFileList(_ path: String? = nil, finished: ((_ fileList: [PPFileModel]?) -> Void)?) {
        let format = PPSocketMessageFormat.format(action: .requestFileList, content: path)
        self.sendDirectionData(socket: self.socket, data: format.pp_convertToJsonData(), receiveBlock: { messageTask in
            print("Client 发送文件列表请求, 收到回复, \(messageTask?.description ?? "")");
            guard let messageTask = messageTask, let messageFormat = PPSocketMessageFormat.format(from: messageTask.directionData!, messageKey: messageTask.messageKey), messageFormat.action == PPSocketActions.responseFileList.getActionString() else {
                finished?(nil)
                return
            }
            let jsonDecoder = JSONDecoder()
            guard let content = messageFormat.content, let data = content.data(using: .utf8), let fileList = try? jsonDecoder.decode([PPFileModel].self, from: data) else {
                finished?(nil)
                return
            }
            finished?(fileList)
        })
    }
    
    public func sendDownloadRequest(filePath: String?, progressBlock: PPReceiveMessageTaskBlock? = nil, receiveBlock: PPReceiveMessageTaskBlock? = nil) -> String? {
        guard let filePath = filePath else {
            return nil
        }
        let format = PPSocketMessageFormat.format(action: .requestToDownloadFile, content: filePath)
        let messageKey = self.sendDirectionData(socket: self.socket, data: format.pp_convertToJsonData()) { messageTask in
            guard let messageTask = messageTask else { return }
//            print("Client 下载文件 进度: \(String(format: "%.2f", messageTask.progress * 100))%")
            progressBlock?(messageTask)
        } receiveBlock: { [weak self] messageTask in
            guard let self = self else { return }
            print("Client 下载文件 结束 \(messageTask?.description ?? "")");
            
            guard let messageTask = messageTask, let localPath = messageTask.filePath else {
                receiveBlock?(messageTask)
                return
            }
            
            let fileName = (filePath as NSString).pathExtension.count > 0 ? (String.GenerateRandomString() + "." + (filePath as NSString).pathExtension) : String.GenerateRandomString()
            let finalPath = self.getDocumentDirectory() + "/" + fileName
            do {
                try FileManager.default.copyItem(atPath: localPath, toPath: finalPath)
                print("Client 下载文件成功: \(finalPath)")
            } catch {
                print("Client 下载文件失败: \(error)")
            }
            receiveBlock?(messageTask)
        }
        return messageKey
    }
}

extension PPClientSocketManager: GCDAsyncSocketDelegate {
    
    public func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("Client 已连接 \(host):\(port)")
        self.socket.readData(withTimeout: -1, tag: 10086)
    }
    
    public func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("Client 已断开: \(String(describing: err))")
        self.cancelAllSendOperation()
        self.cancelALLReceiveTask()
    }
    
    public func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        
//        print("Client 已收到消息:")
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
    
    public func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        print("Client 已发送消息")
        self.sendBodyMessage(socket: self.socket)
    }
}
