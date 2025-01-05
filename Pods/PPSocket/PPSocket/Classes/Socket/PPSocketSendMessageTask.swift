//
//  MessageManager.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2024/11/21.
//

import UIKit

enum PPSocketTransMessageType: Int {
    /// 数据直传
    case directionData = 0
    /// 大文件, 分包传
    case fileData = 1
}

class PPSocketSendMessageTask: NSObject {
    
    public var messageType: PPSocketTransMessageType = .directionData
    
    /// 标记当前任务的序号, 可以理解为唯一标识
    var sendMessageIndex = String.GenerateRandomString(length: 18) {
        didSet {
            print("====")
        }
    }
    
    /// 如果是直接传输数据, 记录总data
    var toSendDirectionData: Data? {
        didSet {
            if let data = toSendDirectionData {
                // 18 + 2 + 8 + 8 + 8 + 16 (固定开头)  data
                // 所有的数据分包, 每个包由于有固定的开头20+8+8+8+16个字节, 所以每个包最多放maxBodyLength - 20 - 8 - 8 - 8 - 16个长度
                toSendTotalSize = UInt64(data.count)
                let cellBodyLength = UInt64(maxBodyLength - prefixLength)
                toSendBodyTotalCount = Int((toSendTotalSize + cellBodyLength - 1) / cellBodyLength)
            } else {
                print("数据不存在")
            }
            
            DispatchQueue.main.async {
                self.initialSendSpeedTimer()
            }
        }
    }
    
    /// 读取文件的地址, 设置地址之后, 自动读取数据, 准备分包操作
    var readFilePath: String? {
        didSet {
            if let filePath = readFilePath {
                
                // 由于文件不能完全加载成data, 容易内存爆炸, 所以文件改成流式获取
                if FileManager.default.fileExists(atPath: filePath),
                   let attributes = try? FileManager.default.attributesOfItem(atPath: filePath),
                   let size = attributes[.size] as? NSNumber,
                   size.int64Value > 0 {
                    
                    readFileHandle = FileHandle(forReadingAtPath: filePath)
                    
                    toSendTotalSize = UInt64(size.int64Value)
                    let cellBodyLength = UInt64(maxBodyLength - prefixLength)
                    toSendBodyTotalCount = Int((toSendTotalSize + cellBodyLength - 1) / cellBodyLength)
                } else {
                    print("文件不存在")
                }
                
                DispatchQueue.main.async {
                    self.initialSendSpeedTimer()
                }
            }
        }
    }
    /// 读取文件的句柄, 用于读取文件数据
    private var readFileHandle: FileHandle?
    /// 读取文件的偏移量, 用于读取文件数据
    private var readedOffset: UInt64 = 0
    /// 消息是否全部处理完成
    var hasAllMessageDone: Bool = true
    /// 总的要发送的数据的大小
    public var toSendTotalSize: UInt64 = 0
    /// 分包的总包数
    private var toSendBodyTotalCount = 0
    /// 当前分包的序号
    private var toSendBodyCurrentIndex = 0
    
    /// 网速回调
    public var toSendTransSpeedChangedBlock: ((_ speed: UInt64) -> ())?
    /// 网速
    public var toSendTransSpeed: UInt64 = 0 {
        didSet {
            print("当前发送数据网速: \(toSendTransSpeed)B/s")
            toSendTransSpeedChangedBlock?(toSendTransSpeed)
        }
    }
    /// 计算网速
    private var toSendSpeedTimer: Timer?
    /// 一秒钟计算一次增值就好了
    private var toSendLastSpeedValue: UInt64 = 0
    private func initialSendSpeedTimer() {
        toSendSpeedTimer?.invalidate()
        
        // 放到主线程
        toSendSpeedTimer = Timer(timeInterval: 1, repeats: true, block: {[weak self] _ in
            guard let self = self else {
                return
            }
            self.calculateSendSpeed()
        })
        RunLoop.current.add(toSendSpeedTimer!, forMode: .default)
    }
    
    private func calculateSendSpeed() {
        self.toSendTransSpeed = self.readedOffset - self.toSendLastSpeedValue
        self.toSendLastSpeedValue = self.readedOffset
    }
    
    private func releaseSpeedCalculate() {
        self.calculateSendSpeed()
        toSendSpeedTimer?.invalidate()
        toSendSpeedTimer = nil
    }
    
    var prefixLength = 20 + 8 + 8 + 8 + 16
    
    // 18, 事件名称, 无业务意义, 仅用作判断相同消息
    // 2, 数据类型, 00: 默认, json, 01: 文件
    // 8个长度, 分包, 包的个数 // 一个包, 放 maxBodyLength - prefixLength
    // 8个长度, 分包, 包的序号
    // 8个长度, 分包, 包的长度
    // 16个长度, 转换成字符串, 表示此次传输的数据长度
    // 数据
    let maxBodyLength = 12 * 1024
    
    func createJsonBodyData(cellMessageBlock:((_ bodyData: Data, _ totalBodyCount: Int, _ index: Int) -> ())?, finishedAllTask: ((_ isSuccess: Bool, _ msg: String?) -> ())?) {
        
        guard let toSendDirectionData = toSendDirectionData else {
            finishedAllTask?(false, "数据不存在")
            return
        }
        if readedOffset >= toSendTotalSize {
            finishedAllTask?(false, "数据已经读取完了")
            return
        }
        
        // maxReadedCount表示这一次最多还可以读多少数据
        let maxReadedCount = maxBodyLength - prefixLength
        
        var bodyData = Data()
        
        if maxReadedCount >= toSendTotalSize - readedOffset {
            // 说明这一次可以把数据全取完了
            bodyData.append(toSendDirectionData.subdata(in: Int(readedOffset)..<Int(toSendTotalSize)))
            readedOffset = toSendTotalSize
            hasAllMessageDone = true
            
        } else {
            // 只能取一部分
            bodyData.append(toSendDirectionData.subdata(in: Int(readedOffset)..<(Int(readedOffset) + maxReadedCount)))
            readedOffset += UInt64(maxReadedCount)
        }
        
        cellMessageBlock?(bodyData, toSendBodyTotalCount, toSendBodyCurrentIndex)
        toSendBodyCurrentIndex += 1
        if (hasAllMessageDone) {
            calculateSendSpeed()
            finishedAllTask?(true, nil)
            releaseSpeedCalculate()
        }
    }
    
    /// 由于文件量大, 需要考虑到内存, 所以我们拆分文件, 控制在随需随取
    func createSendFileBodyData(cellMessageBlock:((_ bodyData: Data, _ totalBodyCount: Int, _ index: Int) -> ())?, finishedAllTask: (() -> ())?, failureBlock:((_ msg: String) -> ())?) {
        
        if (nil == readFileHandle) {
            failureBlock?("文件句柄不存在")
            return
        }
        if readedOffset >= toSendTotalSize {
            failureBlock?("文件已经读取完了")
            return
        }
        // maxReadedCount表示这一次最多还可以读多少数据
        let maxReadedCount = maxBodyLength - prefixLength
        
        var bodyData = Data()
        
        if maxReadedCount >= toSendTotalSize - readedOffset {
            // 说明这一次可以把文件全取完了
            if toSendTotalSize > 0, let data = readFileHandle?.readData(ofLength: Int(toSendTotalSize - readedOffset)) {
                bodyData.append(data)
                readedOffset = toSendTotalSize
//                readFileHandle?.closeFile()
                hasAllMessageDone = true
            }
        } else {
            // 文件只能取一部分
            if let data = readFileHandle?.readData(ofLength: maxReadedCount) {
                bodyData.append(data)
                readedOffset += UInt64(maxReadedCount)
//                try? readFileHandle?.seek(toOffset: readedOffset)
            }
        }
        do {
            try readFileHandle?.seek(toOffset: readedOffset)
        } catch {
            print("======== sendFile error: \(error)")
        }
        
        cellMessageBlock?(bodyData, toSendBodyTotalCount, toSendBodyCurrentIndex)
        toSendBodyCurrentIndex += 1
        if (hasAllMessageDone) {
            try? readFileHandle?.close()
            calculateSendSpeed()
            finishedAllTask?()
            releaseSpeedCalculate()
        }
    }
    
    /// 创建最终发送的数据包体
    func createSendCellBodyData(bodyData: Data, messageCode: String, messageType: PPSocketTransMessageType, totalBodyCount: Int, index: Int) -> Data {
        var sendData = Data()
        
        //18个长度, 区分分包数据
        let oneKey = messageCode.count == 18 ? messageCode :  "\(String(format: "%0\(18 - messageCode.count)d", 0))\(messageCode)"
        sendData.append(oneKey.data(using: .utf8)!)
        
        //2个长度, 数据类型
        let type = String(format: "%02d", messageType.rawValue)
        sendData.append(type.data(using: .utf8)!)
        
        //8个长度, 包的个数
        let bodyCount = String(format: "%08lld", totalBodyCount)
        sendData.append(bodyCount.data(using: .utf8)!)
        //8个长度, 包的序号
        let bodyIndex = String(format: "%08lld", index)
        sendData.append(bodyIndex.data(using: .utf8)!)
        // 8个长度 这个包有多长
        let bodyLength = String(format: "%08lld", bodyData.count + prefixLength)
        sendData.append(bodyLength.data(using: .utf8)!)
        
        let totalLength = String(format: "%016lld", toSendTotalSize)
        sendData.append(totalLength.data(using: .utf8)!)
        
        sendData.append(bodyData)
        
//        print("0数据共\(totalBodyCount)包, 当前第\(index)包, 此包实际数据大小: \(bodyData.count)")
//        print("0数据共\(totalBodyCount)包, 当前第\(index)包, 此包发送体大小: \(sendData.count)")
        
        return sendData
    }
}
