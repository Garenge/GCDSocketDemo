//
//  ReceiveMessageTask.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2024/12/1.
//

import UIKit

/// 收消息的模型
class ReceiveMessageTask: NSObject {
    /// 每个任务有独一无二的key
    var messageKey: String? {
        didSet {
            if messageKey != nil {
                initialReceiveSpeedTimer()
            }
        }
    }
    /// 数据分包的总包数
    var bodyCount: Int = 1
    /// 数据分包的当前包数
    var bodyIndex: Int = 0
    /// 此次传输, 总的数据长度
    var totalLength: UInt64 = 0
    /// 已接收数据的长度
    var receivedOffset: UInt64 = 0 {
        didSet {
            if (receivedOffset == totalLength) {
                self.finishReceiveTask()
            }
        }
    }
    
    /// 数据类型
    var messageType: TransMessageType = .directionData
    
    /// 文件才有, 文件路径
    var filePath: String?
    /// 文件才有, 文件句柄
    var fileHandle: FileHandle?
    
    /// 如果是数据流, 直接拼接
    var directionData: Data?
    
    /// 网速回调
    public var toReceiveTransSpeedChangedBlock: ((_ speed: UInt64) -> ())?
    /// 网速
    public var toReceiveTransSpeed: UInt64 = 0 {
        didSet {
            print("当前接收数据网速: \(toReceiveTransSpeed)B/s")
            toReceiveTransSpeedChangedBlock?(toReceiveTransSpeed)
        }
    }
    /// 计算网速
    private var toReceiveSpeedTimer: Timer?
    /// 一秒钟计算一次增值就好了
    private var toReceiveLastSpeedValue: UInt64 = 0
    private func initialReceiveSpeedTimer() {
        toReceiveSpeedTimer?.invalidate()
        
        // 放到主线程
        toReceiveSpeedTimer = Timer(timeInterval: 1, repeats: true, block: {[weak self] _ in
            guard let self = self else {
                return
            }
            self.calculateReceiveSpeed()
        })
        RunLoop.current.add(toReceiveSpeedTimer!, forMode: .default)
    }
    
    private func calculateReceiveSpeed() {
        self.toReceiveTransSpeed = self.receivedOffset - self.toReceiveLastSpeedValue
        self.toReceiveLastSpeedValue = self.receivedOffset
    }
    
    private func finishReceiveTask() {
        self.calculateReceiveSpeed()
        toReceiveSpeedTimer?.invalidate()
        self.calculateReceiveSpeed()
    }
}
