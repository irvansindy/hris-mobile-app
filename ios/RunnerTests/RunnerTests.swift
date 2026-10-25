import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  @MainActor
  func testInactiveSceneDoesNotCoverWhenProtectionIsDisabled() {
    withWindow { protection, window in
      protection.setSceneInactive(true)
      XCTAssertTrue(window.subviews.isEmpty)
    }
  }

  @MainActor
  func testProtectedSceneIsCoveredUntilItBecomesActive() {
    withWindow { protection, window in
      protection.isEnabled = true
      XCTAssertTrue(window.subviews.isEmpty)
      protection.setSceneInactive(true)
      XCTAssertEqual(window.subviews.count, 1)
      XCTAssertEqual(window.subviews.first?.frame, window.bounds)
      protection.setSceneInactive(false)
      XCTAssertTrue(window.subviews.isEmpty)
    }
  }

  @MainActor
  func testDisablingProtectionRemovesInactiveCover() {
    withWindow { protection, window in
      protection.setSceneInactive(true)
      protection.isEnabled = true
      XCTAssertEqual(window.subviews.count, 1)
      protection.isEnabled = false
      XCTAssertTrue(window.subviews.isEmpty)
    }
  }

  @MainActor
  func testRepeatedStateChangesDoNotStackCovers() {
    withWindow { protection, window in
      protection.isEnabled = true
      for _ in 0..<3 {
        protection.setSceneInactive(true)
        protection.setSceneInactive(true)
        protection.isEnabled = true
        XCTAssertEqual(window.subviews.count, 1)
        protection.setSceneInactive(false)
        XCTAssertTrue(window.subviews.isEmpty)
      }
    }
  }

  @MainActor
  private func withWindow(_ assertions: (SensitiveScreenProtection, UIWindow) -> Void) {
    let protection = SensitiveScreenProtection.shared
    protection.isEnabled = false
    protection.setSceneInactive(false)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    protection.bind(window: window)
    defer {
      protection.isEnabled = false
      protection.setSceneInactive(false)
      protection.bind(window: nil)
    }
    assertions(protection, window)
  }
}
