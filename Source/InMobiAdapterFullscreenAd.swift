// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import InMobiSDK

/// The Chartboost Mediation InMobi adapter fullscreen ad.
final class InMobiAdapterFullscreenAd: InMobiAdapterAd, PartnerFullscreenAd {
    /// The InMobi ad instance.
    private let ad: IMInterstitial

    override init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws {
        guard let placementID = Int64(request.partnerPlacement) else {
            throw adapter.error(.loadFailureInvalidPartnerPlacement, description: "Failed to cast placement to Int64")
        }
        self.ad = IMInterstitial(placementId: placementID)

        try super.init(adapter: adapter, request: request, delegate: delegate)

        self.ad.delegate = self
    }

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Error?) -> Void) {
        log(.loadStarted)
        loadCompletion = completion
        if let adm = request.adm, let data = adm.data(using: .utf8) {
            ad.load(data)
        } else {
            ad.load()
        }
    }

    /// Shows a loaded ad.
    /// Chartboost Mediation SDK will always call this method from the main thread.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Error?) -> Void) {
        log(.showStarted)
        showCompletion = completion
        ad.show(from: viewController)
    }
}

extension InMobiAdapterFullscreenAd: IMInterstitialDelegate {
    func interstitialDidFinishLoading(_ interstitial: IMInterstitial) {
        // Report load success
        log(.loadSucceeded)
        loadCompletion?(nil) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func interstitial(_ interstitial: IMInterstitial, didFailToLoadWithError partnerError: IMRequestStatus) {
        // Report load failure
        let error = partnerError
        log(.loadFailed(error))
        loadCompletion?(error) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func interstitialDidPresent(_ interstitial: IMInterstitial) {
        // Report show success
        log(.showSucceeded)
        showCompletion?(nil) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func interstitial(_ interstitial: IMInterstitial, didFailToPresentWithError partnerError: IMRequestStatus) {
        // Report show failure
        let error = partnerError
        log(.showFailed(error))
        showCompletion?(error) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func interstitialDidDismiss(_ interstitial: IMInterstitial) {
        // Report dismiss
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, error: nil) ?? log(.delegateUnavailable)
    }

    func interstitial(_ interstitial: IMInterstitial, didInteractWithParams params: [String: Any]?) {
        // Report click
        log(.didClick(error: nil))
        delegate?.didClick(self) ?? log(.delegateUnavailable)
    }

    // Note InMobi's IMInterstitial is also used for rewarded ads, thus this method is implemented here although it does not apply to
    // interstitial ads
    func interstitial(_ interstitial: IMInterstitial, rewardActionCompletedWithRewards rewards: [String: Any]) {
        // Report reward
        log(.didReward)
        delegate?.didReward(self) ?? log(.delegateUnavailable)
    }

    func interstitialAdImpressed(_ interstitial: IMInterstitial) {
        // Report impression
        log(.didTrackImpression)
        delegate?.didTrackImpression(self) ?? log(.delegateUnavailable)
    }
}
