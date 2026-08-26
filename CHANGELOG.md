# Changelog

All notable changes to Zoomat are documented in this file.

## Unreleased

### Added

- Event-level default allowance for additional guests, defaulting to zero.
- Per-invitation guest-allowance overrides for named invitations.
- Guest-allowance details in invitation lists, invitation details, and scanner results.
- VoiceOver announcements that include the effective guest allowance.

### Changed

- Named invitations now inherit their event's guest allowance until customized.
- Contact invitation batches can use the event default or one custom allowance.
- User-facing counts use locale-aware number formatting.
- Updated English and Arabic localization for guest allowances and formatted counts.

### Removed

- Per-invitation check-in limits and maximum-reached scanner behavior.
- Stale entries from the string catalog.
