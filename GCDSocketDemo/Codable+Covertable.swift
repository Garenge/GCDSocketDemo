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

    func ht_convertToDict() -> [String: Any]? {

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
}
