import Foundation
import Moya
import Haneke
import Gloss
import Result

struct DiskRecordPlugin: Moya.PluginType {
    func didReceive(_ result: Result<Response, MoyaError>, target: TargetType) {
        _ = result.analysis(ifSuccess: { (response) -> Result<Response, MoyaError> in
            
            if let json = Haneke.JSON.convertFromData(response.data) {
                storeJSON(json, target: target)
            }
            
            return result
            
        }) { (error) -> Result<Response, MoyaError> in
            return result
        }
    }
    
    private func storeJSON(_ json: Haneke.JSON, target: TargetType) {
        
        print(json)
        
        let cache = Shared.JSONCache
        
        cache.set(value: json, key: target.cacheKey)
    }
}

extension TargetType {
    var cacheKey: String {
        return self.path
    }
}
