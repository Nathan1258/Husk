//
//  Extensions.swift
//  husk
//
//  Created by Nathan Ellis on 30/05/2025.
//

import SwiftUI

extension View {
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
        }
    }
}
