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
        
        print("GCDSocketDemo/Files/FilesListViewController.swift#viewDidLoad: query file list started, directory=\(currentDirectory)")
        self.client?.sendQueryFileList(self.currentDirectory, finished: { fileList in
            guard let fileList = fileList else {
                print("GCDSocketDemo/Files/FilesListViewController.swift#viewDidLoad: query file list failed, directory=\(self.currentDirectory)")
                return
            }
            self.logFileList(fileList, directory: self.currentDirectory, scene: "viewDidLoad")
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
        sender.isEnabled = false
        self.collectDownloadFiles(dataList) { [weak self, weak sender] fileList in
            guard let self = self else {
                return
            }
            sender?.isEnabled = true
            print("GCDSocketDemo/Files/FilesListViewController.swift#doDownloadAllFiles: collect download files finished, count=\(fileList.count)")
            let downloadVC = FilesDownloadListViewController()
            downloadVC.client = self.client
            downloadVC.fileList = fileList
            self.navigationController?.pushViewController(downloadVC, animated: true)
        }
    }
    
    public func collectDownloadFiles(_ toDownloadFileList: [PPFileModel], finished: @escaping ([PPFileModel]) -> Void) {
        var resultList: [PPFileModel] = []
        var pendingFolderCount = 0
        
        func finishIfNeeded() {
            if pendingFolderCount == 0 {
                finished(resultList)
            }
        }
        
        for fileModel in toDownloadFileList {
            if shouldSkipDownload(fileModel) {
                let fileName = fileModel.fileName ?? ""
                print("GCDSocketDemo/Files/FilesListViewController.swift#collectDownloadFiles: skip hidden item, name=\(fileName)")
                continue
            }
            
            if fileModel.isFolder {
                let folderPath = fileModel.filePath ?? ""
                pendingFolderCount += 1
                print("GCDSocketDemo/Files/FilesListViewController.swift#collectDownloadFiles: query folder started, path=\(folderPath)")
                self.client?.sendQueryFileList(fileModel.filePath, finished: { fileList in
                    guard let fileList = fileList else {
                        print("GCDSocketDemo/Files/FilesListViewController.swift#collectDownloadFiles: query folder failed, path=\(folderPath)")
                        pendingFolderCount -= 1
                        finishIfNeeded()
                        return
                    }
                    self.logFileList(fileList, directory: folderPath, scene: "collectDownloadFiles")
                    self.collectDownloadFiles(fileList) { childFileList in
                        resultList.append(contentsOf: childFileList)
                        pendingFolderCount -= 1
                        finishIfNeeded()
                    }
                })
            } else {
                resultList.append(fileModel)
            }
        }
        finishIfNeeded()
    }
    
    private func shouldSkipDownload(_ fileModel: PPFileModel) -> Bool {
        guard let fileName = fileModel.fileName, fileName.count > 0 else {
            return false
        }
        return fileName.hasPrefix(".")
    }
    
    private func logFileList(_ fileList: [PPFileModel], directory: String, scene: String) {
        let folderCount = fileList.filter { $0.isFolder }.count
        let fileCount = fileList.count - folderCount
        let previewNames = fileList.prefix(5).map { fileModel in
            let type = fileModel.isFolder ? "folder" : "file"
            return "\(type):\(fileModel.fileName ?? "")"
        }.joined(separator: ", ")
        print("GCDSocketDemo/Files/FilesListViewController.swift#\(scene): query file list succeeded, directory=\(directory), total=\(fileList.count), folders=\(folderCount), files=\(fileCount), preview=[\(previewNames)]")
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
