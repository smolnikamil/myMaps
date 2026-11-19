# Trek Maps

A Flutter iOS, Android, and web trekking tracker using Mapy.com outdoor map
tiles. The Mapy.com REST API supplies raster tiles; `flutter_map` renders them
in Flutter. Mapy.com does not provide a Flutter-specific renderer.

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

A key included in a mobile app or compiled web bundle can be extracted.
Restrict its allowed services and HTTP referrers (domain and port) in the
Mapy.com portal, monitor its quota, and use separate keys for development and
production. See Mapy.com's [API key security
guide](https://developer.mapy.com/portal-muj-ucet/zabezpeceni-api-klice/) and
[attribution requirements](https://developer.mapy.com/rest-api/atributovani/).

## Web

Run locally in Chrome with:

```sh
flutter run -d chrome --dart-define=MAPY_API_KEY=your_api_key
```

Build static web files with:

```sh
flutter build web --dart-define=MAPY_API_KEY=your_api_key
```

The output is in `build/web`. Serve it from HTTPS in production; browser
geolocation is available only in a secure context. `localhost` is generally
treated as secure for local development. The browser asks for location access
when tracking starts. If access is blocked, allow it in the browser's site
settings and retry. Embedding the app in a cross-origin iframe may also require
the host's Permissions Policy to allow geolocation.

Browser permissions and background-tab behavior are controlled by the browser.
This app records only while in use and does not guarantee location updates
while the page is hidden or the browser is suspended.

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
