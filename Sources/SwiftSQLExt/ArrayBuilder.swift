/// Allows creation of SwiftUI-style arrays using a closure. Watch this
/// [WWDC session](https://developer.apple.com/videos/play/wwdc2021/10253/) showing how it works.
///
/// ```
/// Array<String> {
///   "1"
///   "2"
///   let trueCondition = true || Bool.random()
///   if trueCondition {
///     "maybe 3"
///   }
///   let falseCondition = false && Bool.random()
///   if falseCondition {
///     "maybe 4"
///   }
///   for i in (5...7) {
///     "loop \(i)"
///   }
///   Optional<String>.none
///   Optional<String>.some("unwrapped 8")
/// }
/// ```
/// Result:
/// ```
/// ["1", "2", "maybe 3", "loop 5", "loop 6", "loop 7", "unwrapped 8"]
/// ```
@resultBuilder
public enum ArrayBuilder<Element> {
    public typealias Expression = Element
    public typealias Component = [Element]
    
    // General
    public static func buildPartialBlock(first: Never) -> Component { }
    public static func buildBlock() -> [Element] {
        []
    }
    public static func buildExpression(_ expression: Expression) -> Component {
        [expression]
    }
    public static func buildBlock(_ component: Component) -> Component {
        component
    }
    
    // Optionals
    public static func buildOptional(_ children: Component?) -> Component {
        children ?? []
    }
    public static func buildExpression(_ expression: Expression?) -> Component {
        expression.map { [$0] } ?? []
    }
    
    // Logic
    public static func buildIf(_ element: Component?) -> Component {
        element ?? []
    }
    public static func buildEither(first child: Component) -> Component {
        child
    }
    public static func buildEither(second child: Component) -> Component {
        child
    }
    public static func buildPartialBlock(first: Void) -> Component {
        []
    }
    public static func buildPartialBlock(first: Expression) -> Component {
        [first]
    }
    public static func buildPartialBlock(first: Component) -> Component {
        first
    }
    
    
    // Loops
    public static func buildArray(_ components: [Component]) -> Component {
        components.flatMap { $0 }
    }
    public static func buildBlock(_ children: Component...) -> Component {
        children.flatMap { $0 }
    }
    public static func buildPartialBlock(accumulated: Component, next: Expression) -> Component {
        accumulated + [next]
    }
    public static func buildPartialBlock(accumulated: Component, next: Component) -> Component {
        accumulated + next
    }
}

//public extension Array {
//    init(@ArrayBuilder<Element> makeItems: Factory<[Element]>) {
//        self.init(makeItems())
//    }
//}
