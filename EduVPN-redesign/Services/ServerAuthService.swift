//
//  ServerAuthService.swift
//  EduVPN-redesign-macOS
//

import Foundation
import AppAuth
import Moya
import PromiseKit

class ServerAuthService {

    struct WAYFSkippingInfo {
        // Info to help skip the Where-Are-You-From page while authorizing
        // in the browser for Secure Internet servers.
        // See https://github.com/eduvpn/documentation/blob/v2/SERVER_DISCOVERY_SKIP_WAYF.md
        let authURLTemplate: String
        let orgId: String
    }

    private let configRedirectURL: URL // For iOS
    private let configClientId: String // For macOS

    private var currentAuthFlow: OIDExternalUserAgentSession?

    #if os(macOS)
    private lazy var redirectHttpHandler = OIDRedirectHTTPHandler(successURL: nil)
    #endif

    var redirectURL: URL {
        #if os(macOS)
        assert(Thread.isMainThread)
        return URL(
            string: "callback",
            relativeTo: redirectHttpHandler.startHTTPListener(nil))! // swiftlint:disable:this force_unwrapping
        #elseif os(iOS)
        return configRedirectURL
        #endif
    }

    init(configRedirectURL: URL, configClientId: String) {
        self.configRedirectURL = configRedirectURL
        self.configClientId = configClientId
    }

    func startAuth(baseURLString: DiscoveryData.BaseURLString,
                   from viewController: AuthorizingViewController,
                   wayfSkippingInfo: WAYFSkippingInfo?) -> Promise<AuthState> {
        #if os(macOS)
        viewController.showAuthorizingMessage(onCancelled: { [weak self] in
            self?.cancelAuth()
        })
        #endif
        return firstly {
            ServerInfoFetcher.fetch(baseURLString: baseURLString)
        }.then { serverInfo in
            self.startAuth(
                authEndpoint: serverInfo.authorizationEndpoint,
                tokenEndpoint: serverInfo.tokenEndpoint,
                from: viewController,
                wayfSkippingInfo: wayfSkippingInfo,
                shouldShowAuthorizingMessage: false)
        }
    }

    func startAuth(authEndpoint: ServerInfo.OAuthEndpoint,
                   tokenEndpoint: ServerInfo.OAuthEndpoint,
                   from viewController: AuthorizingViewController,
                   wayfSkippingInfo: WAYFSkippingInfo?,
                   shouldShowAuthorizingMessage: Bool = true) -> Promise<AuthState> {
        #if os(macOS)
        if shouldShowAuthorizingMessage {
            viewController.showAuthorizingMessage(onCancelled: { [weak self] in
                self?.cancelAuth()
            })
        }
        #endif
        let authConfig = OIDServiceConfiguration(
            authorizationEndpoint: authEndpoint,
            tokenEndpoint: tokenEndpoint)
        let authRequest = OIDAuthorizationRequest(
            configuration: authConfig,
            clientId: configClientId,
            scopes: ["config"],
            redirectURL: redirectURL,
            responseType: OIDResponseTypeCode,
            additionalParameters: nil)
        return Promise { seal in
            let authFlow = createAuthState(
                authRequest: authRequest,
                viewController: viewController,
                wayfSkippingInfo: wayfSkippingInfo) { (authState, error) in
                    #if os(macOS)
                    NSApp.activate(ignoringOtherApps: true)
                    viewController.hideAuthorizingMessage()
                    #endif
                    if let authState = authState {
                        seal.resolve(AuthState(oidAuthState: authState), error)
                    } else {
                        seal.resolve(nil, error)
                    }
            }
            #if os(macOS)
            redirectHttpHandler.currentAuthorizationFlow = authFlow
            #endif
            currentAuthFlow = authFlow
        }
    }

    #if os(iOS)
    @discardableResult
    func resumeAuth(with url: URL) -> Bool {
        guard let currentAuthFlow = currentAuthFlow else {
            return false
        }
        return currentAuthFlow.resumeExternalUserAgentFlow(with: url)
    }
    #endif

    func cancelAuth() {
        #if os(macOS)
        redirectHttpHandler.cancelHTTPListener()
        #endif
        if let currentAuthFlow = currentAuthFlow {
            currentAuthFlow.cancel()
        }
    }

    func isUserCancelledError(_ error: Error) -> Bool {
        let domain = (error as NSError).domain
        let code = (error as NSError).code
        return domain == OIDGeneralErrorDomain &&
            (code == OIDErrorCode.programCanceledAuthorizationFlow.rawValue ||
                code == OIDErrorCode.userCanceledAuthorizationFlow.rawValue)
    }

    private func createAuthState(
        authRequest: OIDAuthorizationRequest,
        viewController: AuthorizingViewController,
        wayfSkippingInfo: WAYFSkippingInfo?,
        callback: @escaping OIDAuthStateAuthorizationCallback) -> OIDExternalUserAgentSession? {

        let userAgent = OAuthExternalUserAgent(presentingViewController: viewController, wayfSkippingInfo: wayfSkippingInfo)
        return OIDAuthState.authState(byPresenting: authRequest,
                                      externalUserAgent: userAgent,
                                      callback: callback)
    }
}