//
//  InMobiFullscreenAdAdapter.swift
//  HeliumAdapterInMobi
//
//  Created by Daniel Barros on 10/4/22.
//

import Foundation
import HeliumSdk
import InMobiSDK

/// The Helium InMobi ad adapter for interstitial and rewarded ads.
final class InMobiFullscreenAdAdapter: NSObject, PartnerAdAdapter {
    
    /// The associated partner adapter.
    let adapter: PartnerAdapter
    
    /// The ad request containing data relevant to load operation.
    private let request: PartnerAdLoadRequest
    
    /// The partner ad delegate to send ad life-cycle events to.
    private weak var partnerAdDelegate: PartnerAdDelegate?
    
    /// The InMobi ad instance.
    private let ad: IMInterstitial
    
    /// A PartnerAd object to send in ad life-cycle events.
    private lazy var partnerAd = PartnerAd(ad: ad, details: [:], request: request)
    
    /// The completion for the ongoing load operation.
    private var loadCompletion: ((Result<PartnerAd, Error>) -> Void)?

    /// The completion for the ongoing show operation.
    private var showCompletion: ((Result<PartnerAd, Error>) -> Void)?
    
    init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, partnerAdDelegate: PartnerAdDelegate) throws {
        guard let placementID = Int64(request.partnerPlacement) else {
            throw adapter.error(.loadFailure(request), description: "Failed to cast placement to Int64")
        }
        self.adapter = adapter
        self.request = request
        self.partnerAdDelegate = partnerAdDelegate
        self.ad = IMInterstitial(placementId: placementID)
        
        super.init()
        
        self.ad.delegate = self
    }
    
    /// Loads an ad.
    /// - note: Do not call this method directly, `ModularPartnerAdapter` will take care of it when needed.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<HeliumSdk.PartnerAd, Error>) -> Void) {
        loadCompletion = completion
        ad.load()
    }
    
    /// Shows a loaded ad.
    /// - note: Do not call this method directly, `ModularPartnerAdapter` will take care of it when needed.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<HeliumSdk.PartnerAd, Error>) -> Void) {
        showCompletion = completion
        // InMobi makes use of UI-related APIs directly from the thread show() is called, so we need to do it on the main thread
        DispatchQueue.main.async {
            self.ad.show(from: viewController)
        }
    }
}

extension InMobiFullscreenAdAdapter: IMInterstitialDelegate {
    
    func interstitialDidFinishLoading(_ interstitial: IMInterstitial?) {
        // Report load success
        loadCompletion?(.success(partnerAd)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func interstitial(_ interstitial: IMInterstitial?, didFailToLoadWithError partnerError: IMRequestStatus?) {
        // Report load failure
        let error = error(.loadFailure(request), error: partnerError)
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func interstitialDidPresent(_ interstitial: IMInterstitial?) {
        // Report show success
        showCompletion?(.success(partnerAd)) ?? log(.showResultIgnored)
        showCompletion = nil
    }
    
    func interstitial(_ interstitial: IMInterstitial?, didFailToPresentWithError partnerError: IMRequestStatus?) {
        // Report show failure
        let error = error(.showFailure(partnerAd), error: partnerError)
        showCompletion?(.failure(error)) ?? log(.showResultIgnored)
        showCompletion = nil
    }
    
    func interstitialDidDismiss(_ interstitial: IMInterstitial?) {
        // Report dismiss
        log(.didDismiss(partnerAd, error: nil))
        partnerAdDelegate?.didDismiss(partnerAd, error: nil)
    }
    
    func interstitial(_ interstitial: IMInterstitial?, didInteractWithParams params: [AnyHashable : Any]?) {
        // Report click
        log(.didClick(partnerAd, error: nil))
        partnerAdDelegate?.didClick(partnerAd)
    }
    
    // Note InMobi's IMInterstitial is also used for rewarded ads, thus this method is implemented here although it does not apply to interstitial ads
    func interstitial(_ interstitial: IMInterstitial?, rewardActionCompletedWithRewards rewards: [AnyHashable : Any]?) {
        // Report reward
        let rewardAmount = rewards?.first?.value as? Int
        let reward = Reward(amount: rewardAmount, label: nil)
        log(.didReward(partnerAd, reward: reward))
        partnerAdDelegate?.didReward(partnerAd, reward: reward)
    }
}
