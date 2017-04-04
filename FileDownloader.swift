import Foundation
import RxSwift
import Alamofire

public enum DownloadState: Comparable {
    case idle
    case started    (task: DownloadTask)
    case paused     (task: DownloadTask, resumeData: Data)
    case downloading(task: DownloadTask, progress: Progress)
    case finished   (task: DownloadTask, destinationURL: URL)
    case error      (task: DownloadTask, error: Error)

    public static func ==(lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.started, .started):
            return true
        case (.paused, .paused):
            return true
        case (.downloading, .downloading):
            return true
        case (.finished, .finished):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }

    public static func <(lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch rhs {
        case .idle:
            return false
        case .started:
            return [.idle].contains(lhs)
        case .paused:
            switch lhs {
                case .idle, .started: return true
                default: return false
            }
        case .downloading:
            switch lhs {
            case .idle, .started, .paused: return true
            default: return false
            }
        case .finished:
            switch lhs {
            case .idle, .started, .paused, .downloading: return true
            default: return false
            }
        case .error:
            switch lhs {
            case .idle, .started, .paused, .downloading, .finished: return true
            default: return false
            }
        }
    }
    
}



public enum DownloadError: Error {
    case wrongRemoteUrl
}

public class FileDownloader {
    
    private var tasks: [DownloadTask: Observable<DownloadState>] = [:]
    private let storage = JSONStorage<DownloadTask>(type: .documents, document: "download_tasks")
    
    init(resume: Bool) {
        if resume {
            resumeOldTasks()
        }
    }
    
    public func download(uid: String, url: String, destination: String, useBackground: Bool = true, useWifiOnly: Bool = false) -> Observable<DownloadState> {
        let task = DownloadTask(uid: uid,
                                remoteUrl: url,
                                destination: destination,
                                useBackground: useBackground,
                                useWifiOnly: useWifiOnly,
                                resumeData: nil)
        
        return startTask(downloadTask: task)
    }
    
    public func downloadStatus(uid: String, destination: String) -> Observable<DownloadState> {
        let taskPlaceholder = DownloadTask(uid: uid, destination: destination)
        
        if let observable = tasks[taskPlaceholder] {
            return observable
        }
        
        if let fileUrl = downloadedFileUrl(task: taskPlaceholder) {
            return Observable.just(.finished(task: taskPlaceholder, destinationURL: fileUrl))
        }
        
        return Observable.just(.idle)
    }
    
    private func startTask(downloadTask: DownloadTask) -> Observable<DownloadState> {
        let observable: Observable<DownloadState> = Observable.create({ (observer) -> Disposable in
            
            observer.onNext(.idle)
            
            let localFileUrl = self.writeUrlFrom(destination: downloadTask.destination)
            
            let destination: DownloadRequest.DownloadFileDestination = { _, _ in
                return (localFileUrl, [.removePreviousFile, .createIntermediateDirectories])
            }
            
            observer.onNext(.started(task: downloadTask))
            
            guard let url = URL(string: downloadTask.remoteUrl) else {
                observer.onNext(.error(task: downloadTask, error: DownloadError.wrongRemoteUrl))
                observer.onError(DownloadError.wrongRemoteUrl)
                return Disposables.create {}
            }
            
            var downloadRequest: DownloadRequest
            
            if let resumeData = downloadTask.resumeData {
                downloadRequest = Alamofire.download(resumingWith: resumeData)
            } else {
                downloadRequest = Alamofire.download(url, to: destination)
            }

            downloadRequest = downloadRequest
            .response { [weak self] response in
                
                if let resumeData = response.resumeData {
                    observer.onNext(.paused(task: downloadTask, resumeData: resumeData))
                    return
                }
                
                if let error = response.error {
                    observer.onNext(.error(task: downloadTask, error: error))
                    return
                }
                
                if let filePath = response.destinationURL {
                    observer.onNext(.finished(task: downloadTask, destinationURL: filePath))
                }
                
                self?.tasks[downloadTask] = nil
                
                observer.onCompleted()
            }
            .downloadProgress(closure: { (progress) in
                observer.onNext(.downloading(task: downloadTask, progress: progress))
            })
            
            return Disposables.create {
                downloadRequest.cancel()
            }
            
        }).share()
        
        self.tasks[downloadTask] = observable
        
        return observable
    }
    
    private func downloadedFileUrl(task: DownloadTask) -> URL? {
        let localFileUrl = self.writeUrlFrom(destination: task.destination)
        
        if FileManager.default.fileExists(atPath: localFileUrl.path) {
            return localFileUrl
        }
        
        return nil
    }
    
    private func writeUrlFrom(destination: String) -> URL {
        var localFileUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        localFileUrl.appendPathComponent(destination)
        
        return localFileUrl
    }
    
    private func resumeOldTasks() {
        guard let tasks = try? storage.read() else {
            return
        }
        
        for task in tasks {
            _ = startTask(downloadTask: task)
        }
    }
}
