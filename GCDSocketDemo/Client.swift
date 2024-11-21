//
//  Client.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2023/5/17.
//

import Foundation

class MessageBody: NSObject {
    var bodyCount: Int = 1
    var bodyIndex: Int = 0
    var totalBodyLength: UInt = 0
    //    var bodyData: Data = Data()
    var filePath: String?
    var fileHandle: FileHandle?
}

class Client: NSObject {
    
    var receivedMessageDic: [String: MessageBody] = [:]
    
    lazy var socket: GCDAsyncSocket = {
        let socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        //        do {
        //            try socket.accept(onPort: 8888)
        //        } catch {
        //            print("Client 监听端口 8888 失败: \(error)")
        //        }
        return socket
    }()
    
    func connect() {
        if !self.socket.isConnected {
            do {
                try self.socket.connect(toHost: "127.0.0.1", onPort: 12123, withTimeout: -1)
            } catch {
                print("Client connect to socket error: \(error)")
            }
        }
    }
    
    var count = 0
}

extension Client {
    // 发送消息
    func sendMessage() {
        
        let string = "Client" + "-\(count)"
        let data = string.data(using: .utf8)
        self.socket.write(data, withTimeout: -1, tag: 10086)
        count += 1
    }
    
    func getDocumentDirectory() -> String {
        let docuPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory,
                                                            .userDomainMask, true)
        let docuPath = docuPaths[0]
        // print(docuPath)
        return docuPath
    }
}

extension Client: GCDAsyncSocketDelegate {
    
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("Client 已连接 \(host):\(port)")
        self.socket.readData(withTimeout: -1, tag: 10086)
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("Client 已断开: \(String(describing: err))")
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        let string = String(data: data, encoding: .utf8)
        print("Client 已收到消息: \(String(describing: string))")
        
        
        //20个长度, 事件名称, 无业务意义, 仅用作判断相同消息
        //8个长度, 包的个数 // 一个包, 最大 8k = 8 * 1024, 其中还有开头的 20+8+8
        //8个长度, 包的序号
        //8个长度, 转换成字符串, 表示接下来的data长度
        //二进制流
        self.socket.readData(withTimeout: -1, tag: 10086)
        
        if (data.count < 20+8+8) {
            return
        }
        var parseIndex = 0
        guard let messageKey = String(data: data.subdata(in: parseIndex..<18), encoding: .utf8) else { return }
        parseIndex += 18
        
        guard let messageTypeStr = String(data: data.subdata(in: parseIndex..<parseIndex + 2), encoding: .utf8), let messageType = Int(messageTypeStr) else { return }
        if MessageManager.MessageType(rawValue: messageType) != .file {
            return
        }
        
        guard let bodyCountStr = String(data: data.subdata(in: parseIndex..<parseIndex + 8), encoding: .utf8), let bodyCount = Int(bodyCountStr) else { return }
        parseIndex += 8
        
        
        guard let bodyIndexStr = String(data: data.subdata(in: parseIndex..<parseIndex + 8), encoding: .utf8), let bodyIndex = Int(bodyIndexStr) else { return }
        parseIndex += 8
        
        //        print("数据共\(bodyCount)包, 当前第\(bodyIndex)包, 继续等待")
        
        var messageBody = self.receivedMessageDic[messageKey]
        if nil == messageBody {
            messageBody = MessageBody()
            self.receivedMessageDic[messageKey] = messageBody
        }
        messageBody?.totalBodyLength += UInt(data.count - parseIndex)
        print("1数据共\(bodyCount)包, 当前第\(bodyIndex)包, 此包大小: \(data.count - parseIndex), 总大小: \(messageBody!.totalBodyLength)")
        messageBody?.bodyCount = bodyCount
        messageBody?.bodyIndex = bodyIndex
        //
        if nil == messageBody?.fileHandle {
            messageBody?.filePath = getDocumentDirectory() + "/buubbubu.jpg"
            
            let fileHandle = FileHandle(forWritingAtPath: messageBody!.filePath!)
            messageBody?.fileHandle = fileHandle
        }
        
        // TODO: 后期方法, 当我通过前一个包, 或者两个包, 能获取到json的数据之后, 解析, 发现是文件的话, 就将后续的文件流直接写到文件中去, 避免内存暴涨
        messageBody?.fileHandle?.write(data.subdata(in: parseIndex..<data.count))
        try? messageBody?.fileHandle?.seek(toOffset: UInt64(messageBody!.totalBodyLength))
        
        if (bodyCount == bodyIndex + 1) {
            print("数据所有包都合并完成")
            
            if let filePath = messageBody?.filePath, FileManager.default.fileExists(atPath: filePath) {
                print("收到文件, 写入成功")
            } else {
                print("收到文件, 写入失败")
            }
            self.receivedMessageDic[messageKey] = nil
            
            
        } else {
            print("数据所有包未合并完成, 共\(bodyCount)包, 当前第\(bodyIndex)包, 继续等待")
        }
    }
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        print("Client 已发送消息")
    }
}
