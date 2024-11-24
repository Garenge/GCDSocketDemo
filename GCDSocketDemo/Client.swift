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
    
    var receiveBuffer = Data()
    
    var prefixLength = 20 + 8 + 8 + 8 + 16
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
    
    
    func didReceiveData(data: Data) {
        if (data.count < prefixLength) {
            return
        }
        var parseIndex = 0
        guard let messageKey = String(data: data.subdata(in: parseIndex..<18), encoding: .utf8) else { return }
        parseIndex += 18
        
        guard let messageTypeStr = String(data: data.subdata(in: parseIndex..<parseIndex + 2), encoding: .utf8), let messageType = Int(messageTypeStr) else { return }
        if MessageManager.MessageType(rawValue: messageType) != .file {
            return
        }
        parseIndex += 2
        
        guard let bodyCountStr = String(data: data.subdata(in: parseIndex..<parseIndex + 8), encoding: .utf8), let bodyCount = Int(bodyCountStr) else { return }
        parseIndex += 8
        
        
        guard let bodyIndexStr = String(data: data.subdata(in: parseIndex..<parseIndex + 8), encoding: .utf8), let bodyIndex = Int(bodyIndexStr) else { return }
        parseIndex += 8
        
        guard let bodyLengthStr = String(data: data.subdata(in: parseIndex..<parseIndex + 8), encoding: .utf8), let _ = Int(bodyLengthStr) else { return }
        parseIndex += 8
        
        guard let totalLengthStr = String(data: data.subdata(in: parseIndex..<parseIndex + 16), encoding: .utf8), let _ = Int(totalLengthStr) else { return }
        parseIndex += 16
        
        var messageBody = self.receivedMessageDic[messageKey]
        if nil == messageBody {
            messageBody = MessageBody()
            self.receivedMessageDic[messageKey] = messageBody
        }
        messageBody?.totalBodyLength += UInt(data.count - parseIndex)
        print("1数据共\(bodyCount)包, 当前第\(bodyIndex)包, 此包大小: \(data.count - parseIndex), 总大小: \(messageBody!.totalBodyLength)")
        messageBody?.bodyCount = bodyCount
        messageBody?.bodyIndex = bodyIndex
        
        // TODO: 根据messageTypeStr区分是文件, 还是json, 选择合适的方式拼接data
        
        if nil == messageBody?.fileHandle {
            // TODO: 理论上, 客户端先请求文件, 然后服务端开始发送文件, 所以客户端是知道文件格式的, 这里可以根据文件格式来确定文件后缀名
            let fileName = messageKey + ".jpg"
            messageBody?.filePath = getDocumentDirectory() + "/" + fileName
            print("文件地址: \(messageBody?.filePath ?? "")")
            if let filePath = messageBody?.filePath {
                try? FileManager.default.removeItem(atPath: filePath)
                if !FileManager.default.fileExists(atPath: filePath) {
                    FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)
                }
                let fileHandle = FileHandle(forWritingAtPath: filePath)
                messageBody?.fileHandle = fileHandle
            }
        }
        
        // 将文件流直接写到文件中去, 避免内存暴涨
        let fileData = data.subdata(in: parseIndex..<data.count)
        
        messageBody?.fileHandle?.write(fileData)
        try? messageBody?.fileHandle?.seek(toOffset: UInt64(messageBody!.totalBodyLength))
        
        if (bodyCount == bodyIndex + 1) {
            print("数据所有包都合并完成")
            try? messageBody?.fileHandle?.close()
            self.receivedMessageDic[messageKey] = nil
            
        } else {
            print("数据所有包未合并完成, 共\(bodyCount)包, 当前第\(bodyIndex)包, 继续等待")
        }
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
        // 将新收到的数据追加到缓冲区
        print("Client 已收到消息:")
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
    }
}
