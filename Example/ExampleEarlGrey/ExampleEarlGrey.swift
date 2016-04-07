import XCTest

class ExampleTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testExample() {
        EarlGrey().selectElementWithMatcher(grey_accessibilityID("t_1"))
            .assertWithMatcher(grey_sufficientlyVisible())
    }
}
