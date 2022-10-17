//
//  InMobiAdapterBannerAd.swift
//  HeliumAdapterInMobi
//
//  Created by Daniel Barros on 10/4/22.
//

import Foundation
import HeliumSdk
import InMobiSDK

/// The Helium InMobi adapter banner ad.
final class InMobiAdapterBannerAd: InMobiAdapterAd, PartnerAd {
    
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView? { ad }
    
    /// The InMobi ad instance.
    private var ad: IMBanner?
    
    /// InMobi's placement ID needed to create a IMBanner instance.
    private let placementID: Int64
    
    override init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws {
        guard let placementID = Int64(request.partnerPlacement) else {
            throw adapter.error(.invalidPlacement, description: "Failed to cast placement to Int64")
        }
        self.placementID = placementID
        try super.init(adapter: adapter, request: request, delegate: delegate)
    }
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        
        // Save completion for later
        loadCompletion = completion
        
        // InMobi banner inherits from UIView so we need to instantiate it on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Create the banner
            let frame = CGRect(origin: .zero, size: self.request.size ?? IABStandardAdSize)
            let ad = IMBanner(frame: frame, placementId: self.placementID, delegate: self)
            self.ad = ad
            ad?.shouldAutoRefresh(false)
            
            // Load it
            ad?.load()
        }
    }
    
    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        // no-op
    }
}

extension InMobiAdapterBannerAd: IMBannerDelegate {
    
    func bannerDidFinishLoading(_ banner: IMBanner?) {
        // Report load success
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func banner(_ banner: IMBanner?, didFailToLoadWithError partnerError: IMRequestStatus?) {
        // Report load failure
        let error = error(.loadFailure, error: partnerError)
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func banner(_ banner: IMBanner?, didInteractWithParams params: [AnyHashable : Any]?) {
        // Report click
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:])
    }
}