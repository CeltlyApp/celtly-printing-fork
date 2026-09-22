# Celtly Printing fork

Based on the published `printing` 5.14.2 package from David PHAM-VAN's
`DavBfr/dart_pdf` project. Original package metadata, LICENSE and copyright
notices are retained. The package root is this repository's root.

This narrowly scoped fork adds `celtlyShareFile` to the existing
`net.nfet.printing` method channel on iOS and Android. It shares an already
closed, size/SHA-256-verified private PDF supplied by the calling application.
It performs no second native file write and never deletes exposed files.

Arguments: `path` (canonical private PDF path), `bytes` (expected positive
length, at most 80 MiB), `sha256` (64 lowercase hex), and popover `x/y/w/h`.
The caller must verify the file hash immediately before invocation and retain
the immutable file while external consumption remains unknown. Native checks
also enforce the dedicated private root, filename, size and readability.

Results are `unknown` (no downstream delivery claim) or `cancelled` (iOS).
Invocation/readiness failures return sanitized platform errors. Android
chooser completion does not establish receiver consumption or cancellation.
The plugin does not claim eventual delivery or make cache retention guarantees
against OS eviction. Existing Printing APIs remain unchanged; callers must use
the new verified-file method to obtain this contract.

Only five native files differ from upstream: the added iOS/Android
`CeltlyShareFile` helpers, both platform `PrintingPlugin` files and Android
`PrintingHandler`. Manifests, identifiers, entitlements, podspecs, Gradle files,
the public Dart library and dependency versions are unchanged.

Consumers must pin an exact commit SHA. Private build authentication belongs
in the build environment's credential store, never in this package, dependency
URL or generated application output. Native platform builds and device
acceptance remain required; publication alone is not native certification.
