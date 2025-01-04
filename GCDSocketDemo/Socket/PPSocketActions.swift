//
//  PPSocketActions.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2024/12/4.
//

import Foundation

/// 长度小于18的字符串, 在前面补0, 补齐18
enum PPSocketActions: String {
    
    /// 请求文件列表
    case requestFileList
    /// 响应文件列表
    case responseFileList
    
    /// 请求下载文件
    case requestToDownloadFile
    /// 响应下载文件
    case responseToDownloadFile
    
    /// 取消任务
    case requestToCancelTask
    /// 响应取消任务
    case responseToCancelTask
    
    /// 获取动作字符串, 长度不足18的在前面补0
    func getActionString() -> String {
        let actionString = self.rawValue
        let actionLength = actionString.count
        if actionLength < 18 {
            let zeroString = String(repeating: "0", count: 18 - actionLength)
            return zeroString + actionString
        }
        return actionString
    }
}
