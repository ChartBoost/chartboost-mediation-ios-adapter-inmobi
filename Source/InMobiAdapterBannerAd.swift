// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import InMobiSDK

/// The Chartboost Mediation InMobi adapter banner ad.
final class InMobiAdapterBannerAd: InMobiAdapterAd, PartnerBannerAd {
    /// The partner banner ad view to display.
    var view: UIView?

    /// The loaded partner ad banner size.
    var size: PartnerBannerSize?

    /// InMobi's placement ID needed to create a IMBanner instance.
    private let placementID: Int64
    
    override init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws {
        guard let placementID = Int64(request.partnerPlacement) else {
            throw adapter.error(.loadFailureInvalidPartnerPlacement, description: "Failed to cast placement to Int64")
        }
        self.placementID = placementID
        try super.init(adapter: adapter, request: request, delegate: delegate)
    }
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.loadStarted)

        // Fail if we cannot fit a fixed size banner in the requested size.
        guard let loadedSize = fixedBannerSize(for: request.bannerSize) else {
            let error = error(.loadFailureInvalidBannerSize)
            log(.loadFailed(error))
            return completion(.failure(error))
        }
        size = PartnerBannerSize(size: loadedSize, type: .fixed)

        // Save completion for later
        loadCompletion = completion
        
        // Create the banner
        let frame = CGRect(origin: .zero, size: loadedSize)
        let ad = IMBanner(frame: frame, placementId: placementID, delegate: self)
        ad.shouldAutoRefresh(false)
        view = ad

        // Load it
        ad.load()
    }
}

extension InMobiAdapterBannerAd: IMBannerDelegate {

    func bannerAdImpressed(_ banner: IMBanner) {
        log(.didTrackImpression)
        delegate?.didTrackImpression(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func bannerDidFinishLoading(_ banner: IMBanner) {
        // Report load success
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func banner(_ banner: IMBanner, didFailToLoadWithError partnerError: IMRequestStatus) {
        // Report load failure
        let error = partnerError
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func banner(_ banner: IMBanner, didInteractWithParams params: [String : Any]?) {
        // Report click
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }
}

// MARK: - Helpers
extension InMobiAdapterBannerAd {
    private func fixedBannerSize(for requestedSize: BannerSize?) -> CGSize? {
        guard let requestedSize else {
            return IABStandardAdSize
        }
        let sizes = [IABLeaderboardAdSize, IABMediumAdSize, IABStandardAdSize]
        // Find the largest size that can fit in the requested size.
        for size in sizes {
            // If height is 0, the pub has requested an ad of any height, so only the width matters.
            if requestedSize.size.width >= size.width &&
                (size.height == 0 || requestedSize.size.height >= size.height) {
                return size
            }
        }
        // The requested size cannot fit any fixed size banners.
        return nil
    }
}
