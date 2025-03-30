//
//  FileManager+Ex.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2025/3/30.
//

import Foundation

extension FileManager {
    
    func getDocumentDirectory() -> String {
        let docuPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory,
                                                            .userDomainMask, true)
        let docuPath = docuPaths[0]
        // print(docuPath)
        return docuPath
    }
    
}
