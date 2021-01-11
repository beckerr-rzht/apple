//
//  DiscoveryData.swift
//  EduVPN
//

// Models the data extracted from server_list.json and organization_list.json

import Foundation

struct DiscoveryData {
    typealias OrgId = String

    struct BaseURLString {
        let urlString: String
    }

    struct InstituteAccessServer {
        let baseURLString: BaseURLString
        let displayName: LanguageMappedString
        let supportContact: [String]
        let keywordList: LanguageMappedString?
    }

    struct SecureInternetServer {
        let baseURLString: BaseURLString
        let countryCode: String
        let supportContact: [String]
        let authenticationURLTemplate: String?
    }

    struct Organization {
        let orgId: OrgId
        let displayName: LanguageMappedString
        let keywordList: LanguageMappedString?
        let secureInternetHome: BaseURLString
    }

    struct Servers {
        let instituteAccessServers: [InstituteAccessServer]
        let secureInternetServersMap: [BaseURLString: SecureInternetServer]
    }

    struct Organizations {
        let organizations: [Organization]
    }
}

extension DiscoveryData.Organization: Decodable {
    enum CodingKeys: String, CodingKey {
        case orgId = "org_id"
        case displayName = "display_name"
        case keywordList = "keyword_list"
        case secureInternetHome = "secure_internet_home"
    }
}

extension DiscoveryData.Servers: Decodable {
    enum ServerListTopLevelKeys: String, CodingKey {
        case server_list // swiftlint:disable:this identifier_name
    }

    private struct ServerEntry: Decodable {
        let serverType: String
        let baseURLString: DiscoveryData.BaseURLString
        let displayName: LanguageMappedString?
        let countryCode: String?
        let supportContact: [String]?
        let keywordList: LanguageMappedString?
        let authenticationURLTemplate: String?

        enum CodingKeys: String, CodingKey { // swiftlint:disable:this nesting
            case serverType = "server_type"
            case baseURLString = "base_url"
            case displayName = "display_name"
            case countryCode = "country_code"
            case supportContact = "support_contact"
            case keywordList = "keyword_list"
            case authenticationURLTemplate = "authentication_url_template"
        }
    }

    init(from decoder: Decoder) throws {
        let listContainer = try decoder.container(keyedBy: ServerListTopLevelKeys.self)
        let list = try listContainer.decode([ServerEntry].self, forKey: .server_list)
        var instituteAccessServers: [DiscoveryData.InstituteAccessServer] = []
        var secureInternetServersMap: [DiscoveryData.BaseURLString: DiscoveryData.SecureInternetServer] = [:]
        for serverEntry in list {
            let baseURLString = serverEntry.baseURLString
            let supportContact = serverEntry.supportContact ?? []
            let authenticationURLTemplate = serverEntry.authenticationURLTemplate
            let keywordList = serverEntry.keywordList
            switch serverEntry.serverType {
            case "institute_access":
                if let displayName = serverEntry.displayName {
                    instituteAccessServers.append(DiscoveryData.InstituteAccessServer(
                        baseURLString: baseURLString, displayName: displayName,
                        supportContact: supportContact, keywordList: keywordList))
                }
            case "secure_internet":
                if let countryCode = serverEntry.countryCode {
                    secureInternetServersMap[baseURLString] = DiscoveryData.SecureInternetServer(
                        baseURLString: baseURLString, countryCode: countryCode,
                        supportContact: supportContact,
                        authenticationURLTemplate: authenticationURLTemplate)
                }
            default:
                break
            }
        }
        self.instituteAccessServers = instituteAccessServers
        self.secureInternetServersMap = secureInternetServersMap
    }
}

extension DiscoveryData.Organizations: Decodable {
    enum OrgListTopLevelKeys: String, CodingKey {
        case organization_list // swiftlint:disable:this identifier_name
    }

    init(from decoder: Decoder) throws {
        let listContainer = try decoder.container(keyedBy: OrgListTopLevelKeys.self)
        let list = try listContainer.decode([DiscoveryData.Organization].self, forKey: .organization_list)
        self.organizations = list
    }
}

extension DiscoveryData.BaseURLString: Hashable {
    static func == (lhs: DiscoveryData.BaseURLString, rhs: DiscoveryData.BaseURLString) -> Bool {
        return lhs.urlString == rhs.urlString
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(urlString)
    }
}

extension DiscoveryData.BaseURLString: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.urlString = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(urlString)
    }
}

enum DiscoveryDataURLError: Error {
    case invalidURLStringInDiscoveryData(urlString: String)
}

extension DiscoveryDataURLError: AppError {
    var summary: String {
        switch self {
        case .invalidURLStringInDiscoveryData(let urlString):
            return "Invalid URL string \"\(urlString)\" in discovery data"
        }
    }
}

extension DiscoveryData.BaseURLString {
    func toURL() throws -> URL {
        guard let url = URL(string: urlString) else {
            throw DiscoveryDataURLError.invalidURLStringInDiscoveryData(urlString: urlString)
        }
        return url
    }

    func toString() -> String {
        return urlString
    }
}
