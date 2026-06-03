// Disambiguate VideoTaggingCore.Section from SwiftUI.Section
// SwiftUI.Section is generic (Section<Parent, Content, Footer>) so bare 'Section'
// should resolve to the VideoTaggingCore type, but explicit typealias prevents
// any ambiguity errors when SwiftUI is also imported.
import VideoTaggingCore
typealias VideoSection = Section
