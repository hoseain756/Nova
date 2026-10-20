# Android release signing

The repository keeps the debug signing fallback so release builds continue to work without signing credentials. To sign locally with the supplied NOVA upload keystore, copy android/key.properties.example to android/key.properties, set the keystore path, alias, and passwords on your machine, then build with flutter build apk --release. The actual properties file and *.jks files are ignored by Git.

A local ignored android/key.properties is prepared to point to the supplied keystore. Its alias and password fields are deliberately blank because the keystore file alone does not provide those credentials. Gradle uses the upload key only after all required values are present and the keystore exists; otherwise it retains the prior debug signing behavior.

.github/workflows/release.yml analyzes, tests, builds, and stores an APK artifact when a v* tag is pushed or the workflow is started manually. GitHub-hosted runners do not have the local keystore, so their artifact uses the debug fallback. Do not attach that artifact as an update for users whose installed app was signed with another key. A distributable update must be signed with the same upload key as the installed NOVA build; this workflow currently does not publish GitHub Releases or attach assets.
