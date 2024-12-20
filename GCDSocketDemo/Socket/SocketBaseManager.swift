//
//  SocketBaseManager.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2024/12/1.
//

import UIKit
import CryptoKit
import PPCustomAsyncOperation

extension String {
    static func GenerateRandomString(length: Int = 18) -> String {
        // 1. 创建种子数据（时间戳 + 随机数）
        let timestamp = Date().timeIntervalSince1970
        let randomValue = UUID().uuidString
        let seed = "\(timestamp)\(randomValue)"
        
        // 2. 使用 SHA256 生成哈希
        let hash = SHA256.hash(data: Data(seed.utf8))
        
        // 3. 将哈希值转为十六进制字符串
        let hexString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // 4. 截取前18位
        let uniqueID = String(hexString.prefix(length))
        return uniqueID
    }
}


struct FileModel: Codable, Convertable {
    
    /// 文件名
    var fileName: String?
    /// 文件路径
    var filePath: String? {
        didSet {
            if let path = filePath {
                let url = URL(fileURLWithPath: path)
                do {
                    let attr = try FileManager.default.attributesOfItem(atPath: url.path)
                    fileName = url.lastPathComponent
                    fileSize = attr[FileAttributeKey.size] as? UInt64 ?? 0
                    pathExtension = url.pathExtension
                    
                    if let fileType = attr[FileAttributeKey.type] as? FileAttributeType {
                        switch fileType {
                        case .typeDirectory:
                            isFolder = true
                        case .typeRegular:
                            isFolder = false
                        default:
                            isFolder = false
                        }
                    }
                } catch {
                    print("获取文件信息失败: \(error)")
                }
            }
        }
    }
    /// 文件大小
    var fileSize: UInt64 = 0
    /// 是否是文件夹
    var isFolder: Bool = false
    /// 文件后缀名
    var pathExtension: String?
    /// 此文件, 会对应一个本地的唯一key, 到时候client请求下载, server将key作为事件名称
    var fileKey: String = String.GenerateRandomString()
}

struct SocketMessageFormat: Codable, Convertable {
    var action: String?
    var content: String?
    var messageKey: String = String.GenerateRandomString()
    
    static func format(action: GSActions, content: String?, messageKey: String? = nil) -> SocketMessageFormat {
        var format = SocketMessageFormat()
        format.action = action.getActionString()
        format.content = content
        if let key = messageKey {
            format.messageKey = key
        }
        return format
    }
    
    static func format(from: Data?, messageKey: String? = nil) -> SocketMessageFormat? {
        if let data = from {
            let decoder = JSONDecoder()
            if var model = try? decoder.decode(SocketMessageFormat.self, from: data) {
                if let key = messageKey {
                    model.messageKey = key
                }
                return model
            }
        }
        return nil
    }
}

class SocketBaseManager: NSObject {
    
    /// 标记当前任务的序号, 可以理解为唯一标识, 处理完一个事件, 需要重置
    var sendMessageIndex = String.GenerateRandomString(length: 18) {
        didSet {
            print("====")
        }
    }
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
    
    /// 直接发送数据, 直传(尽量文件不用直传, 采用文件专门的传输, 或者文件传输的时候, key用文件自己的key)
    func sendDirectionData(socket: GCDAsyncSocket?, data: Data?, messageKey: String? = nil, progressBlock: ReceiveMessageTaskBlock? = nil, receiveBlock: ReceiveMessageTaskBlock?) {
        let operation = PPCustomAsyncOperation()
        operation.mainOperationDoBlock = { [weak self] (operation) -> Bool in
            self?.currentSendMessageTask = SendMessageTask()
            self?.currentSendMessageTask?.hasAllMessageDone = false
            self?.currentSendMessageTask?.messageType = .directionData
            self?.currentSendMessageTask?.toSendDirectionData = data ?? Data()
            if let messageKey = messageKey, messageKey.count > 0 {
                self?.sendMessageIndex = messageKey
            }
            if progressBlock != nil || receiveBlock != nil, let messageKey = self?.sendMessageIndex, messageKey.count > 0 {
                let messageBody = ReceiveMessageTask()
                messageBody.messageKey = messageKey
                messageBody.didReceiveDataProgressBlock = progressBlock
                messageBody.didReceiveDataCompleteBlock = receiveBlock
                self?.receivedMessageDic[messageKey] = messageBody
            }
            
            self?.sendBodyMessage(socket: socket)
            return false
        }
        sendMessageQueue.addOperation(operation)
    }
    
    /// 发送文件data
    func sendFileData(socket: GCDAsyncSocket?, filePath: String, messageKey: String? = nil) {
        
        let operation = PPCustomAsyncOperation()
        operation.mainOperationDoBlock = { [weak self] (operation) -> Bool in
            self?.currentSendMessageTask = SendMessageTask()
            self?.currentSendMessageTask?.hasAllMessageDone = false
            self?.currentSendMessageTask?.messageType = .fileData
            self?.currentSendMessageTask?.readFilePath = filePath
            
            if let messageKey = messageKey, messageKey.count > 0 {
                self?.sendMessageIndex = messageKey
            }
            
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
            }, finishedAllTask: { [weak self] (isSuccess, msg) in
                /// 上个任务结束
                self?.sendMessageIndex = String.GenerateRandomString(length: 18)
                self?.currentSendMessageTask = nil
                (self?.sendMessageQueue.operations.first as? PPCustomAsyncOperation)?.finish()
            })
        case .fileData:
            self.currentSendMessageTask?.createSendFileBodyData { [weak self] (bodyData, totalBodyCount, index) in
                if index < totalBodyCount {
                    self?.sendCellBodyData(socket: socket, bodyData: bodyData, messageType: .fileData, totalBodyCount: totalBodyCount, index: index)
                }
            } finishedAllTask: { [weak self] in
                
                /// 上个任务结束
                self?.sendMessageIndex = String.GenerateRandomString(length: 18)
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
        let messageCode = sendMessageIndex
        if let sendData = currentSendMessageTask?.createSendCellBodyData(bodyData: bodyData, messageCode: messageCode, messageType: messageType, totalBodyCount: totalBodyCount, index: index) {
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
    
    func getTemporaryDirectory() -> String {
        let tmpPath = NSTemporaryDirectory()
        return tmpPath
    }
    
    func receiveRequestFileList(_ messageFormat: SocketMessageFormat) {
        
    }
    
    func receiveResponseFileList(_ messageFormat: SocketMessageFormat) {
        
    }
    
    func receiveRequestToDownloadFile(_ messageFormat: SocketMessageFormat) {
        
    }
    
    final func didReceiveData(data: Data) {
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
            self.receivedMessageDic[messageKey] = messageBody
        }
        messageBody?.totalLength = totalLength
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
            let fileName = messageKey + ".tmp"
            messageBody.filePath = getTemporaryDirectory() + "/" + fileName
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
//        messageBody.receivedOffset += UInt64(fileData.count)
        
        try? messageBody.fileHandle?.seek(toOffset: UInt64(messageBody.receivedOffset))
        
        messageBody.didReceiveDataProgressBlock?(messageBody)
        
        if (messageBody.bodyCount == messageBody.bodyIndex + 1) {
            print("数据所有包都合并完成")
            try? messageBody.fileHandle?.close()
            messageBody.didReceiveDataCompleteBlock?(messageBody)
            self.receivedMessageDic[messageKey] = nil
            
        } else {
            print("数据所有包未合并完成, 共\(messageBody.bodyCount)包, 当前第\(messageBody.bodyIndex)包, 继续等待")
        }
    }
    
    /// 处理收到的data数据
    final func doReceiveData(_ messageBody: ReceiveMessageTask, data: Data, parseIndex: Int) {
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
            
            if let didReceiveDataCompleteBlock = messageBody.didReceiveDataCompleteBlock {
                didReceiveDataCompleteBlock(messageBody)
                self.receivedMessageDic[messageKey] = nil
                return
            }
            
            
            // 这里可以封装给子类实现, 由子类去具体解析某些事件 ============================
            if let messageFormat = SocketMessageFormat.format(from: messageBody.directionData!, messageKey: messageKey) {
                switch messageFormat.action {
                case GSActions.requestFileList.getActionString():
                    self.receiveRequestFileList(messageFormat)
                    break
                case GSActions.responseFileList.getActionString():
                    self.receiveResponseFileList(messageFormat)
                    break
                case GSActions.requestToDownloadFile.getActionString():
                    self.receiveRequestToDownloadFile(messageFormat)
                    break
                default:
                    break
                }
            } else {
                
                // 可能是文件, 写入文件试试
                // TODO: 理论上, 客户端先请求文件, 然后服务端开始发送文件, 所以客户端是知道文件格式的, 这里可以根据文件格式来确定文件后缀名
                let fileName = messageKey + ".data"
                let filePath = getTemporaryDirectory() + "/" + fileName
                print("文件地址: \(filePath)")
                try? FileManager.default.removeItem(atPath: filePath)
                if !FileManager.default.fileExists(atPath: filePath) {
                    FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)
                }
                try? messageBody.directionData?.write(to: URL(fileURLWithPath: filePath))
            }
            // 这里可以封装给子类实现, 由子类去具体解析某些事件 ============================
            
            
            self.receivedMessageDic[messageKey] = nil
            
        } else {
            print("数据所有包未合并完成, 共\(messageBody.bodyCount)包, 当前第\(messageBody.bodyIndex)包, 继续等待")
        }
    }
}
