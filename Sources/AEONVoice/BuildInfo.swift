import Foundation

/// Build-time metadata injected by the Makefile.
/// The placeholder value is replaced with the real git SHA during `make app`.
enum BuildInfo {
    static let commitSHA = "dev"
}
