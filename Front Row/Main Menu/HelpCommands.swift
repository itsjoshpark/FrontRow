//
//  HelpCommands.swift
//  Front Row
//
//  Created by Joshua Park on 3/7/24.
//

import SwiftUI

struct HelpCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .help) {
            Link(
                "Website",
                destination: URL(string: "https://github.com/itsjoshpark/FrontRow")!
            )
            Link(
                "Improve Translation",
                destination: URL(string: "https://crowdin.com/project/FrontRow")!
            )
            Link(
                "Report a Problem",
                destination: URL(string: "https://github.com/itsjoshpark/FrontRow/issues")!
            )
        }
    }
}
