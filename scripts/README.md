# Build and release scripts

Run build-ios.sh on macOS with Xcode. verify-source.py checks the pinned source
revisions. package-ipa.py validates a device arm64 binary before packaging.
smoke-core.py checks the actual demo and RMS persistence. publish.ps1 is an
optional manual upload helper that preserves existing repository history.

verify-audio.py validates vendored audio files against audio-dependencies.lock.json.
verify-app-audio.py checks the built .app contains the exact SF2 and notices.
The source archive and publish.ps1 now include third_party and the SF2 bank;
the first Git upload is larger because the bank is about 30 MB.
