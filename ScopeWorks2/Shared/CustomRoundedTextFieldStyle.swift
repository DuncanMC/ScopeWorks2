//
//  CustomRoundedTextFieldStyle.swift
//  ScopeWorks2
//
//  Created by Duncan Champney on 7/7/26.
//

import SwiftUI
#if os(macOS)
    import AppKit
#else
    import UIKit

#endif

extension TextFieldStyle where Self == CustomRoundedTextFieldStyle {

    public static func customRoundedBorderTextFieldStyle(
        cornerRadius: CGFloat = 5,
        borderColor: Color = Color(white: 0.75),
        borderWidth: CGFloat = 0.5,
        backgroundColor: Color = CustomRoundedTextFieldStyle.defaultBackgroundColor
    ) -> CustomRoundedTextFieldStyle {
        return CustomRoundedTextFieldStyle(
            cornerRadius: cornerRadius,
            borderColor: borderColor,
            borderWidth: borderWidth,
            backgroundColor: backgroundColor)
    }
}
    
public struct CustomRoundedTextFieldStyle: TextFieldStyle {
#if os(macOS)
    public static var defaultBackgroundColor: Color { Color(.textBackgroundColor) }
#else
    public static var defaultBackgroundColor: Color { Color(.systemBackground) }
#endif

    var cornerRadius: CGFloat
    var borderColor: Color
    var borderWidth: CGFloat
    var backgroundColor: Color

    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
}
