# iOS update delivery

The root `version.json` separates Android (`latest_version`, `latest_build`,
`min_build`, `android_url`) from iOS (`ios_latest_version`, `ios_latest_build`,
`ios_url`). Installed iOS build numbers come from `CFBundleVersion` via
`package_info_plus`. The iOS URL must be an HTTPS page that can actually lead
the user to installation. Leave all three iOS fields empty/zero until that
destination is ready. Android's minimum build never blocks iOS.

When a newer iOS build and a destination exist, NOVA offers a dismissible
launch notice once per iOS release build. About also checks on demand and opens
the destination outside the app. NOVA does not download and install an IPA on
its own, and opening a page is not proof of installation.

`codemagic.yaml` packages `Nova-release-unsigned.ipa` with `--no-codesign` for
iLoader. That archive must be signed before the iPhone can install it. The
desktop iLoader import flow does not provide a verified phone-side install URL;
linking the raw unsigned IPA as `ios_url` would be misleading. For direct
on-device delivery, use a supported signed channel such as TestFlight or a
properly provisioned Ad Hoc/enterprise distribution page with its OTA manifest.
The update can replace an installed app only when its bundle identity and
signing/provisioning remain compatible. A new app binary must be installed once
to add this update-check logic to phones running an older binary.

Before setting iOS metadata, verify the new IPA's `CFBundleShortVersionString`,
`CFBundleVersion`, bundle ID, signing, target-device eligibility and actual
installation on a physical iPhone. The unsigned Codemagic compile alone proves
none of the installation flow.
