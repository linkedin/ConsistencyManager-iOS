
import XCTest

extension XCTestCase {

    /// Checks for the callback to be the expected value within the given timeout.
    ///
    /// - Parameters:
    ///   - condition: The condition to check for.
    ///   - timeout: The timeout in which the callback should return true.
    ///   - description: A string to display in the test log for this expectation, to help diagnose failures.
    func wait(for condition: @autoclosure @escaping () -> Bool, timeout: TimeInterval, description: String) {
        let end = Date().addingTimeInterval(timeout)
        var value = false
        let closure = { value = condition() }

        while !value && 0 < end.timeIntervalSinceNow {
            if RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.002)) {
                Thread.sleep(forTimeInterval: 0.002)
            }
            closure()
        }

        closure()

        XCTAssertTrue(value, "Timed out waiting for condition: \"\(description)\"", file: #file, line: #line)
    }
}
