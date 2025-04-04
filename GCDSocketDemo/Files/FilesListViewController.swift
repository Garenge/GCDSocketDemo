//
//  FilesListViewController.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2024/12/22.
//

import UIKit
import PPToolKit
import PPSocket
import PPCustomAsyncOperation

class FilesListViewController: UIViewController {
    
    var client: PPClientSocketManager?
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return tableView
    }()
    
    let progressView = UIProgressView()
    
    var currentDirectory: String = ""
    
    /// 当前下载的文件
    var currentDownloadFile: PPFileModel?
    
    /// 当前下载任务的id
    var currentDownloadTaskId: String?
    
    var dataList: [PPFileModel] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "List"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "一键下载", style: .plain, target: self, action: #selector(doDownloadAllFiles(_:)))
        self.view.backgroundColor = .white
        
        self.setupSubviews()
        
        self.client?.sendQueryFileList(self.currentDirectory, finished: { fileList in
            guard let fileList = fileList else {
                print("获取文件列表失败")
                return
            }
            print("获取文件列表成功: \(fileList.count)")
            self.dataList.removeAll()
            self.dataList.append(contentsOf: fileList)
            self.tableView.reloadData()
        })
    }
    
    func setupSubviews() {
        
        progressView.isHidden = true
        self.view.addSubview(progressView)
        progressView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(self.view.snp_bottomMargin)
            make.height.equalTo(2)
        }
        
        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(self.view.snp_topMargin)
            make.bottom.equalTo(progressView.snp.top).offset(-2)
        }
    }
    
    let downloadQueue = PPCustomOperationQueue()
    
    @objc func doDownloadAllFiles(_ sender: UIBarButtonItem) {
        
        for fileModel in dataList {
            if fileModel.isFolder {
                continue
            }
            
            downloadQueue.addOperation(withIdentifier: fileModel.fileKey) { [weak self] operation in
                guard let self = self else {
                    return true
                }
                
                Thread.sleep(forTimeInterval: 1)
                let taskId = self.client?.sendDownloadRequest(filePath: fileModel.filePath, progressBlock: { messageTask in
                    print("下载进度: \(messageTask?.progress ?? 0)")
                }, receiveBlock: { messageTask in
                    print("下载完成: \(messageTask?.filePath ?? "")")
                    operation.finish()
                })
                return false
            }
            
            
        }
    }

}

extension FilesListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        
        let fileModel = dataList[indexPath.row]
        let fileSize = NSString.pp_fileSizeFormat(Int64(fileModel.fileSize))
        cell.imageView?.image = fileModel.isFolder ? UIImage(systemName: "folder") : UIImage(systemName: "document")
        if fileModel.isFolder {
            cell.textLabel?.text = "\(fileModel.fileName ?? "")"
        } else {
            cell.textLabel?.text = "\(fileModel.fileName ?? "")  \(fileSize)"
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let fileModel = dataList[indexPath.row]
        print("点击了第\(indexPath.row)行, 文件名: \(String(describing: fileModel.fileName))")
        
        if let currentDownloadTaskId = self.currentDownloadTaskId {
            self.client?.cancelRequest(currentDownloadTaskId, receiveBlock: { [weak self] messageTask in
                // 下载取消, 置空
                self?.currentDownloadFile = nil
                self?.currentDownloadTaskId = nil
                print("取消下载任务: \(currentDownloadTaskId)")
                self?.progressView.isHidden = true
                self?.progressView.setProgress(0, animated: true)
            })
            return
        }
        
        if fileModel.isFolder {
            let filesVC = FilesListViewController()
            filesVC.client = client
            filesVC.currentDirectory = (self.currentDirectory as NSString).appendingPathComponent(fileModel.fileName ?? "")
            self.navigationController?.pushViewController(filesVC, animated: true)
        } else {
            let alertVC = UIAlertController(title: "提示", message: "是否下载文件: \(fileModel.fileName ?? "")", preferredStyle: .alert)
            alertVC.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
            alertVC.addAction(UIAlertAction(title: "下载", style: .default, handler: { [weak self] _ in
                self?.currentDownloadFile = fileModel
                self?.progressView.isHidden = false
                self?.currentDownloadTaskId = self?.client?.sendDownloadRequest(filePath: fileModel.filePath, progressBlock: { messageTask in
                    self?.progressView.setProgress(Float(messageTask?.progress ?? 0), animated: true)
                }, receiveBlock: { messageTask in
                    // 下载完成, 置空
                    self?.currentDownloadFile = nil
                    self?.currentDownloadTaskId = nil
                    self?.progressView.isHidden = true
                    self?.progressView.setProgress(0, animated: false)
                })
            }))
            self.present(alertVC, animated: true, completion: nil)
        }
    }
}

