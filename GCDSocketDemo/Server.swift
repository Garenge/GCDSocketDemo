//
//  Server.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2023/5/17.
//

import Foundation
import PPCustomAsyncOperation

class Server: NSObject {
    
    lazy var queue: PPCustomOperationQueue = {
        let queue = PPCustomOperationQueue()
        queue.maxConcurrentOperationCount = 1;
        return queue
    }()
    
    lazy var socket: GCDAsyncSocket = {
        let socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        return socket
    }()
    
    func accept() {
        do {
            try socket.accept(onPort: 12123)
        } catch {
            print("Server 监听端口 12123 失败: \(error)")
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
    
    var count = 0
}

extension Server {
    
    func sendJsonData(data: Data) {
        MessageManager.makeJsonBodyData(data: data) { [weak self] (bodyData, totalBodyCount, index) in
            self?.sendCellBodyData(bodyData: bodyData, messageType: .json, totalBodyCount: totalBodyCount, index: index)
        }
        count += 1
    }
    
    func sendFileData(filePath: String) {
        
        
        MessageManager.makeFileBodyData(filePath: filePath) { [weak self] (bodyData, totalBodyCount, index) in
            self?.sendCellBodyData(bodyData: bodyData, messageType: .file, totalBodyCount: totalBodyCount, index: index)
        } failureBlock: { msg in
            print(msg)
        }
        
        count += 1
    }
    
    func sendCellBodyData(bodyData: Data, messageType: MessageManager.MessageType, totalBodyCount: Int, index: Int) {
        let sendData = MessageManager.makeCellBodyData(bodyData: bodyData, messageCode: String(format: "%018d", count), messageType: messageType, totalBodyCount: totalBodyCount, index: index)
        
        let operation = PPCustomAsyncOperation()
        operation.mainOperationDoBlock = { [weak self] (operation) -> Bool in
            self?.clientSocket?.write(sendData, withTimeout: -1, tag: 10086)
            return false
        }
        queue.addOperation(operation)
    }
    // 发送消息
    // TODO: 后期方法, 封装成传参形式, 将文件地址传进来, 然后使用流式读取, 避免一次性读取文件过大, 导致内存暴涨
    func sendMessage() {
        
        //        let string = "Server" + "-\(count)"
        //        let data = string.data(using: .utf8)  okzxVsJNxXc
        
        //        var json: [String: Any] = ["userName": "garenge", "timeStamp": Date().timeIntervalSince1970]
        //        var fileSize = 0
        //
        //            // 由于文件不能完全加载成data, 容易内存爆炸, 所以文件改成流式获取
        //        if
        //            let filePath = filePath, FileManager.default.fileExists(atPath: filePath),
        //            let attributes = try? FileManager.default.attributesOfItem(atPath: filePath),
        //            let size = attributes[.size] as? NSNumber,
        //            size.int64Value > 0 {
        //            fileSize = size.intValue
        //            json["file"] = ["fileName": "test.txt", "filePath": filePath, "fileSize": fileSize]
        //        }
        //
        //            // json一般都在可控范围, 所以json直接获取data
        //        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
        //            return
        //        }
        
        
        guard let filePath = Bundle.main.path(forResource: "IMG_1555_2.mov", ofType: nil) else {
            print("文件不存在")
            return
        }
//        let filePath = "/Users/garenge/Downloads/Jietu20241027-145102-HD.mp4"
        self.sendFileData(filePath: filePath)
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
        (self.queue.operations.first as? PPCustomAsyncOperation)?.finish()
    }
}
