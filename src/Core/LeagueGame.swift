import AppKit

/// The League of Legends match client. The launcher has a different bundle identifier.
let leagueGameBundleID = "com.riotgames.LeagueofLegends.GameClient"

@MainActor
func leagueGameIsRunning() -> Bool {
    NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == leagueGameBundleID }
}
