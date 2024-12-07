//
//  Codable+Covertable.swift
//  Exercise
//
//  Created by pengpeng on 2024/2/22.
//

import Foundation

protocol Convertable: Codable {
}

extension Convertable {

    func convertToDict() -> [String: Any]? {

        var var_dict: [String: Any]?

        do {
            print("init")
            let var_encoder = JSONEncoder()

            let var_data = try var_encoder.encode(self)
            print("model convert to data")

            var_dict = try JSONSerialization.jsonObject(with: var_data, options: .allowFragments) as? [String: Any]

        } catch {
            print(error)
        }

        return var_dict
    }
    
    func convertToJsonData() -> Data? {
        do {
            let encoder = JSONEncoder()
            return try encoder.encode(self)
        } catch {
            print(error)
        }
        return nil
    }
}

extension Array where Element: Convertable {
    func convertToDictArray() -> [[String: Any]]? {
        return self.compactMap { $0.convertToDict() }
    }
    
    func convertToJsonData() -> Data? {
        do {
            let encoder = JSONEncoder()
            return try encoder.encode(self)
        } catch {
            print(error)
        }
        return nil
    }
}
