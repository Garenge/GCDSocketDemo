//
//  ViewController.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2023/5/17.
//

import UIKit
import SnapKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        self.setupSubviews()
    }

    func setupSubviews() {
        let connectButton = UIButton(type: .system)
        connectButton.setTitle("Auto Connect(Server & Client)", for: .normal)
        connectButton.addTarget(self, action: #selector(connectButtonClickedAction(_:)), for: .touchUpInside)
        self.view.addSubview(connectButton)

        connectButton.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
        }
    }

    let server = Server()
    let client = Client()
    @objc func connectButtonClickedAction(_ sender: UIButton) {

        server.accept()

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.client.connect()
        }
    }

    @IBAction func send1Action(_ sender: Any) {
        server.sendMessage()
    }

    @IBAction func send2Action(_ sender: Any) {
        client.sendMessage()
    }

}

