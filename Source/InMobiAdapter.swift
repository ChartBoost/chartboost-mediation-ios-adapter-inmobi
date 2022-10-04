//
//  InMobiAdapter.swift
//  HeliumAdapterInMobi
//
//  Created by Daniel Barros on 10/4/22.
//

import Foundation
import HeliumSdk
import InMobiSDK

/// The Helium InMobi adapter.
final class InMobiAdapter: NSObject, ModularPartnerAdapter {
    
    /// The version of the partner SDK, e.g. "5.13.2"
    let partnerSDKVersion = IMSdk.getVersion()
    
    /// The version of the adapter, e.g. "2.5.13.2.0"
    /// The first number is Helium SDK's major version. The next 3 numbers are the partner SDK version. The last number is the build version of the adapter.
    let adapterVersion = "4.10.0.2.0"
    
    /// The partner's identifier.
    let partnerIdentifier = "inmobi"
    
    /// The partner's name in a human-friendly version.
    let partnerDisplayName = "InMobi"
    
    /// Created ad adapter instances, keyed by the request identifier.
    /// You should not generally need to modify this property in your adapter implementation, since it is managed by the
    /// `ModularPartnerAdapter` itself on its default implementation for `PartnerAdapter` load, show and invalidate methods.
    var adAdapters: [String: PartnerAdAdapter] = [:]
    
    /// The last value set on `setGDPRApplies(_:)`.
    private var gdprApplies: Bool?
    
    /// The last value set on `setGDPRConsentStatus(_:)`.
    private var gdprStatus: GDPRConsentStatus?
    
    /// Does any setup needed before beginning to load ads.
    /// - parameter configuration: Configuration data for the adapter to set up.
    /// - parameter completion: Closure to be performed by the adapter when it's done setting up. It should include an error indicating the cause for failure or `nil` if the operation finished successfully.
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Error?) -> Void) {
        log(.setUpStarted)
        // Get credentials, fail early if they are unavailable
        guard let accountID = configuration.accountID else {
            let error = error(.missingSetUpParameter(key: .accountIDKey))
            log(.setUpFailed(error))
            completion(error)
            return
        }
        // Initialize InMobi
        IMSdk.initWithAccountID(accountID) { [self] partnerError in
            if let partnerError = partnerError {
                let error = error(.setUpFailure, error: partnerError)
                log(.setUpFailed(error))
                completion(error)
            } else {
                log(.setUpSucceded)
                completion(nil)
            }
        }
    }
    
    /// Fetches bidding tokens needed for the partner to participate in an auction.
    /// - parameter request: Information about the ad load request.
    /// - parameter completion: Closure to be performed with the fetched info.
    func fetchBidderInformation(request: PreBidRequest, completion: @escaping ([String : String]) -> Void) {
        // InMobi does not currently provide any bidding token
        log(.fetchBidderInfoStarted(request))
        log(.fetchBidderInfoSucceeded(request))
        completion([:])
    }
    
    /// Indicates if GDPR applies or not.
    /// - parameter applies: `true` if GDPR applies, `false` otherwise.
    func setGDPRApplies(_ applies: Bool) {
        // Save value and set GDPR on InMobi using both gdprApplies and gdprStatus
        gdprApplies = applies
        updateGDPRConsent()
    }
    
    /// Indicates the user's GDPR consent status.
    /// - parameter status: One of the `GDPRConsentStatus` values depending on the user's preference.
    func setGDPRConsentStatus(_ status: GDPRConsentStatus) {
        // Save value and set GDPR on InMobi using both gdprApplies and gdprStatus
        gdprStatus = status
        updateGDPRConsent()
    }
    
    private func updateGDPRConsent() {
        // Set InMobi GDPR consent using both gdprApplies and gdprStatus
        var value: [String: Any] = [:]
        if let gdprApplies = gdprApplies {
            value[IM_PARTNER_GDPR_APPLIES] = gdprApplies ? String.gdprApplies : .gdprDoesNotApply
        }
        if let gdprStatus = gdprStatus, gdprStatus != .unknown {
            value[IM_PARTNER_GDPR_CONSENT_AVAILABLE] = gdprStatus == .granted ? String.gdprConsentAvailable : .gdprConsentUnavailable
        }
        IMSdk.setPartnerGDPRConsent(value)
        log(.privacyUpdated(setting: "partnerGDPRConsent", value: value))
    }
    
    /// Indicates the CCPA status both as a boolean and as a IAB US privacy string.
    /// - parameter hasGivenConsent: A boolean indicating if the user has given consent.
    /// - parameter privacyString: A IAB-compliant string indicating the CCPA status.
    func setCCPAConsent(hasGivenConsent: Bool, privacyString: String?) {
        // InMobi SDK does not provide CCPA APIs
    }
    
    /// Indicates if the user is subject to COPPA or not.
    /// - parameter isSubject: `true` if the user is subject, `false` otherwise.
    func setUserSubjectToCOPPA(_ isSubject: Bool) {
        // InMobi SDK does not provide COPPA APIs
    }
    
    /// Provides a new ad adapter in charge of communicating with a single partner ad instance.
    func makeAdAdapter(request: PartnerAdLoadRequest, partnerAdDelegate: PartnerAdDelegate) throws -> PartnerAdAdapter {
        switch request.format {
        case .interstitial, .rewarded:
            return try InMobiFullscreenAdAdapter(adapter: self, request: request, partnerAdDelegate: partnerAdDelegate)
        case .banner:
            return try InMobiBannerAdAdapter(adapter: self, request: request, partnerAdDelegate: partnerAdDelegate)
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
