# Parked code

Features set aside during the 2026-09 redesign so the app can focus on the core loop
(scan a scene → pick words at your level → daily planned review).

This folder sits **outside** the `SnapLingo/` file-system-synchronized group, so nothing
here is compiled. It is kept for reference; git history (`wip: snapshot before redesign`)
has the exact working versions.

| What | Files | Why parked |
| --- | --- | --- |
| Word books (词书): publish, subscribe, discover, creator profiles | `Views/Collections`, `Views/Discover`, `Models/CollectionModels.swift`, `Utilities/Collection*.swift`, `Utilities/UserScopedCollections.swift`, `Views/CollectionReviewView.swift` | Local-only "social" layer with no backend; it duplicated word + SRS state and overwrote review progress on every launch. |
| Sign in with Apple | `Views/Auth`, `ViewModels/AuthManager.swift`, `Models/UserProfile.swift`, `Utilities/KeychainHelper.swift` | No backend to sign in to. Data is local; multi-device sync should come from SwiftData + CloudKit instead. |
| Old library / API-key screens | `Views/LibraryView.swift`, `Views/DayDetailSheet.swift`, `Views/APIKeySetupView.swift`, `ViewModels/LibraryViewModel.swift` | Already unused before the redesign. |

## Bringing something back

1. Move the files back under `SnapLingo/` (Xcode picks them up automatically).
2. Port them to the current models: there is a single `VocabWord` (SRS state lives on it)
   and a `Scan` model for scenes; there is no `ownerUserID` any more.
3. Word books would need a real backend (or CloudKit shared database) to be meaningful.
