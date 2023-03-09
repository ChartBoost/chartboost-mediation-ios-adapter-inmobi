// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import InMobiSDK

/// The Chartboost Mediation InMobi adapter.
final class InMobiAdapter: NSObject, PartnerAdapter {
    
    /// The version of the partner SDK.
    let partnerSDKVersion = IMSdk.getVersion()
    
    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    let adapterVersion = "4.10.1.3.0"
    
    /// The partner's unique identifier.
    let partnerIdentifier = "inmobi"
    
    /// The human-friendly partner name.
    let partnerDisplayName = "InMobi"
    
    /// The designated initializer for the adapter.
    /// Chartboost Mediation SDK will use this constructor to create instances of conforming types.
    /// - parameter storage: An object that exposes storage managed by the Chartboost Mediation SDK to the adapter.
    /// It includes a list of created `PartnerAd` instances. You may ignore this parameter if you don't need it.
    init(storage: PartnerAdapterStorage) {}
    
    /// Does any setup needed before beginning to load ads.
    /// - parameter configuration: Configuration data for the adapter to set up.
    /// - parameter completion: Closure to be performed by the adapter when it's done setting up. It should include an error indicating the cause for failure or `nil` if the operation finished successfully.
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Error?) -> Void) {
        log(.setUpStarted)
        // Get credentials, fail early if they are unavailable
        guard let accountID = configuration.accountID else {
            let error = error(.initializationFailureInvalidCredentials, description: "Missing \(String.accountIDKey)")
            log(.setUpFailed(error))
            completion(error)
            return
        }
        // Initialize InMobi
        // It's necessary to call `initWithAccountID` on the main thread because it appears to
        // occasionally use WebKit APIs that must be accessed on the main thread.
        DispatchQueue.main.async { [self] in
            IMSdk.initWithAccountID(accountID) { [self] error in
                if let error = error {
                    log(.setUpFailed(error))
                    completion(error)
                } else {
                    log(.setUpSucceded)
                    completion(nil)
                }
            }
        }
    }
    
    /// Fetches bidding tokens needed for the partner to participate in an auction.
    /// - parameter request: Information about the ad load request.
    /// - parameter completion: Closure to be performed with the fetched info.
    func fetchBidderInformation(request: PreBidRequest, completion: @escaping ([String : String]?) -> Void) {
        // InMobi does not currently provide any bidding token
        completion(nil)
    }
    
    /// Indicates if GDPR applies or not and the user's GDPR consent status.
    /// - parameter applies: `true` if GDPR applies, `false` if not, `nil` if the publisher has not provided this information.
    /// - parameter status: One of the `GDPRConsentStatus` values depending on the user's preference.
    func setGDPR(applies: Bool?, status: GDPRConsentStatus) {
        // See IMSdk.setPartnerGDPRConsent(_:) documentation on IMSdk.h
        var value: [String: Any] = [:]
        if let applies = applies {
            value[IM_PARTNER_GDPR_APPLIES] = applies ? String.gdprApplies : .gdprDoesNotApply
        }
        if status != .unknown {
            value[IM_PARTNER_GDPR_CONSENT_AVAILABLE] = status == .granted ? String.gdprConsentAvailable : .gdprConsentUnavailable
        }
        IMSdk.setPartnerGDPRConsent(value)
        log(.privacyUpdated(setting: "partnerGDPRConsent", value: value))
    }
    
    /// Indicates the CCPA status both as a boolean and as an IAB US privacy string.
    /// - parameter hasGivenConsent: A boolean indicating if the user has given consent.
    /// - parameter privacyString: An IAB-compliant string indicating the CCPA status.
    func setCCPA(hasGivenConsent: Bool, privacyString: String) {
        // InMobi SDK does not provide CCPA APIs
    }
    
    /// Indicates if the user is subject to COPPA or not.
    /// - parameter isChildDirected: `true` if the user is subject to COPPA, `false` otherwise.
    func setCOPPA(isChildDirected: Bool) {
        // See https://support.inmobi.com/monetize/sdk-documentation/ios-guidelines/overview-ios-guidelines#optimizing-data
        IMSdk.setIsAgeRestricted(isChildDirected)
        log(.privacyUpdated(setting: "isAgeRestricted", value: isChildDirected))
    }
    
    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// `invalidate()` is called on ads before disposing of them in case partners need to perform any custom logic before the object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerAd {
        switch request.format {
        case .interstitial, .rewarded:
            return try InMobiAdapterFullscreenAd(adapter: self, request: request, delegate: delegate)
        case .banner:
            return try InMobiAdapterBannerAd(adapter: self, request: request, delegate: delegate)
        @unknown default:
            throw error(.loadFailureUnsupportedAdFormat)
        }
    }
    
    /// Maps a partner load error to a Chartboost Mediation error code.
    /// Chartboost Mediation SDK calls this method when a load completion is called with a partner error.
    ///
    /// A default implementation is provided that returns `nil`.
    /// Only implement if the partner SDK provides its own list of error codes that can be mapped to Chartboost Mediation's.
    /// If some case cannot be mapped return `nil` to let Chartboost Mediation choose a default error code.
    func mapLoadError(_ error: Error) -> ChartboostMediationError.Code? {
        guard let error = error as? IMRequestStatus,
              let code = IMStatusCode(rawValue: error.code) else {
            return nil
        }
        switch code {
        case .networkUnReachable:
            return .loadFailureNoConnectivity
        case .noFill:
            return .loadFailureNoFill
        case .requestInvalid:
            return .loadFailureInvalidAdRequest
        case .requestPending:
            return .loadFailureLoadInProgress
        case .requestTimedOut:
            return .loadFailureTimeout
        case .multipleLoadsOnSameInstance:
            return .loadFailureLoadInProgress
        case .internalError:
            return .loadFailureUnknown
        case .serverError:
            return .loadFailureServerError
        case .adActive:
            return .loadFailureShowInProgress
        case .earlyRefreshRequest:
            return .loadFailureAborted
        case .droppingNetworkRequest:
            return .loadFailureNetworkingError
        @unknown default:
            return nil
        }
    }
}

/// Convenience extension to access InMobi credentials from the configuration.
private extension PartnerConfiguration {
    var accountID: String? { credentials[.accountIDKey] as? String }
}

private extension String {
    /// InMobi account ID credentials key
    static let accountIDKey = "account_id"
    /// InMobi GDPR applies value. Defined in IMSdk.h comments.
    static let gdprApplies = "1"
    /// InMobi GDPR does not apply value. Defined in IMSdk.h comments.
    static let gdprDoesNotApply = "0"
    /// InMobi GDPR available consent value. Defined in IMSdk.h comments.
    static let gdprConsentAvailable = "true"
    /// InMobi GDPR unavailable consent value. Defined in IMSdk.h comments.
    static let gdprConsentUnavailable = "false"
}
