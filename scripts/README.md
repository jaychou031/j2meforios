# Build and release scripts

Run build-ios.sh on macOS with Xcode. verify-source.py checks the pinned source
revisions. package-ipa.py validates a device arm64 binary before packaging.
smoke-core.py checks the actual demo and RMS persistence. publish.ps1 is an
optional manual upload helper that preserves existing repository history.
