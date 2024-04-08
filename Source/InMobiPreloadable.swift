// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK

/// A protocol that indicates that an InMobi ad can be preloaded using
/// their bidding APIs.

protocol InMobiPreloadable {
    /// Requesting an ad for bid.
    func preload(completion: @escaping (Result<PartnerEventDetails, Error>) -> Void)
}
