import Testing
@testable import Feudalism

struct FeudalismTests {

    @Test func appImports() async throws {
        #expect(BuildCost.zero.stone == 0)
    }
}
