// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import InMobiSDK

/// Base class for Chartboost Mediation InMobi adapter ads.
class InMobiAdapterAd: NSObject {
    
    /// The partner adapter that created this ad.
    let adapter: PartnerAdapter
    
    /// Extra ad information provided by the partner.
    var details: PartnerDetails = [:]

    /// The ad load request associated to the ad.
    /// It should be the one provided on ``PartnerAdapter/makeBannerAd(request:delegate:)`` or ``PartnerAdapter/makeFullscreenAd(request:delegate:)``.
    let request: PartnerAdLoadRequest
    
    /// The partner ad delegate to send ad life-cycle events to.
    /// It should be the one provided on ``PartnerAdapter/makeBannerAd(request:delegate:)`` or ``PartnerAdapter/makeFullscreenAd(request:delegate:)``.
    weak var delegate: PartnerAdDelegate?
    
    /// The completion for the ongoing load operation.
    var loadCompletion: ((Result<PartnerDetails, Error>) -> Void)?

    /// The completion for the ongoing show operation.
    var showCompletion: ((Result<PartnerDetails, Error>) -> Void)?
    
    init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws {
        self.adapter = adapter
        self.request = request
        self.delegate = delegate
    }
}
