# Trek Maps

A Flutter iOS and Android trekking tracker using Mapy.com outdoor map tiles. The
Mapy.com REST API supplies raster tiles; `flutter_map` renders them in a native
Flutter UI. Mapy.com does not provide a Flutter-specific renderer.

## Mapy.com API key

1. Create an API project and key in the [Mapy.com developer portal](https://developer.mapy.com/portal-muj-ucet/).
2. Run the app with the key supplied at build time:

   ```sh
   flutter run --dart-define=MAPY_API_KEY=your_api_key
   ```

   For release builds, pass the same define to `flutter build apk` or
   `flutter build ios`. Do not put a real key in Dart source, committed config,
   or screenshots.

The app uses Mapy.com's `outdoor` tile set and its `/v1/maptiles/{mapset}/256/{z}/{x}/{y}` REST endpoint. The app displays the official Mapy.com logo and required
copyright link over the map. A map key is required to load tiles; without it,
the app shows setup guidance while the trek controls remain available.

An API key embedded in a mobile app can be extracted. Restrict its allowed
services and usage in the Mapy.com portal, monitor its quota, and use a
separate key for development and production. See Mapy.com's [API key security
guide](https://developer.mapy.com/portal-muj-ucet/zabezpeceni-api-klice/) and
[attribution requirements](https://developer.mapy.com/rest-api/atributovani/).

## Trek recording

Tap **Start tracking** and grant foreground location access when prompted.
Pause and resume keep the route and elapsed time; stop leaves the completed
route visible until a new trek starts. Route points and statistics are kept in
memory only. This MVP records while the app is in use; it does not request
background location access or save/export tracks.

The location permission is requested only when tracking starts. If access was
previously blocked, use the app settings action shown by the app.

## Development

```sh
flutter pub get
flutter analyze
flutter test
```
