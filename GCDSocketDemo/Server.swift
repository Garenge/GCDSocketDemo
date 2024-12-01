//
//  Server.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2023/5/17.
//

import Foundation
import PPCustomAsyncOperation

class Server: NSObject {
    
    /// 多文件排序发送
    lazy var queue: PPCustomOperationQueue = {
        let queue = PPCustomOperationQueue()
        queue.maxConcurrentOperationCount = 1;
        return queue
    }()
    
    lazy var socket: GCDAsyncSocket = {
        let socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        return socket
    }()
    
    func accept(port: UInt16 = 12123) {
        do {
            try socket.accept(onPort: port)
            print("Server 监听端口 \(port) 成功")
        } catch {
            print("Server 监听端口 \(port) 失败: \(error)")
        }
    }
    
    //    func connect() {
    //        if !self.socket.isConnected {
    //            do {
    //                try self.socket.connect(toHost: "127.0.0.1", onPort: 8888, withTimeout: -1)
    //            } catch {
    //                print("Server connect to socket error: \(error)")
    //            }
    //        }
    //    }
    
    var clientSocket: GCDAsyncSocket?
    
    /// 标记发送事件, 处理完一个事件, 可以+1
    var count = 0
    
    /// 消息管理, 当前的消息体, 任务自动跟随执行
    var messageManager: MessageManager?
}

extension Server {
    
    func sendJsonData(data: Data) {
//        messageManager.makeJsonBodyData(data: data) { [weak self] (bodyData, totalBodyCount, index) in
//            self?.sendCellBodyData(bodyData: bodyData, messageType: .json, totalBodyCount: totalBodyCount, index: index)
//        }
//        count += 1
    }
    
    func sendFileData(filePath: String) {
        
        let operation = PPCustomAsyncOperation()
        operation.mainOperationDoBlock = { [weak self] (operation) -> Bool in
            self?.messageManager = MessageManager()
            self?.messageManager?.hasAllMessageDone = false
            self?.messageManager?.readFilePath = filePath
            self?.sendBodyMessage()
            return false
        }
        queue.addOperation(operation)
    }
    
    func sendBodyMessage() {
        self.messageManager?.makeFileBodyData { [weak self] (bodyData, totalBodyCount, index) in
            if index < totalBodyCount {
                self?.sendCellBodyData(bodyData: bodyData, messageType: .file, totalBodyCount: totalBodyCount, index: index)
            }
        } finishedAllTask: { [weak self] in
            
            /// 上个任务结束
            self?.count += 1
            self?.messageManager?.finishTask()
            self?.messageManager = nil
            (self?.queue.operations.first as? PPCustomAsyncOperation)?.finish()
        } failureBlock: { msg in
            print(msg)
        }
    }
    
    func sendCellBodyData(bodyData: Data, messageType: MessageManager.MessageType, totalBodyCount: Int, index: Int) {
        if let sendData = messageManager?.makeCellBodyData(bodyData: bodyData, messageCode: String(format: "%018d", count), messageType: messageType, totalBodyCount: totalBodyCount, index: index) {
            self.clientSocket?.write(sendData, withTimeout: -1, tag: 10086)
        }
    }
    /// 发送消息
    func sendMessage() {
        // 模拟多任务队列
        do {
            guard let filePath = Bundle.main.path(forResource: "okzxVsJNxXc.jpg", ofType: nil) else {
                print("文件不存在")
                return
            }
            self.sendFileData(filePath: filePath)
        }
        
        do {
            guard let filePath = Bundle.main.path(forResource: "故障.txt", ofType: nil) else {
                print("文件不存在")
                return
            }
            self.sendFileData(filePath: filePath)
        }
    }
}

extension Server: GCDAsyncSocketDelegate {
    
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("Server 已连接 \(host):\(port)")
    }
    
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        print("Server accept new socket")
        self.clientSocket = newSocket
        self.clientSocket?.readData(withTimeout: -1, tag: 10086)
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("Server 已断开: \(String(describing: err))")
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        let string = String(data: data, encoding: .utf8)
        print("Server 已收到消息: \(String(describing: string))")
        self.clientSocket?.readData(withTimeout: -1, tag: 10086)
    }
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        print("Server 已发送消息, tag:\(tag)")
        self.sendBodyMessage()
    }
}
