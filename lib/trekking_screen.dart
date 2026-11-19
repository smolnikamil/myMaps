import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'trekking_metrics.dart';

enum TrekStatus { ready, recording, paused, finished }

class TrekkingScreen extends StatefulWidget {
  const TrekkingScreen({super.key, required this.apiKey});

  final String apiKey;

  @override
  State<TrekkingScreen> createState() => _TrekkingScreenState();
}

class _TrekkingScreenState extends State<TrekkingScreen> {
  static const _initialCenter = LatLng(50.0755, 14.4378);
  static const _mapyLogoUrl = 'https://api.mapy.com/img/api/logo.svg';
  static final _copyrightUri = Uri.parse('https://api.mapy.com/copyright');
  static final _mapyUri = Uri.parse('https://mapy.com/');

  final _mapController = MapController();
  final _stopwatch = Stopwatch();
  final List<LatLng> _route = [];
  StreamSubscription<Position>? _positionSubscription;
  Timer? _ticker;
  TrekStatus _status = TrekStatus.ready;
  Duration _elapsed = Duration.zero;
  double _distanceMeters = 0;
  bool _mapReady = false;
  bool _starting = false;

  bool get _hasApiKey => widget.apiKey.trim().isNotEmpty;

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_positionSubscription?.cancel());
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _startOrResume() async {
    if (_starting) return;
    setState(() => _starting = true);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage(
          'Turn on location services to start tracking.',
          action: SnackBarAction(
            label: 'Settings',
            onPressed: Geolocator.openLocationSettings,
          ),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          'Location access is blocked. Allow it in app settings.',
          action: SnackBarAction(
            label: 'Settings',
            onPressed: Geolocator.openAppSettings,
          ),
        );
        return;
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        _showMessage('Location permission is needed to record a trek.');
        return;
      }

      if (_status != TrekStatus.paused) {
        _route.clear();
        _distanceMeters = 0;
        _elapsed = Duration.zero;
        _stopwatch
          ..reset()
          ..start();
      } else {
        _stopwatch.start();
      }

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 5,
            ),
          ).listen(
            _onPosition,
            onError: (Object error, StackTrace stackTrace) {
              _handleLocationError();
            },
          );
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed = _stopwatch.elapsed);
      });
      setState(() => _status = TrekStatus.recording);
    } on LocationServiceDisabledException {
      _showMessage('Location services are unavailable on this device.');
    } on PermissionDefinitionsNotFoundException {
      _showMessage('Location permission setup is missing from the app.');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _onPosition(Position position) {
    if (!mounted || position.accuracy > 50) return;
    final point = LatLng(position.latitude, position.longitude);

    if (_route.isNotEmpty) {
      final previous = _route.last;
      final segmentMeters = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        point.latitude,
        point.longitude,
      );
      if (segmentMeters < 2) return;
      _distanceMeters += segmentMeters;
    }

    setState(() => _route.add(point));
    if (_mapReady) _mapController.move(point, 15);
  }

  Future<void> _pause() async {
    _ticker?.cancel();
    _stopwatch.stop();
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (mounted) {
      setState(() {
        _elapsed = _stopwatch.elapsed;
        _status = TrekStatus.paused;
      });
    }
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    _stopwatch.stop();
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (mounted) {
      setState(() {
        _elapsed = _stopwatch.elapsed;
        _status = TrekStatus.finished;
      });
    }
  }

  Future<void> _handleLocationError() async {
    await _stop();
    _showMessage('Location updates stopped. Check your device settings.');
  }

  void _showMessage(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  void _centerOnRoute() {
    final point = _route.isNotEmpty ? _route.last : _initialCenter;
    if (_mapReady) _mapController.move(point, 15);
  }

  Future<void> _openUri(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) _showMessage('Could not open ${uri.host}.');
  }

  String get _statusLabel => switch (_status) {
    TrekStatus.ready => 'Ready',
    TrekStatus.recording => 'Recording trek',
    TrekStatus.paused => 'Trek paused',
    TrekStatus.finished => 'Trek finished',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final landscape = constraints.maxWidth > constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(child: _buildMap()),
              SafeArea(
                child: landscape
                    ? _buildLandscapeLayout()
                    : _buildPortraitLayout(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _initialCenter,
        initialZoom: 13,
        minZoom: 3,
        maxZoom: 20,
        onMapReady: () => _mapReady = true,
      ),
      children: [
        if (_hasApiKey)
          TileLayer(
            urlTemplate:
                'https://api.mapy.com/v1/maptiles/outdoor/256/{z}/{x}/{y}'
                '?apikey=${Uri.encodeQueryComponent(widget.apiKey.trim())}&lang=en',
            userAgentPackageName: 'com.smolnikamil.trek_maps',
            maxNativeZoom: 20,
            maxZoom: 20,
          ),
        if (_route.length > 1)
          PolylineLayer(polylines: [buildRoutePolyline(_route)]),
        if (_route.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: _route.last,
                width: 40,
                height: 40,
                child: const _CurrentLocationMarker(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(compact: MediaQuery.sizeOf(context).width < 380),
        const Spacer(),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _MapButton(
              icon: Icons.my_location,
              label: 'Center map',
              onPressed: _centerOnRoute,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildControlPanel(),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        SizedBox(
          width: 340,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: _buildControlPanel(),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildHeader(compact: true),
              const Spacer(),
              _MapButton(
                icon: Icons.my_location,
                label: 'Center map',
                onPressed: _centerOnRoute,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({bool compact = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.terrain, color: Color(0xFF174E3A), size: 25),
              const SizedBox(width: 10),
              const Text(
                'Trek Maps',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              if (!compact) ...[
                const SizedBox(width: 14),
                _StatusBadge(status: _status, label: _statusLabel),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Material(
      color: const Color(0xFFFCFBF7),
      elevation: 10,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_hasApiKey) ...[
              const _MapKeyNotice(),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'DISTANCE',
                    value: formatDistance(_distanceMeters),
                    icon: Icons.route,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'ELAPSED',
                    value: formatElapsed(_elapsed),
                    icon: Icons.timer_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildActions(),
            const SizedBox(height: 12),
            if (_hasApiKey)
              _MapyAttribution(
                onOpenLogo: () => _openUri(_mapyUri),
                onOpenCopyright: () => _openUri(_copyrightUri),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    if (_status == TrekStatus.recording) {
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _pause,
              icon: const Icon(Icons.pause_rounded),
              label: const Text('Pause'),
            ),
          ),
          const SizedBox(width: 12),
          _StopButton(onPressed: _stop),
        ],
      );
    }
    if (_status == TrekStatus.paused) {
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _starting ? null : _startOrResume,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(_starting ? 'Resuming…' : 'Resume'),
            ),
          ),
          const SizedBox(width: 12),
          _StopButton(onPressed: _stop),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _starting ? null : _startOrResume,
        icon: Icon(
          _status == TrekStatus.finished
              ? Icons.add_rounded
              : Icons.play_arrow_rounded,
        ),
        label: Text(
          _starting
              ? 'Getting location…'
              : _status == TrekStatus.finished
              ? 'Start a new trek'
              : 'Start tracking',
        ),
      ),
    );
  }
}

class _MapKeyNotice extends StatelessWidget {
  const _MapKeyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2EC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.map_outlined, color: Color(0xFF174E3A)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Add your Mapy.com API key with MAPY_API_KEY to load the map.',
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9E8E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: const Color(0xFF668275)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF668275),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.label});

  final TrekStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final recording = status == TrekStatus.recording;
    final color = recording ? const Color(0xFFB63D32) : const Color(0xFF174E3A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (recording)
            const _RecordingDot()
          else
            Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingDot extends StatefulWidget {
  const _RecordingDot();

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: const Icon(Icons.circle, size: 8, color: Color(0xFFB63D32)),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.stop_rounded),
      label: const Text('Stop'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFB63D32),
        side: const BorderSide(color: Color(0xFFE8B9B2)),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon, color: const Color(0xFF174E3A)),
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16845B),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 1),
        ],
      ),
    );
  }
}

class _MapyAttribution extends StatelessWidget {
  const _MapyAttribution({
    required this.onOpenLogo,
    required this.onOpenCopyright,
  });

  final VoidCallback onOpenLogo;
  final VoidCallback onOpenCopyright;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Semantics(
          button: true,
          label: 'Mapy.com',
          child: InkWell(
            onTap: onOpenLogo,
            borderRadius: BorderRadius.circular(8),
            child: SvgPicture.network(
              _TrekkingScreenState._mapyLogoUrl,
              height: 32,
              width: 100,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => const SizedBox(
                width: 100,
                height: 32,
                child: _MapyLogoFallback(),
              ),
              errorBuilder: (_, _, _) => const _MapyLogoFallback(),
            ),
          ),
        ),
        TextButton(
          onPressed: onOpenCopyright,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF39483F),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Seznam.cz a.s. a další',
            style: TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _MapyLogoFallback extends StatelessWidget {
  const _MapyLogoFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Mapy.com',
        style: TextStyle(
          color: Color(0xFF174E3A),
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
