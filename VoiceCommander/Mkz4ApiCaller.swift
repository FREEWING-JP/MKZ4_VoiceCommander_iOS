//
//  Mkz4Api.swift
//  VoiceCommander
//
//  Copyright © 2017年 Cerevo Inc. All rights reserved.
//

import Foundation

class Mkz4ApiCaller {

    static let sharedInstance = Mkz4ApiCaller()

    let hostURL = "http://192.168.4.1:8080"
    var session: URLSession
    var currentTask: URLSessionDataTask?

    enum Command: String {
        case None = ""
        case Stop = "stop"
        case Forward = "forward"
        case Back = "back"
        case Left = "left"
        case Right = "right"
        case LeftForward = "leftforward"
        case RightForward = "rightforward"
        case LeftBack = "leftback"
        case RightBack = "rightback"
    }

    init() {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 1
        config.httpShouldUsePipelining = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 1
        session = URLSession(configuration: config)
    }

    func sendCommand(command: Command) {
        get(url: URL(string: "\(hostURL)/\(command.rawValue)")!)
    }

    func get(url: URL) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            if (error != nil) {
                print("error: \(error)")
                return
            }

            guard let data = data else {
                print("empty data")
                return
            }

            print(String.init(data: data, encoding: .utf8) ?? "Failed to decode response.")
        })
        if let t = currentTask {
            t.cancel()
        }
        currentTask = task
        task.resume()
    }

    func post(url: URL) {
        if let t = currentTask {
            t.cancel()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // set the request-body(JSON)
        let params: [String: Any] = [:]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: params, options: [])
        } catch {
            return
        }

        // use NSURLSessionDataTask
        let task = session.dataTask(with: request, completionHandler: {data, response, error in
            if let error = error {
                print("error: \(error)")
                return
            }

            guard let data = data else {
                print("empty data")
                return
            }

            print(String.init(data: data, encoding: .utf8) ?? "Failed to decode response.")
        })
        if let t = currentTask {
            t.cancel()
        }
        currentTask = task
        task.resume()
    }
}
