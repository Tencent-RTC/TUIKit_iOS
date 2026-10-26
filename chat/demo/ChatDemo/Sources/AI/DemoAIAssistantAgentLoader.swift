import Foundation
import TUIChatKit

final class DemoAIAssistantAgentLoader: AIAssistantAgentLoader {
    static let shared = DemoAIAssistantAgentLoader()

    private static let agentsURLString = "https://md5.ltd/api/support/v1/agents"
    private static let connectTimeout: TimeInterval = 10
    private static let readTimeout: TimeInterval = 15

    private let session: URLSession

    private(set) var agents: [AIAssistantAgent] = []

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = Self.connectTimeout
        configuration.timeoutIntervalForResource = Self.readTimeout
        session = URLSession(configuration: configuration)
    }

    func displayName(forConversationID conversationID: String) -> String? {
        return agents.first { $0.conversationID == conversationID }?.displayName
    }

    func load(onResult: @escaping ([AIAssistantAgent]) -> Void) {
        guard let url = URL(string: Self.agentsURLString) else {
            DispatchQueue.main.async { onResult(self.agents) }
            return
        }
        var request = URLRequest(url: url)
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        session.dataTask(with: request) { [weak self] data, response, _ in
            let loadedAgents: [AIAssistantAgent]?
            if let data, let response = response as? HTTPURLResponse,
               200 ..< 300 ~= response.statusCode {
                loadedAgents = Self.parse(data)
            } else {
                loadedAgents = nil
            }
            DispatchQueue.main.async {
                guard let self else { return }
                if let loadedAgents { self.agents = loadedAgents }
                onResult(self.agents)
            }
        }.resume()
    }

    private static func parse(_ data: Data) -> [AIAssistantAgent] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let array = root["agents"] as? [[String: Any]] else {
            return []
        }
        var result: [AIAssistantAgent] = []
        for item in array {
            let imUserId = (item["im_user_id"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            if imUserId.isEmpty { continue }
            result.append(AIAssistantAgent(
                id: (item["id"] as? String ?? "").trimmingCharacters(in: .whitespaces),
                name: (item["name"] as? String ?? "").trimmingCharacters(in: .whitespaces),
                welcome: (item["welcome"] as? String ?? "").trimmingCharacters(in: .whitespaces),
                imUserId: imUserId,
                imNickname: (item["im_nickname"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            ))
        }
        return result
    }
}
