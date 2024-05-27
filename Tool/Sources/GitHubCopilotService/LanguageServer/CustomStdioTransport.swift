import Foundation
import JSONRPC
import os.log

public class CustomDataTransport: DataTransport {
    let nextTransport: DataTransport
    
    var onWriteRequest: (JSONRPCRequest<JSONValue>) -> Void = { _ in }
    
    init(nextTransport: DataTransport) {
        self.nextTransport = nextTransport
    }
    
    public func write(_ data: Data) {
        if let request = try? JSONDecoder().decode(JSONRPCRequest<JSONValue>.self, from: data) {
            onWriteRequest(request)
        }
        
        nextTransport.write(data)
    }
    
    public func setReaderHandler(_ handler: @escaping ReadHandler) {
        nextTransport.setReaderHandler(handler)
    }
    
    public func close() {
        nextTransport.close()
    }
}

