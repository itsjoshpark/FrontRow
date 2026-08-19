//
//  RemuxOfferAlert.swift
//  Front Row
//
//  Created by Joshua Park on 8/15/26.
//

import SwiftUI

/// What the "convert this file?" alert says.
///
/// Kept apart from the view so the one wording decision it makes - whether the subtitle warning is
/// appended - can be tested without a window.
enum RemuxOfferAlert {

    static func message(for offer: RemuxOffer) -> String {
        var message = String(
            localized:
                "\"\(offer.url.lastPathComponent)\" can be opened after it is converted.",
            comment: "Alert message offering to convert a file into a format Front Row can play"
        )

        // Only bitmap subtitles are lost; text tracks are converted and never worth mentioning.
        if offer.plan.recipe?.droppedSubtitles.isEmpty == false {
            message +=
                " "
                + String(
                    localized: "Subtitles will be dropped.",
                    comment: "Appended when subtitle tracks cannot survive the conversion"
                )
        }

        return message
    }
}

struct RemuxOfferMessage: View {
    let offer: RemuxOffer

    var body: some View {
        Text(RemuxOfferAlert.message(for: offer))
    }
}
