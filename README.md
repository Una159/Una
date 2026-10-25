# Feature modules — implementation backlog

Each feature should be implemented in its own source file and only activate when its config key is enabled. Do not mark a feature implemented until it has been tested against the target Douyin 40.8.0 build.

- Video UI and save flow
- Interface theme and element visibility
- Privacy and ad-element filtering
- Comment audio picker
- Message quick reply
- Live compact controls

The starter currently registers these features and persists their toggles; it does not implement their internal behavior.
