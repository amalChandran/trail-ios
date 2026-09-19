# Try the iOS example

Run `./scripts/run-ios.sh`, or open `Examples/TrailPlayground.xcodeproj` and choose an iPhone simulator. The app consumes this repository’s root Swift package. MapKit needs no API key.

Open **Map journeys →** and switch between Flight, Cab and Ferry. Compare Full route, Two points, Arc and Great circle. Pause, scrub and move the map in alternating directions. Tap **Try loading arc → route** to see bundled directions resolve, morph and start the vehicle. Try reduced motion and background/resume.

**API examples →** contains runnable integration snippets, including custom plugins, layers, sequences and native map content. [Compiled source examples](examples/iOS.md) · [Native recording](media/README.md) · [Verification](VERIFICATION.md)

Trail Studio is a local example app, not an App Store release. These are illustrative journeys, not live navigation or passenger booking. A physical iPhone uses your normal Xcode development signing setup; the simulator needs no developer-account signing configuration.
