# Bundled General MIDI bank

GeneralUser GS SoftSynth v1.44, from the user-provided
GeneralUser_GS_1.44-SoftSynth.zip, inspected on 2026-11-14.

Source: https://www.schristiancollins.com/generaluser.php
The SF2 contents are unchanged; only its filename is normalized for packaging.
The original GeneralUser-LICENSE.txt is retained in full, including its sample
provenance statements. Exact checksums are in ../../audio-dependencies.lock.json.

The App bundles this file and license. It loads samples once on its VM worker,
shares read-only sample data among streams/channels, and frees each stream's
voices and effects at close. It needs no runtime download. This bank does not
claim to reproduce a specific Nokia/Sony Ericsson handset's proprietary sounds.
