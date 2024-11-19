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

    //20个长度, 事件名称, 无业务意义, 仅用作判断相同消息
    //8个长度, 包的个数 // 一个包, 最大 8k = 8 * 1024, 其中还有开头的 20+8+8
    //8个长度, 包的序号
    //8个长度, 转换成字符串, 表示接下来的json长度
    //json体
    //8个长度, 转换成字符串, 表示接下来的data长度
    //二进制流
let maxBodyLength = 12 * 1024

extension Server {
    
    func sendFileData(filePath: String?) {
        
        let preFixLength = 20 + 8 + 8
        
        var json: [String: Any] = ["userName": "garenge", "timeStamp": Date().timeIntervalSince1970]
        var fileSize = 0
        
            // 由于文件不能完全加载成data, 容易内存爆炸, 所以文件改成流式获取
        if
            let filePath = filePath, FileManager.default.fileExists(atPath: filePath),
            let attributes = try? FileManager.default.attributesOfItem(atPath: filePath),
            let size = attributes[.size] as? NSNumber,
            size.int64Value > 0 {
            fileSize = size.intValue
            json["file"] = ["fileName": "test.txt", "filePath": filePath, "fileSize": fileSize]
        }
        
            // json一般都在可控范围, 所以json直接获取data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
            return
        }
        
            // 20 8 8   8  json  8  fileData
            // 所有的数据分包, 每个包由于有固定的开头20+8+8个字节, 所以每个包最多放maxBodyLength - 20 - 8 - 8个长度
        let totalBodySize = 8 + jsonData.count + 8 + fileSize
        let cellBodyLength = maxBodyLength - preFixLength
        let totalBodyCount = (totalBodySize + cellBodyLength - 1) / cellBodyLength
        
            // 整理整个数据, 发现前面数据基本都是可控的, 整块数据可以分成两段, (20 8 8   8  json  8)  fileData
        let preData = {
            var bodyData = Data()
                //8个长度, 转换成字符串, 表示接下来的json长度
            let jsonLength = String(format: "%08d", jsonData.count)
            bodyData.append(jsonLength.data(using: .utf8)!)
                //json体
            bodyData.append(jsonData)
                //8个长度, 转换成字符串, 表示接下来的data长度
            let fileLength = String(format: "%08d", fileSize)
            bodyData.append(fileLength.data(using: .utf8)!)
            return bodyData
        }()
            // 创建一个下标, 从左往右按顺序截取data, 发送数据
        
        var sepIndex = 0
        var cellBodyIndex = 0
        
        var fileHandler: FileHandle? = fileSize > 0 ? FileHandle(forReadingAtPath: filePath!) : nil
        try? fileHandler?.seek(toOffset: 0)
        
        while sepIndex < totalBodySize {
                // 从上一个下标开始, 取长度为 maxBodyLength - preFixLength 的流
            if sepIndex + maxBodyLength - preFixLength < preData.count {
                    // 还没取到file
                let bodyData = preData.subdata(in: sepIndex..<(sepIndex + maxBodyLength - preFixLength))
                self.sendCellBodyData(bodyData: bodyData, totalBodyCount: totalBodyCount, index: cellBodyIndex)
                sepIndex += maxBodyLength - preFixLength
                cellBodyIndex += 1
            } else {
                    // 右边已经到了file
                var bodyData = Data()
                var fileReadCount = 0
                if sepIndex < preData.count {
                    // 左脚在前一块, 后脚在data, 先把前一部分给放到bodyData中
                    bodyData.append(preData.subdata(in: sepIndex..<preData.count))
                    fileReadCount = maxBodyLength - preFixLength - (preData.count - sepIndex)
                    sepIndex = preData.count - sepIndex
                } else {
                    fileReadCount = maxBodyLength - preFixLength
                }
                
                // fileReadCount表示这一次最多还可以读多少数据
                if fileReadCount >= totalBodySize - sepIndex {
                    // 说明这一次可以把文件全取完了
                    if fileSize > 0 {
                        let data = fileHandler!.readData(ofLength: totalBodySize - sepIndex)
                        bodyData.append(data)
                    }
                    sepIndex = totalBodySize
                } else {
                    // 文件只能取一部分
                    let data = fileHandler!.readData(ofLength: fileReadCount)
                    bodyData.append(data)
                    try? fileHandler?.seek(toOffset: UInt64(sepIndex + fileReadCount - preData.count))
                    sepIndex += fileReadCount
                }
                
                self.sendCellBodyData(bodyData: bodyData, totalBodyCount: totalBodyCount, index: cellBodyIndex)
                cellBodyIndex += 1
            }
            
        }
        fileHandler?.closeFile()
        
        count += 1
    }
    
    func sendCellBodyData(bodyData: Data, totalBodyCount: Int, index: Int) {
        var sendData = Data()
        
            //20个长度, 区分分包数据
        let oneKey = String(format: "%020d", count)
        sendData.append(oneKey.data(using: .utf8)!)
        
            //8个长度, 包的个数 // 一个包, 最大 8k = 8 * 1024, 其中还有开头的 2+8+8
        let bodyCount = String(format: "%08lld", totalBodyCount)
        sendData.append(bodyCount.data(using: .utf8)!)
            //8个长度, 包的序号
        let bodyIndex = String(format: "%08lld", index)
        sendData.append(bodyIndex.data(using: .utf8)!)
        
        print("0数据共\(totalBodyCount)包, 当前第\(index)包, 此包大小: \(bodyData.count)")
        sendData.append(bodyData)
        
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
        // 发送消息
        // TODO: 后期方法, 封装成传参形式, 将文件地址传进来, 然后使用流式读取, 避免一次性读取文件过大, 导致内存暴涨
    func sendMessage() {
        
            //        let string = "Server" + "-\(count)"
            //        let data = string.data(using: .utf8)  okzxVsJNxXc
        let filePath = Bundle.main.path(forResource: "okzxVsJNxXc", ofType: "jpg")
        self.sendFileData(filePath: filePath)
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
