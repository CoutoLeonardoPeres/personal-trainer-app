const String kAppVersionMarker = String.fromEnvironment(
  'APP_VERSION_MARKER',
  defaultValue: '',
);

const String kAppVersionName = String.fromEnvironment(
  'APP_VERSION_NAME',
  defaultValue: '1.0.0',
);

const String kAppBuildNumber = String.fromEnvironment(
  'APP_BUILD_NUMBER',
  defaultValue: '1',
);

String appVersionMarkerLabel() {
  final base = '$kAppVersionName+$kAppBuildNumber';
  final marker = kAppVersionMarker.trim();
  if (marker.isEmpty) return base;
  return '$base • $marker';
}
