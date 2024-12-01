//
//  SocketBaseManager.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2024/12/1.
//

import UIKit
import PPCustomAsyncOperation

class SocketBaseManager: NSObject {
    
    /// 标记当前任务的序号, 可以理解为唯一标识, 处理完一个事件, 可以+1
    var sendMessageIndex = 0
    /// 18, 事件名称, 无业务意义, 仅用作判断相同消息
    /// 2, 数据类型, 00: 默认, json, 01: 文件
    /// 8个长度, 分包, 包的个数 // 一个包, 放 maxBodyLength - prefixLength
    /// 8个长度, 分包, 包的序号
    /// 8个长度, 分包, 包的长度
    /// 16个长度, 转换成字符串, 表示此次传输的数据长度
    /// 数据
    var prefixLength = 20 + 8 + 8 + 8 + 16
    
    // MARK: - 发消息
    /// 消息管理, 当前的消息体, 任务自动跟随执行
    var currentSendMessageTask: SendMessageTask?
    /// 多消息排序发送, 可以发送json, 或者file
    lazy var sendMessageQueue: PPCustomOperationQueue = {
        let queue = PPCustomOperationQueue()
        queue.maxConcurrentOperationCount = 1;
        return queue
    }()
    
    /// 直接发送数据, 直传
    func sendDirectionData(socket: GCDAsyncSocket?, data: Data) {
        let operation = PPCustomAsyncOperation()
        operation.mainOperationDoBlock = { [weak self] (operation) -> Bool in
            self?.currentSendMessageTask = SendMessageTask()
            self?.currentSendMessageTask?.hasAllMessageDone = false
            self?.currentSendMessageTask?.messageType = .directionData
            self?.currentSendMessageTask?.toSendDirectionData = data
            self?.sendBodyMessage(socket: socket)
            return false
        }
        sendMessageQueue.addOperation(operation)
    }
    
    /// 发送文件data
    func sendFileData(socket: GCDAsyncSocket?, filePath: String) {
        
        let operation = PPCustomAsyncOperation()
        operation.mainOperationDoBlock = { [weak self] (operation) -> Bool in
            self?.currentSendMessageTask = SendMessageTask()
            self?.currentSendMessageTask?.hasAllMessageDone = false
            self?.currentSendMessageTask?.messageType = .fileData
            self?.currentSendMessageTask?.readFilePath = filePath
            self?.sendBodyMessage(socket: socket)
            return false
        }
        sendMessageQueue.addOperation(operation)
    }
    
    /// 发送包数据, 每次发完一个包数据, 就继续尝试发下一个, 除非任务结束
    func sendBodyMessage(socket: GCDAsyncSocket?) {
        switch self.currentSendMessageTask?.messageType {
        case .directionData:
            self.currentSendMessageTask?.createJsonBodyData(cellMessageBlock: { [weak self] (bodyData, totalBodyCount, index) in
                self?.sendCellBodyData(socket: socket, bodyData: bodyData, messageType: .directionData, totalBodyCount: totalBodyCount, index: index)
            }, finishedAllTask: { [weak self] in
                /// 上个任务结束
                self?.sendMessageIndex += 1
                self?.currentSendMessageTask = nil
                (self?.sendMessageQueue.operations.first as? PPCustomAsyncOperation)?.finish()
            }, failureBlock: { msg in
                print(msg)
            })
        case .fileData:
            self.currentSendMessageTask?.createSendFileBodyData { [weak self] (bodyData, totalBodyCount, index) in
                if index < totalBodyCount {
                    self?.sendCellBodyData(socket: socket, bodyData: bodyData, messageType: .fileData, totalBodyCount: totalBodyCount, index: index)
                }
            } finishedAllTask: { [weak self] in
                
                /// 上个任务结束
                self?.sendMessageIndex += 1
                self?.currentSendMessageTask = nil
                (self?.sendMessageQueue.operations.first as? PPCustomAsyncOperation)?.finish()
            } failureBlock: { msg in
                print(msg)
            }
        default:
            break
        }
    }
    
    /// 分包发送数据
    func sendCellBodyData(socket: GCDAsyncSocket?, bodyData: Data, messageType: TransMessageType, totalBodyCount: Int, index: Int) {
        if let sendData = currentSendMessageTask?.createSendCellBodyData(bodyData: bodyData, messageCode: String(format: "%018d", sendMessageIndex), messageType: messageType, totalBodyCount: totalBodyCount, index: index) {
            socket?.write(sendData, withTimeout: -1, tag: 10086)
        }
    }
    
    // MARK: - 收消息
    var receivedMessageDic: [String: ReceiveMessageTask] = [:]
    /// tcp是数据流, 所以不代表每次拿到数据就是完整的, 需要自己处理数据的完整性
    var receiveBuffer = Data()
    
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
        parseIndex += 2
        
        guard let bodyCountStr = String(data: data.subdata(in: parseIndex..<parseIndex + 8), encoding: .utf8), let bodyCount = Int(bodyCountStr) else { return }
        parseIndex += 8
        
        
        guard let bodyIndexStr = String(data: data.subdata(in: parseIndex..<parseIndex + 8), encoding: .utf8), let bodyIndex = Int(bodyIndexStr) else { return }
        parseIndex += 8
        
        guard let bodyLengthStr = String(data: data.subdata(in: parseIndex..<parseIndex + 8), encoding: .utf8), let _ = Int(bodyLengthStr) else { return }
        parseIndex += 8
        
        guard let totalLengthStr = String(data: data.subdata(in: parseIndex..<parseIndex + 16), encoding: .utf8), let totalLength = UInt64(totalLengthStr) else { return }
        parseIndex += 16
        
        var messageBody = self.receivedMessageDic[messageKey]
        if nil == messageBody {
            messageBody = ReceiveMessageTask()
            messageBody?.messageKey = messageKey
            messageBody?.totalLength = totalLength
            self.receivedMessageDic[messageKey] = messageBody
        }
        messageBody?.receivedOffset += UInt64(data.count - parseIndex)
        print("1数据共\(bodyCount)包, 当前第\(bodyIndex)包, 此包大小: \(data.count - parseIndex), 总大小: \(messageBody!.receivedOffset)")
        messageBody?.bodyCount = bodyCount
        messageBody?.bodyIndex = bodyIndex
        
        // TODO: 根据messageTypeStr区分是文件, 还是json, 选择合适的方式拼接data
        switch TransMessageType(rawValue: messageType) {
        case .directionData:
            self.doReceiveData(messageBody!, data: data, parseIndex: parseIndex)
        case .fileData: do {
            self.doReceiveFile(messageBody!, data: data, parseIndex: parseIndex)
        }
        default:
            break
        }
    }
    
    /// 处理收到的文件数据
    func doReceiveFile(_ messageBody: ReceiveMessageTask, data: Data, parseIndex: Int) {
        guard let messageKey = messageBody.messageKey else {
            return
        }
        if nil == messageBody.fileHandle {
            // TODO: 理论上, 客户端先请求文件, 然后服务端开始发送文件, 所以客户端是知道文件格式的, 这里可以根据文件格式来确定文件后缀名
            let fileName = messageKey + ".jpg"
            messageBody.filePath = getDocumentDirectory() + "/" + fileName
            print("文件地址: \(messageBody.filePath ?? "")")
            if let filePath = messageBody.filePath {
                try? FileManager.default.removeItem(atPath: filePath)
                if !FileManager.default.fileExists(atPath: filePath) {
                    FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)
                }
                let fileHandle = FileHandle(forWritingAtPath: filePath)
                messageBody.fileHandle = fileHandle
            }
        }
        
        // 将文件流直接写到文件中去, 避免内存暴涨
        let fileData = data.subdata(in: parseIndex..<data.count)
        
        messageBody.fileHandle?.write(fileData)
        messageBody.receivedOffset += UInt64(fileData.count)
        
        try? messageBody.fileHandle?.seek(toOffset: UInt64(messageBody.receivedOffset))
        
        if (messageBody.bodyCount == messageBody.bodyIndex + 1) {
            print("数据所有包都合并完成")
            try? messageBody.fileHandle?.close()
            self.receivedMessageDic[messageKey] = nil
            
        } else {
            print("数据所有包未合并完成, 共\(messageBody.bodyCount)包, 当前第\(messageBody.bodyIndex)包, 继续等待")
        }
    }
    
    /// 处理收到的data数据
    func doReceiveData(_ messageBody: ReceiveMessageTask, data: Data, parseIndex: Int) {
        guard let messageKey = messageBody.messageKey else {
            return
        }
        if nil == messageBody.directionData {
            messageBody.directionData = Data()
        }
        
        // 直接合并数据
        messageBody.directionData?.append(data.subdata(in: parseIndex..<data.count))
        messageBody.receivedOffset += UInt64(data.count - parseIndex)
        
        if (messageBody.bodyCount == messageBody.bodyIndex + 1) {
            print("数据所有包都合并完成")
            self.receivedMessageDic[messageKey] = nil
            
            if let json = try? JSONSerialization.jsonObject(with: messageBody.directionData!, options: .mutableContainers) {
                print("收到数据: \(json)")
            } else {
                // 可能是文件, 写入文件试试
                // TODO: 理论上, 客户端先请求文件, 然后服务端开始发送文件, 所以客户端是知道文件格式的, 这里可以根据文件格式来确定文件后缀名
                let fileName = messageKey + ".jpg"
                let filePath = getDocumentDirectory() + "/" + fileName
                print("文件地址: \(filePath)")
                try? FileManager.default.removeItem(atPath: filePath)
                if !FileManager.default.fileExists(atPath: filePath) {
                    FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)
                }
                try? messageBody.directionData?.write(to: URL(fileURLWithPath: filePath))
            }
            
        } else {
            print("数据所有包未合并完成, 共\(messageBody.bodyCount)包, 当前第\(messageBody.bodyIndex)包, 继续等待")
        }
    }
}
