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
//        setsockopt(<#T##Int32#>, <#T##Int32#>, <#T##Int32#>, <#T##UnsafeRawPointer!#>, <#T##socklen_t#>)
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

//20个长度, 事件名称, 无业务意义, 仅用作判断相同消息
//8个长度, 包的个数 // 一个包, 最大 8k = 8 * 1024, 其中还有开头的 20+8+8
//8个长度, 包的序号
//8个长度, 转换成字符串, 表示接下来的json长度
//json体
//8个长度, 转换成字符串, 表示接下来的data长度
//二进制流
let maxBodyLength = 12 * 1024

extension Server {
    // 发送消息
    func sendMessage() {

//        let string = "Server" + "-\(count)"
//        let data = string.data(using: .utf8)
        
        let preFixLength = 20 + 8 + 8
        
        guard let filePath = Bundle.main.path(forResource: "okzxVsJNxXc", ofType: "jpg"), let fileData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            return
        }
        let json = ["userName": "garenge", "fileName": "test.txt", "filePath": filePath, "fileSize": fileData.count] as [String : Any]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
            return
        }
        
        var bodyData = Data()
            //8个长度, 转换成字符串, 表示接下来的json长度
        let jsonLength = String(format: "%08d", jsonData.count)
        bodyData.append(jsonLength.data(using: .utf8)!)
            //json体
        bodyData.append(jsonData)
            //8个长度, 转换成字符串, 表示接下来的data长度
        let fileLength = String(format: "%08d", fileData.count)
        bodyData.append(fileLength.data(using: .utf8)!)
            //二进制流
        bodyData.append(fileData)
        
        
        var dataArray: [Data] = []
        var lastIndex = 0
        while (lastIndex < bodyData.count) {
            
            // 从上一个下标开始, 取长度为 maxBodyLength - preFixLength 的流
            var subData: Data
            if (bodyData.count - lastIndex > maxBodyLength - preFixLength) {
                subData = bodyData.subdata(in: lastIndex..<(lastIndex + maxBodyLength - preFixLength))
                lastIndex += subData.count
            } else {
                subData = bodyData.subdata(in: lastIndex..<bodyData.count)
                lastIndex = bodyData.count;
            }
            dataArray.append(subData)
        }
        
        let totalBodyCount = dataArray.count
        for (index, data) in dataArray.enumerated() {
            var sendData = Data()
            
                //20个长度, 区分分包数据
            let oneKey = String(format: "%020d", count)
            sendData.append(oneKey.data(using: .utf8)!)
            
                //8个长度, 包的个数 // 一个包, 最大 8k = 8 * 1024, 其中还有开头的 2+8+8
            let bodyCount = String(format: "%08d", totalBodyCount)
            sendData.append(bodyCount.data(using: .utf8)!)
                //8个长度, 包的序号
            let bodyIndex = String(format: "%08d", index)
            sendData.append(bodyIndex.data(using: .utf8)!)
            
            print("0数据共\(totalBodyCount)包, 当前第\(index)包, 此包大小: \(data.count)")
            sendData.append(data)

            let operation = PPCustomAsyncOperation()
            operation.mainOperationDoBlock = { [weak self] (operation) -> Bool in
                self?.clientSocket?.write(sendData, withTimeout: -1, tag: 10086)
//                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
//                    operation.finish()
//                }
                return false
            }
            queue.addOperation(operation)
            
        }
        
        count += 1
    }
}

extension Server: GCDAsyncSocketDelegate {

    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("Server 已连接 \(host):\(port)")
//        self.clientSocket?.readData(withTimeout: -1, tag: 10086)
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
