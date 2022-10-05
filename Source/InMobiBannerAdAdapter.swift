//
//  InMobiBannerAdAdapter.swift
//  HeliumAdapterInMobi
//
//  Created by Daniel Barros on 10/4/22.
//

import Foundation
import HeliumSdk
import InMobiSDK

/// The Helium InMobi ad adapter for banner ads.
final class InMobiBannerAdAdapter: NSObject, PartnerAdAdapter {
    
    /// The associated partner adapter.
    let adapter: PartnerAdapter
    
    /// The ad request containing data relevant to load operation.
    private let request: PartnerAdLoadRequest
    
    /// The partner ad delegate to send ad life-cycle events to.
    private weak var partnerAdDelegate: PartnerAdDelegate?
    
    /// The InMobi ad instance.
    private var ad: IMBanner?
    
    /// InMobi's placement ID needed to create a IMBanner instance.
    private let placementID: Int64
    
    /// A PartnerAd object to send in ad life-cycle events.
    private lazy var partnerAd = PartnerAd(ad: ad, details: [:], request: request)
    
    /// The completion for the ongoing load operation.
    private var loadCompletion: ((Result<PartnerAd, Error>) -> Void)?
    
    init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, partnerAdDelegate: PartnerAdDelegate) throws {
        guard let placementID = Int64(request.partnerPlacement) else {
            throw adapter.error(.loadFailure(request), description: "Failed to cast placement to Int64")
        }
        self.adapter = adapter
        self.request = request
        self.partnerAdDelegate = partnerAdDelegate
        self.placementID = placementID
    }
    
    /// Loads an ad.
    /// - note: Do not call this method directly, `ModularPartnerAdapter` will take care of it when needed.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<HeliumSdk.PartnerAd, Error>) -> Void) {
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
    /// - note: Do not call this method directly, `ModularPartnerAdapter` will take care of it when needed.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<HeliumSdk.PartnerAd, Error>) -> Void) {
        // no-op
    }
}

extension InMobiBannerAdAdapter: IMBannerDelegate {
    
    func bannerDidFinishLoading(_ banner: IMBanner?) {
        // Report load success
        loadCompletion?(.success(partnerAd)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func banner(_ banner: IMBanner?, didFailToLoadWithError partnerError: IMRequestStatus?) {
        // Report load failure
        let error = error(.loadFailure(request), error: partnerError)
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func banner(_ banner: IMBanner?, didInteractWithParams params: [AnyHashable : Any]?) {
        // Report click
        log(.didClick(partnerAd, error: nil))
        partnerAdDelegate?.didClick(partnerAd)
    }
}
