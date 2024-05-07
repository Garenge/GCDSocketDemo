//
//  Client.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2023/5/17.
//

import Foundation

class Client: NSObject {

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
        self.socket.readData(withTimeout: -1, tag: 10086)
    }

    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        print("Client 已发送消息")
    }
}
