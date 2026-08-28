# Changelog

All notable changes to Zoomat are documented in this file.

## Unreleased

### Added

- Per-invitation allowed-entry limits, defaulting to one successful scan per scanner phone.
- Scanner-pass invitation card images and QR placement settings.
- Multiple phone numbers per contact and direct WhatsApp chat launching.
- Explicit invitation saving to Photos with guest and event captions.
- Event-level default allowance for additional guests, defaulting to zero.
- Per-invitation guest-allowance overrides for named invitations.
- Guest-allowance details in invitation lists, invitation details, and scanner results.
- VoiceOver announcements that include the effective guest allowance.

### Changed

- Additional-guest allowances no longer have an arbitrary upper limit.
- Guest allowances and entry limits now use distinct labels and explanations.
- Scanner passes support files up to 50 MiB to preserve original invitation card images.
- Named invitations now inherit their event's guest allowance until customized.
- Contact invitation batches can use the event default or one custom allowance.
- User-facing counts use locale-aware number formatting.
- Updated English and Arabic localization for guest allowances and formatted counts.

### Removed

- Stale entries from the string catalog.
