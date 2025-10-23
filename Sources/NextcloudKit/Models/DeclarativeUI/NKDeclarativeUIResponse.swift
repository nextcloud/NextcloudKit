//
//  NKDeclarativeUIResponse.swift
//  NextcloudKit
//
//  Created by Milen Pivchev on 24.09.25.
//


public struct NKDeclarativeUIResponse: Codable {
    let version: Double
    let root: RootContainer
}

public struct RootContainer: Codable {
    let orientation: String
    let rows: [Row]
}

public struct Row: Codable {
    let children: [Child]
}

public struct Child: Codable {
    let element: String
    let text: String?
    let url: String?
}
