import SwiftUI

enum BWType {
    static let exhaustedHeadlineSize: CGFloat = 40
    static let exhaustedResetSize: CGFloat = 32
    static let exhaustedAsideSize: CGFloat = 24
    static let grayVerdictSize: CGFloat = 32
    static let restingComposerSize: CGFloat = 19
    static let display = Font.system(size: 88, weight: .black, design: .default)
    static let title = Font.system(.largeTitle, design: .default, weight: .bold)
    static let body = Font.system(.body, design: .default, weight: .regular)
    static let restingComposer = Font.system(size: restingComposerSize, weight: .bold, design: .default)
    static let reaction = Font.system(.title3, design: .default, weight: .regular).italic()
    static let button = Font.system(size: 18, weight: .bold, design: .default)
}
