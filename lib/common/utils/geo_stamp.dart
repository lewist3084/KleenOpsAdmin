// geo_stamp.dart
//
// Best-effort geolocation capture for clock-in/out and task join/exit stamps.
// Returns null silently when permissions are missing or the device cannot
// provide a fix within the timeout.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin port: the `geolocator` plugin isn't a dependency of the admin app,
/// so geo-stamping is disabled here. The kleenops version captures the
/// device position; in admin we degrade to no fix (task join/exit stamps
/// simply omit `geoIn`/`geoOut`). Returns `null` always.
Future<GeoPoint?> captureGeoStamp() async => null;
