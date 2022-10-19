//
//  InMobiAdapterFullscreenAd.swift
//  HeliumAdapterInMobi
//
//  Created by Daniel Barros on 10/4/22.
//

import Foundation
import HeliumSdk
import InMobiSDK

/// The Helium InMobi adapter fullscreen ad.
final class InMobiAdapterFullscreenAd: InMobiAdapterAd, PartnerAd {
    
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView? { nil }
    
    /// The InMobi ad instance.
    private let ad: IMInterstitial
    
    override init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws {
        guard let placementID = Int64(request.partnerPlacement) else {
            throw adapter.error(.invalidPlacement, description: "Failed to cast placement to Int64")
        }
        self.ad = IMInterstitial(placementId: placementID)
        
        try super.init(adapter: adapter, request: request, delegate: delegate)
        
        self.ad.delegate = self
    }
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        loadCompletion = completion
        ad.load()
    }
    
    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.showStarted)
        showCompletion = completion
        // InMobi makes use of UI-related APIs directly from the thread show() is called, so we need to do it on the main thread
        DispatchQueue.main.async {
            self.ad.show(from: viewController)
        }
    }
}

extension InMobiAdapterFullscreenAd: IMInterstitialDelegate {
    
    func interstitialDidFinishLoading(_ interstitial: IMInterstitial?) {
        // Report load success
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func interstitial(_ interstitial: IMInterstitial?, didFailToLoadWithError partnerError: IMRequestStatus?) {
        // Report load failure
        let error = error(.loadFailure, error: partnerError)
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func interstitialDidPresent(_ interstitial: IMInterstitial?) {
        // Report show success
        log(.showSucceeded)
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
        showCompletion = nil
    }
    
    func interstitial(_ interstitial: IMInterstitial?, didFailToPresentWithError partnerError: IMRequestStatus?) {
        // Report show failure
        let error = error(.showFailure, error: partnerError)
        log(.showFailed(error))
        showCompletion?(.failure(error)) ?? log(.showResultIgnored)
        showCompletion = nil
    }
    
    func interstitialDidDismiss(_ interstitial: IMInterstitial?) {
        // Report dismiss
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, details: [:], error: nil)
    }
    
    func interstitial(_ interstitial: IMInterstitial?, didInteractWithParams params: [AnyHashable : Any]?) {
        // Report click
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:])
    }
    
    // Note InMobi's IMInterstitial is also used for rewarded ads, thus this method is implemented here although it does not apply to interstitial ads
    func interstitial(_ interstitial: IMInterstitial?, rewardActionCompletedWithRewards rewards: [AnyHashable : Any]?) {
        // Report reward
        let rewardAmount = rewards?.first?.value as? Int
        let reward = Reward(amount: rewardAmount, label: nil)
        log(.didReward(reward))
        delegate?.didReward(self, details: [:], reward: reward)
    }
}
