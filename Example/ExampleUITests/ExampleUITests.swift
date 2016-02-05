import XCTest

class ExampleUITests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIApplication().launch()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testExample() {
        let app = XCUIApplication()
        let t1 = app.textFields["t_1"]
        t1.tap()
        t1.typeText("test")
        let t2 = app.textFields["t_2"]
        t2.tap()
        t2.typeText("test")
        let t3 = app.textFields["t_3"]
        t3.tap()
        t3.typeText("test")
    }
}
