// Copyright 2022-2024 Chartboost, Inc.
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
    let adapterVersion = "4.10.7.0.0"

    /// The partner's unique identifier.
    let partnerID = "inmobi"

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
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.setUpStarted)
        // Get credentials, fail early if they are unavailable
        guard let accountID = configuration.accountID else {
            let error = error(.initializationFailureInvalidCredentials, description: "Missing \(String.accountIDKey)")
            log(.setUpFailed(error))
            completion(.failure(error))
            return
        }
        // Initialize InMobi
        // It's necessary to call `initWithAccountID` on the main thread because it appears to
        // occasionally use WebKit APIs that must be accessed on the main thread.
        DispatchQueue.main.async { [self] in
            IMSdk.initWithAccountID(accountID) { [self] error in
                if let error = error {
                    log(.setUpFailed(error))
                    completion(.failure(error))
                } else {
                    log(.setUpSucceded)
                    completion(.success([:]))
                }
            }
        }
    }

    /// Fetches bidding tokens needed for the partner to participate in an auction.
    /// - parameter request: Information about the ad load request.
    /// - parameter completion: Closure to be performed with the fetched info.
    func fetchBidderInformation(request: PartnerAdPreBidRequest, completion: @escaping (Result<[String : String], Error>) -> Void) {
        // InMobi does not currently provide any bidding token
        log(.fetchBidderInfoNotSupported)
        completion(.success([:]))
    }

    /// Indicates that the user consent has changed.
    /// - parameter consents: The new consents value, including both modified and unmodified consents.
    /// - parameter modifiedKeys: A set containing all the keys that changed.
    func setConsents(_ consents: [ConsentKey: ConsentValue], modifiedKeys: Set<ConsentKey>) {
        guard modifiedKeys.contains(partnerID)
                || modifiedKeys.contains(ConsentKeys.gdprConsentGiven)
                || modifiedKeys.contains(ConsentKeys.tcf)
        else {
            return
        }
        // See IMSdk.setPartnerGDPRConsent(_:) documentation on IMSdk.h

        // GDPR Applies
        var value: [String: Any] = [:]
        if let applies = UserDefaults.standard.string(forKey: .tcfGDPRApplies) {
            // applies = "1", does not apply = "0"
            // Both IAB and IMSdk use the same values with the same meaning, so it's a direct assignment
            value[IMCommonConstants.IM_PARTNER_GDPR_APPLIES] = applies
        }

        // GDPR consent
        let consent = consents[partnerID] ?? consents[ConsentKeys.gdprConsentGiven]
        switch consent {
        case ConsentValues.granted:
            value[IMCommonConstants.IM_PARTNER_GDPR_CONSENT_AVAILABLE] = String.gdprConsentAvailable
        case ConsentValues.denied:
            value[IMCommonConstants.IM_PARTNER_GDPR_CONSENT_AVAILABLE] = String.gdprConsentUnavailable
        default:
            break
        }

        // TCF string
        if let tcfString = consents[ConsentKeys.tcf] {
            value[IMCommonConstants.IM_GDPR_CONSENT_IAB] = tcfString
        }

        IMSdk.setPartnerGDPRConsent(value)
        log(.privacyUpdated(setting: "partnerGDPRConsent", value: value))
    }

    /// Indicates that the user is underage signal has changed.
    /// - parameter isUserUnderage: `true` if the user is underage as determined by the publisher, `false` otherwise.
    func setIsUserUnderage(_ isUserUnderage: Bool) {
        // See https://support.inmobi.com/monetize/sdk-documentation/ios-guidelines/overview-ios-guidelines#optimizing-data
        IMSdk.setIsAgeRestricted(isUserUnderage)
        log(.privacyUpdated(setting: "isAgeRestricted", value: isUserUnderage))
    }
    
    /// Creates a new banner ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// ``PartnerAd/invalidate()`` is called on ads before disposing of them in case partners need to perform any custom logic before the
    /// object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// Chartboost Mediation SDK will always call this method from the main thread.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeBannerAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerBannerAd {
        // This partner supports multiple loads for the same partner placement.
        try InMobiAdapterBannerAd(adapter: self, request: request, delegate: delegate)
    }

    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// ``PartnerAd/invalidate()`` is called on ads before disposing of them in case partners need to perform any custom logic before the
    /// object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeFullscreenAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerFullscreenAd {
        // This partner supports multiple loads for the same partner placement.
        switch request.format {
        case PartnerAdFormats.interstitial, PartnerAdFormats.rewarded:
            return try InMobiAdapterFullscreenAd(adapter: self, request: request, delegate: delegate)
        default:
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
        case .incorrectPlacementID:
            return .loadFailureInvalidPartnerPlacement
        case .sdkNotInitialised:
            return .loadFailurePartnerNotInitialized
        case .invalidBannerframe:
            return .loadFailureInvalidBannerSize
        default:
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
    /// InMobi GDPR available consent value. Defined in IMSdk.h comments.
    static let gdprConsentAvailable = "true"
    /// InMobi GDPR unavailable consent value. Defined in IMSdk.h comments.
    static let gdprConsentUnavailable = "false"
    /// This key for the TCFv2 string when stored in UserDefaults is defined by the IAB in Consent Management Platform API Final v.2.2 May 2023
    /// https://github.com/InteractiveAdvertisingBureau/GDPR-Transparency-and-Consent-Framework/blob/master/TCFv2/IAB%20Tech%20Lab%20-%20CMP%20API%20v2.md#what-is-the-cmp-in-app-internal-structure-for-the-defined-api
    static let tcfGDPRApplies = "IABTCF_gdprApplies"
}
