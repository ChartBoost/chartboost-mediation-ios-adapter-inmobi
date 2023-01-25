// Copyright 2022-2023 Chartboost, Inc.
// 
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

//
//  InMobiAdapter.swift
//  HeliumAdapterInMobi
//
//  Created by Daniel Barros on 10/4/22.
//

import ChartboostMediationSDK
import Foundation
import InMobiSDK

/// The Helium InMobi adapter.
final class InMobiAdapter: NSObject, PartnerAdapter {
    
    /// The version of the partner SDK.
    let partnerSDKVersion = IMSdk.getVersion()
    
    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Helium SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Helium major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    let adapterVersion = "4.10.1.2.0"
    
    /// The partner's unique identifier.
    let partnerIdentifier = "inmobi"
    
    /// The human-friendly partner name.
    let partnerDisplayName = "InMobi"
    
    /// The designated initializer for the adapter.
    /// Helium SDK will use this constructor to create instances of conforming types.
    /// - parameter storage: An object that exposes storage managed by the Helium SDK to the adapter.
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
        IMSdk.initWithAccountID(accountID) { [self] partnerError in
            if let partnerError = partnerError {
                log(.setUpFailed(partnerError))
                completion(partnerError)
            } else {
                log(.setUpSucceded)
                completion(nil)
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
        // InMobi SDK does not provide COPPA APIs
    }
    
    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Helium SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Helium SDK takes care of storing and disposing of ad instances so you don't need to.
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
