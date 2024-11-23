//
//  MessageManager.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2024/11/21.
//

import UIKit

class MessageManager: NSObject {
    
    enum MessageType: Int {
        case json = 0
        case file = 1
    }
    
    // 18, 事件名称, 无业务意义, 仅用作判断相同消息
    // 2, 数据类型, 00: 默认, json, 01: 文件
    
    // 8个长度, 分包, 包的个数 // 一个包, 最大 maxBodyLength, 其中还有开头的 20+8+8
    // 8个长度, 分包, 包的序号
    // 8个长度, 转换成字符串, 表示接下来的数据长度
    // 数据
    static let maxBodyLength = 12 * 1024
    
    static func makeJsonBodyData(data: Data, cellMessageBlock:((_ bodyData: Data, _ totalBodyCount: Int, _ index: Int) -> ())?) {
        // 18 + 2 + 8 + 8 (固定开头)  8  data
        // 所有的数据分包, 每个包由于有固定的开头20+8+8个字节, 所以每个包最多放maxBodyLength - 20 - 8 - 8个长度
        let preFixLength = 20 + 8 + 8
        // 整理整个数据, 发现前面数据基本都是可控的, 整块数据可以分成两段, 8 + data
        let preData = { () -> Data in
            var bodyData = Data()
            //8个长度, 转换成字符串, 表示接下来的json长度
            let length = String(format: "%08d", data.count)
            bodyData.append(length.data(using: .utf8)!)
            //数据体
            bodyData.append(data)
            return bodyData
        }()
        let totalBodySize = preData.count
        let cellBodyLength = maxBodyLength - preFixLength
        let totalBodyCount = (totalBodySize + cellBodyLength - 1) / cellBodyLength
        
        var sepIndex = 0
        var cellBodyIndex = 0
        while sepIndex < totalBodySize {
            var bodyData = Data()
            if sepIndex + maxBodyLength - preFixLength < preData.count {
                // 这一次放心取, 数据量很大
                bodyData.append(preData.subdata(in: sepIndex..<(sepIndex + maxBodyLength - preFixLength)))
                sepIndex += maxBodyLength - preFixLength
            } else {
                bodyData.append(preData.subdata(in: sepIndex..<preData.count))
                sepIndex = preData.count
            }
            
            cellMessageBlock?(bodyData, totalBodyCount, cellBodyIndex)
            cellBodyIndex += 1
        }
    }
    
    static func makeFileBodyData(filePath: String, cellMessageBlock:((_ bodyData: Data, _ totalBodyCount: Int, _ index: Int) -> ())?, failureBlock:((_ msg: String) -> ())?) {
        let preFixLength = 20 + 8 + 8
        
        var fileSize = 0
        
        // 由于文件不能完全加载成data, 容易内存爆炸, 所以文件改成流式获取
        if FileManager.default.fileExists(atPath: filePath),
           let attributes = try? FileManager.default.attributesOfItem(atPath: filePath),
           let size = attributes[.size] as? NSNumber,
           size.int64Value > 0 {
            fileSize = size.intValue
        }
        if fileSize == 0 {
            print("文件不存在")
            failureBlock?("文件不存在")
            return
        }
        
        // 18 + 2 + 8 + 8 (固定开头)  8  data
        // 所有的数据分包, 每个包由于有固定的开头20+8+8个字节, 所以每个包最多放maxBodyLength - 20 - 8 - 8个长度
        let totalBodySize = 8 + fileSize
        let cellBodyLength = maxBodyLength - preFixLength
        let totalBodyCount = (totalBodySize + cellBodyLength - 1) / cellBodyLength

        // 整理整个数据, 发现前面数据基本都是可控的, 整块数据可以分成两段, (20 8 8   8  json  8)  fileData
        let preData = { () -> Data in
            var bodyData = Data()
            //8个长度, 转换成字符串, 表示接下来的data长度
            let fileLength = String(format: "%08d", fileSize)
            bodyData.append(fileLength.data(using: .utf8)!)
            return bodyData
        }()
        // 创建一个下标, 从左往右按顺序截取data, 发送数据
        
        var sepIndex = 0
        var cellBodyIndex = 0
        
        guard let fileHandler = FileHandle(forReadingAtPath: filePath) else {
            print("创建文件句柄失败")
            return
        }
        try? fileHandler.seek(toOffset: 0)
        
        while sepIndex < totalBodySize {
            // 从上一个下标开始, 取长度为 maxBodyLength - preFixLength 的流
            if sepIndex + maxBodyLength - preFixLength < preData.count {
                // 还没取到file
                let bodyData = preData.subdata(in: sepIndex..<(sepIndex + maxBodyLength - preFixLength))
                cellMessageBlock?(bodyData, totalBodyCount, cellBodyIndex)
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
                        let data = fileHandler.readData(ofLength: totalBodySize - sepIndex)
                        bodyData.append(data)
                    }
                    sepIndex = totalBodySize
                } else {
                    // 文件只能取一部分
                    let data = fileHandler.readData(ofLength: fileReadCount)
                    bodyData.append(data)
                    try? fileHandler.seek(toOffset: UInt64(sepIndex + fileReadCount - preData.count))
                    sepIndex += fileReadCount
                }
                
                cellMessageBlock?(bodyData, totalBodyCount, cellBodyIndex)
                cellBodyIndex += 1
            }
            
        }
        fileHandler.closeFile()
    }
    
    static func makeCellBodyData(bodyData: Data, messageCode: String, messageType: MessageType, totalBodyCount: Int, index: Int) -> Data {
        var sendData = Data()
        
        //20个长度, 区分分包数据
        let oneKey = messageCode.count == 18 ? messageCode :  "\(String(format: "%0\(18 - messageCode.count)d", 0))\(messageCode)"
        sendData.append(oneKey.data(using: .utf8)!)
        
        //2个长度, 数据类型
        let type = String(format: "%02d", messageType.rawValue)
        sendData.append(type.data(using: .utf8)!)
        
        //8个长度, 包的个数 // 一个包, 最大 8k = 8 * 1024, 其中还有开头的 2+8+8
        let bodyCount = String(format: "%08lld", totalBodyCount)
        sendData.append(bodyCount.data(using: .utf8)!)
        //8个长度, 包的序号
        let bodyIndex = String(format: "%08lld", index)
        sendData.append(bodyIndex.data(using: .utf8)!)
        
        print("0数据共\(totalBodyCount)包, 当前第\(index)包, 此包大小: \(bodyData.count)")
        sendData.append(bodyData)
        
        return sendData
    }
    
}
