//
//  ServerInfo.swift
//  eduVPN
//

// Models the data extracted from <server_base_url>/info.json

struct ServerInfo: Decodable {

    typealias BaseURL = URL
    typealias OAuthEndpoint = URL

    var authorizationEndpoint: OAuthEndpoint
    var tokenEndpoint: OAuthEndpoint
    var apiBaseUrl: BaseURL
}

extension ServerInfo {

    enum ServerInfoKeys: String, CodingKey {
        case api
        case apiInfo = "http://eduvpn.org/api#2"
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case apiBaseUrl = "api_base_uri"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ServerInfoKeys.self)
        
        let apiContainer = try container.nestedContainer(keyedBy: ServerInfoKeys.self, forKey: .api)
        let apiInfoContainer = try apiContainer.nestedContainer(keyedBy: ServerInfoKeys.self, forKey: .apiInfo)
        
        let authorizationEndpoint = try apiInfoContainer.decode(URL.self, forKey: .authorizationEndpoint)
        let tokenEndpoint = try apiInfoContainer.decode(URL.self, forKey: .tokenEndpoint)
        let apiBaseUrl = try apiInfoContainer.decode(URL.self, forKey: .apiBaseUrl)
        
        self.init(authorizationEndpoint: authorizationEndpoint, tokenEndpoint: tokenEndpoint, apiBaseUrl: apiBaseUrl)
    }
}
