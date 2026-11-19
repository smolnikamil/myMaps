import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

double calculateRouteDistance(Iterable<LatLng> points) {
  final iterator = points.iterator;
  if (!iterator.moveNext()) return 0;

  var previous = iterator.current;
  var distance = 0.0;
  while (iterator.moveNext()) {
    final current = iterator.current;
    distance += Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
    previous = current;
  }
  return distance;
}

String formatElapsed(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String formatDistance(double distanceMeters) {
  if (distanceMeters >= 1000) {
    return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
  }
  return '${distanceMeters.round()} m';
}

Polyline buildRoutePolyline(List<LatLng> points) {
  return Polyline(
    points: points,
    strokeWidth: 5,
    color: const Color(0xFF16845B),
    borderStrokeWidth: 2,
    borderColor: const Color(0xFFFFFFFF),
  );
}
