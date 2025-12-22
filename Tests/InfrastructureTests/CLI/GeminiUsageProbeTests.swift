import Testing
import Foundation
import Mockable
@testable import Infrastructure
@testable import Domain

@Suite
struct GeminiUsageProbeTests {
    
    // MARK: - Helpers
    
    private func makeTemporaryHomeDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    private func createCredentialsFile(in homeDirectory: URL, accessToken: String = "test-token") throws {
        let dotGemini = homeDirectory.appendingPathComponent(".gemini")
        try FileManager.default.createDirectory(at: dotGemini, withIntermediateDirectories: true)
        
        let credsURL = dotGemini.appendingPathComponent("oauth_creds.json")
        let json: [String: Any] = [
            "access_token": accessToken,
            "expiry_date": Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: credsURL)
    }
    
    @Test
    func `probe falls back to API when CLI is missing`() async throws {
        // Given
        let homeDir = try makeTemporaryHomeDirectory()
        try createCredentialsFile(in: homeDir)
        let mockService = MockNetworkClient()
        
        // Setup API mocks
        let projectsResponse = """
        { "projects": [{ "projectId": "gen-lang-client-123" }] }
        """.data(using: .utf8)!
        
        let quotaResponse = """
        {
            "buckets": [{
                "modelId": "gemini-pro",
                "remainingFraction": 0.8,
                "resetTime": "2025-12-21T12:00:00Z"
            }]
        }
        """.data(using: .utf8)!
        
        given(mockService)
            .request(.any)
            .willProduce { request in
                let url = request.url?.absoluteString ?? ""
                if url.contains("projects") {
                    return (projectsResponse, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
                } else {
                    return (quotaResponse, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
                }
            }
        
        // Initialize probe with mock network client
        let probe = GeminiUsageProbe(
            homeDirectory: homeDir.path,
            timeout: 1.0,
            networkClient: mockService
        )
        
        // When
        // Assuming 'gemini' CLI is NOT installed in the test environment,
        // it should fail CLI probe and fall back to API.
        let snapshot = try await probe.probe()
        
        // Then
        #expect(snapshot.quotas.count == 1)
        #expect(snapshot.quotas.first?.percentRemaining == 80.0)
        #expect(snapshot.providerId == "gemini")
        
        // Verify API was actually called
        verify(mockService).request(.any).called(2)
    }
}
