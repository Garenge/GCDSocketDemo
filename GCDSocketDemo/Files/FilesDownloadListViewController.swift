//
//  FilesDownloadListViewController.swift
//  GCDSocketDemo
//
//  Created by Codex on 2026/5/24.
//

import UIKit
import PPToolKit
import PPSocket
import PPCustomAsyncOperation

private enum FileDownloadStatus {
    case waiting
    case downloading
    case finished
    case failed
    
    var title: String {
        switch self {
        case .waiting:
            return "等待下载"
        case .downloading:
            return "下载中"
        case .finished:
            return "已完成"
        case .failed:
            return "下载失败"
        }
    }
}

private final class FileDownloadItem {
    let fileModel: PPFileModel
    var progress: Float = 0
    var status: FileDownloadStatus = .waiting
    var taskId: String?
    
    init(fileModel: PPFileModel) {
        self.fileModel = fileModel
    }
}

final class FilesDownloadListViewController: UIViewController {
    
    var client: PPClientSocketManager?
    var fileList: [PPFileModel] = []
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(FileDownloadCell.self, forCellReuseIdentifier: FileDownloadCell.reuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 88
        return tableView
    }()
    
    private lazy var downloadQueue: PPCustomOperationQueue = {
        let queue = PPCustomOperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    private var downloadItems: [FileDownloadItem] = []
    private var hasStartedDownload = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "下载列表"
        self.view.backgroundColor = .white
        self.setupSubviews()
        self.setupDownloadItems()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.startDownloadIfNeeded()
    }
    
    private func setupSubviews() {
        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupDownloadItems() {
        self.downloadItems = fileList.map { FileDownloadItem(fileModel: $0) }
        self.navigationItem.title = "下载列表(\(downloadItems.count))"
        self.tableView.reloadData()
        print("GCDSocketDemo/Files/FilesDownloadListViewController.swift#setupDownloadItems: prepared download items, count=\(downloadItems.count)")
    }
    
    private func startDownloadIfNeeded() {
        guard hasStartedDownload == false else {
            return
        }
        hasStartedDownload = true
        for index in downloadItems.indices {
            self.enqueueDownload(at: index)
        }
    }
    
    private func enqueueDownload(at index: Int) {
        let item = downloadItems[index]
        downloadQueue.addOperation(withIdentifier: item.fileModel.fileKey) { [weak self] operation in
            guard let self = self else {
                return true
            }
            
            self.updateItem(at: index, progress: 0, status: .downloading)
            let filePath = item.fileModel.filePath ?? ""
            print("GCDSocketDemo/Files/FilesDownloadListViewController.swift#enqueueDownload: download started, path=\(filePath)")
            item.taskId = self.client?.sendDownloadRequest(filePath: item.fileModel.filePath, progressBlock: { [weak self] messageTask in
                let progress = Float(messageTask?.progress ?? 0)
                self?.updateItem(at: index, progress: progress, status: .downloading)
            }, receiveBlock: { [weak self] messageTask in
                let finalProgress = messageTask == nil ? item.progress : 1
                let status: FileDownloadStatus = messageTask == nil ? .failed : .finished
                self?.updateItem(at: index, progress: finalProgress, status: status)
                print("GCDSocketDemo/Files/FilesDownloadListViewController.swift#enqueueDownload: download finished, path=\(filePath), status=\(status.title)")
                operation.finish()
            })
            return false
        }
    }
    
    private func updateItem(at index: Int, progress: Float, status: FileDownloadStatus) {
        DispatchQueue.main.async {
            guard self.downloadItems.indices.contains(index) else {
                return
            }
            let item = self.downloadItems[index]
            item.progress = max(0, min(progress, 1))
            item.status = status
            let indexPath = IndexPath(row: index, section: 0)
            if let cell = self.tableView.cellForRow(at: indexPath) as? FileDownloadCell {
                cell.configure(with: item)
            } else {
                self.tableView.reloadRows(at: [indexPath], with: .none)
            }
        }
    }
}

extension FilesDownloadListViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return downloadItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FileDownloadCell.reuseIdentifier, for: indexPath)
        guard let downloadCell = cell as? FileDownloadCell else {
            return cell
        }
        downloadCell.configure(with: downloadItems[indexPath.row])
        return downloadCell
    }
}

private final class FileDownloadCell: UITableViewCell {
    
    static let reuseIdentifier = "FileDownloadCell"
    
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let statusLabel = UILabel()
    private let percentLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.setupSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupSubviews()
    }
    
    func configure(with item: FileDownloadItem) {
        let fileModel = item.fileModel
        let fileSize = NSString.pp_fileSizeFormat(Int64(fileModel.fileSize))
        titleLabel.text = fileModel.fileName ?? "--"
        detailLabel.text = "\(fileSize)  \(fileModel.filePath ?? "")"
        statusLabel.text = item.status.title
        percentLabel.text = "\(Int(item.progress * 100))%"
        progressView.setProgress(item.progress, animated: true)
    }
    
    private func setupSubviews() {
        selectionStyle = .none
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.numberOfLines = 2
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 2
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabel
        percentLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        percentLabel.textAlignment = .right
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)
        contentView.addSubview(statusLabel)
        contentView.addSubview(percentLabel)
        contentView.addSubview(progressView)
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }
        
        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.left.right.equalTo(titleLabel)
        }
        
        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(detailLabel.snp.bottom).offset(8)
            make.left.equalTo(titleLabel)
            make.right.lessThanOrEqualTo(percentLabel.snp.left).offset(-8)
        }
        
        percentLabel.snp.makeConstraints { make in
            make.centerY.equalTo(statusLabel)
            make.right.equalTo(titleLabel)
            make.width.equalTo(52)
        }
        
        progressView.snp.makeConstraints { make in
            make.top.equalTo(statusLabel.snp.bottom).offset(8)
            make.left.right.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-12)
        }
    }
}
