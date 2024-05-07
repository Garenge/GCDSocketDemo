//
//  Server.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2023/5/17.
//

import Foundation

class Server: NSObject {

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

extension Server {
    // 发送消息
    func sendMessage() {

        let string = "Server" + "-\(count)"
        let data = string.data(using: .utf8)
        self.clientSocket?.write(data, withTimeout: -1, tag: 10086)
        count += 1
    }
}

extension Server: GCDAsyncSocketDelegate {

    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("Server 已连接 \(host):\(port)")
        self.clientSocket?.readData(withTimeout: -1, tag: 10086)
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
        print("Server 已发送消息")
    }
}
