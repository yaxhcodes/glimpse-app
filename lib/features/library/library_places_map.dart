import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../l10n/l10n.dart';
import '../../core/services/ai_proxy_config.dart';
import 'library_entity.dart';
import 'library_map_style.dart';
import 'package:glimpse/shared/theme/app_icons.dart';

class LibraryPlacesMap extends StatefulWidget {
  const LibraryPlacesMap({
    super.key,
    required this.entities,
    required this.onEntityTapped,
    this.selectedKey,
    this.borderRadius = BorderRadius.zero,
    this.showAttribution = true,
    this.attributionBottom = 6,
    this.bottomObstructionFraction,
    this.avoidTopSystemUi = false,
  });

  final List<LibraryEntity> entities;
  final ValueChanged<LibraryEntity> onEntityTapped;
  final String? selectedKey;
  final BorderRadius borderRadius;
  final bool showAttribution;
  final double attributionBottom;
  final ValueListenable<double>? bottomObstructionFraction;
  final bool avoidTopSystemUi;

  @override
  State<LibraryPlacesMap> createState() => _LibraryPlacesMapState();
}

class _LibraryPlacesMapState extends State<LibraryPlacesMap> {
  static const _sourceId = 'glimpse-library-places';
  static const _selectedSourceId = 'glimpse-library-selected-place';
  static const _clusterLayerId = 'glimpse-library-place-clusters';
  static const _clusterCountLayerId = 'glimpse-library-place-counts';
  static const _placeLayerId = 'glimpse-library-place-pins';
  static const _selectedLayerId = 'glimpse-library-selected-pin';
  static const _selectedLabelLayerId = 'glimpse-library-selected-label';
  static const _mapStyleOverride = String.fromEnvironment(
    'LIBRARY_MAP_STYLE_URL',
  );
  static const _darkMapStyleOverride = String.fromEnvironment(
    'LIBRARY_MAP_DARK_STYLE_URL',
  );

  /// Raw provider styles by URL, fetched once per session and recoloured
  /// per theme on device.
  static final Map<String, Future<Map<String, dynamic>?>> _baseStyles = {};
  static final Dio _styleDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      responseType: ResponseType.json,
    ),
  );

  MapLibreMapController? _controller;
  bool _styleLoaded = false;
  bool _timedOut = false;
  Timer? _loadTimer;
  Timer? _obstructionTimer;

  /// The style handed to the map: themed JSON, or the plain URL when the
  /// style could not be fetched. Null until the first one is ready.
  String? _styleString;
  bool _styleIsThemed = false;
  String? _styleSignature;

  List<LibraryEntity> get _mapped => widget.entities
      .where((entity) => entity.mention.hasCoordinates)
      .toList(growable: false);

  String _styleUrl(Brightness brightness) => resolveLibraryMapStyleUrl(
    brightness: brightness,
    baseUrl: AiProxyConfig.baseUrl,
    lightOverride: _mapStyleOverride,
    darkOverride: _darkMapStyleOverride,
  );

  @override
  void initState() {
    super.initState();
    _restartLoadTimer();
    widget.bottomObstructionFraction?.addListener(_handleObstructionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scheme = Theme.of(context).colorScheme;
    final url = _styleUrl(scheme.brightness);
    final palette = LibraryMapPalette.fromScheme(scheme);
    final signature = '$url|${palette.signature}';
    if (signature == _styleSignature) return;
    _styleSignature = signature;
    unawaited(_prepareStyle(url, palette, signature));
  }

  Future<void> _prepareStyle(
    String url,
    LibraryMapPalette palette,
    String signature,
  ) async {
    final base = await _baseStyles.putIfAbsent(url, () => _fetchStyle(url));
    if (base == null) _baseStyles.remove(url);
    if (!mounted || signature != _styleSignature) return;
    final next = base == null
        ? url
        : jsonEncode(themeLibraryMapStyle(base, palette));
    if (next == _styleString) return;
    final reloading = _styleString != null;
    setState(() {
      _styleString = next;
      _styleIsThemed = base != null;
      if (reloading) {
        // The map swaps styles in place and calls onStyleLoaded again.
        _styleLoaded = false;
        _timedOut = false;
      }
    });
    if (reloading) _restartLoadTimer();
  }

  static Future<Map<String, dynamic>?> _fetchStyle(String url) async {
    try {
      final response = await _styleDio.get<Object?>(url);
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Falls back to the provider's own colours by URL.
    }
    return null;
  }

  void _restartLoadTimer() {
    _loadTimer?.cancel();
    _loadTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && !_styleLoaded) setState(() => _timedOut = true);
    });
  }

  @override
  void didUpdateWidget(covariant LibraryPlacesMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bottomObstructionFraction !=
        widget.bottomObstructionFraction) {
      oldWidget.bottomObstructionFraction?.removeListener(
        _handleObstructionChanged,
      );
      widget.bottomObstructionFraction?.addListener(_handleObstructionChanged);
    }
    if (oldWidget.selectedKey != widget.selectedKey) {
      if (_styleLoaded) unawaited(_replaceSource());
      if (widget.selectedKey case final key?) {
        // The camera padding reads this map's size, which is not readable
        // mid-build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.selectedKey == key) unawaited(_focus(key));
        });
      }
    }
    if (_styleLoaded && !_sameEntities(oldWidget.entities, widget.entities)) {
      unawaited(_replaceSourceAndFit());
    }
  }

  bool _sameEntities(
    List<LibraryEntity> previous,
    List<LibraryEntity> current,
  ) {
    // Order-insensitive: the sheet regroups places (by region, as lookups
    // land) without changing which pins are on the map, and a refit on
    // every regroup made the camera lurch.
    if (previous.length != current.length) return false;
    String pin(LibraryEntity entity) =>
        '${entity.key}@${entity.mention.latitude},${entity.mention.longitude}';
    final before = previous.map(pin).toSet();
    return current.every((entity) => before.contains(pin(entity)));
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _obstructionTimer?.cancel();
    widget.bottomObstructionFraction?.removeListener(_handleObstructionChanged);
    _controller?.onFeatureTapped.remove(_handleFeatureTapped);
    super.dispose();
  }

  void _handleObstructionChanged() {
    _obstructionTimer?.cancel();
    _obstructionTimer = Timer(const Duration(milliseconds: 140), () {
      final selectedKey = widget.selectedKey;
      if (mounted && selectedKey != null && _styleLoaded) {
        unawaited(_focus(selectedKey));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_mapped.isEmpty) return const _MapFallback(noLocations: true);
    final styleString = _styleString;
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (styleString != null)
            MapLibreMap(
              styleString: styleString,
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _mapped.first.mention.latitude!,
                  _mapped.first.mention.longitude!,
                ),
                zoom: _mapped.length == 1 ? 11 : 2.5,
              ),
              compassEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              trackCameraPosition: true,
              onMapCreated: (controller) {
                _controller = controller;
                controller.onFeatureTapped.add(_handleFeatureTapped);
              },
              onStyleLoadedCallback: _onStyleLoaded,
            ),
          // Tiles arrive black before the style settles; cover them with the
          // page surface and fade the map in once pins are drawn.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _styleLoaded,
              child: AnimatedOpacity(
                opacity: _styleLoaded ? 0 : 1,
                duration: _motionDuration(const Duration(milliseconds: 420)),
                curve: Curves.easeOutCubic,
                child: _timedOut
                    ? const _MapFallback()
                    : const _MapLoadingSurface(),
              ),
            ),
          ),
          if (widget.showAttribution)
            Positioned(
              right: 8,
              bottom: widget.attributionBottom,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: Text(
                    '© Geoapify · © OpenStreetMap',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onStyleLoaded() async {
    _loadTimer?.cancel();
    final controller = _controller;
    if (controller == null || !mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    final land = LibraryMapPalette.fromScheme(colorScheme).land;
    // primaryContainer sat at the land's tone in dark palettes and the
    // bubbles vanished; the primary hue always stands off the basemap.
    final clusterColor = _colorHex(colorScheme.primary);
    final clusterTextColor = _colorHex(colorScheme.onPrimary);
    final pinColor = _colorHex(colorScheme.primary);
    final pinStrokeColor = _colorHex(land);
    final selectedColor = _colorHex(colorScheme.tertiary);
    final selectedStrokeColor = _colorHex(colorScheme.surface);
    if (!_styleIsThemed) await _preferEnglishLabels(controller);
    try {
      await controller.addSource(
        _sourceId,
        GeojsonSourceProperties(
          data: _geoJson(),
          cluster: true,
          clusterRadius: 52,
          clusterMaxZoom: 13,
          promoteId: 'entity_key',
        ),
      );
      await controller.addSource(
        _selectedSourceId,
        GeojsonSourceProperties(data: _selectedGeoJson()),
      );
      await controller.addCircleLayer(
        _sourceId,
        _clusterLayerId,
        CircleLayerProperties(
          circleColor: clusterColor,
          circleRadius: const [
            'step',
            ['get', 'point_count'],
            16,
            8,
            20,
            24,
            25,
          ],
          circleStrokeColor: pinStrokeColor,
          circleStrokeWidth: 2.5,
        ),
        filter: const ['has', 'point_count'],
        enableInteraction: true,
      );
      await controller.addSymbolLayer(
        _selectedSourceId,
        _selectedLabelLayerId,
        SymbolLayerProperties(
          textField: const ['get', 'title'],
          textColor: _colorHex(colorScheme.onSurface),
          textSize: 12,
          textHaloColor: _colorHex(land),
          textHaloWidth: 2,
          textOffset: const [0, 1.7],
          textAnchor: 'top',
          textAllowOverlap: true,
          // Zoomed out, the pin sits on its own cluster and the name ran
          // through the count ("Na4yn"); the card below names it anyway.
          textOpacity: const [
            'step',
            ['zoom'],
            0,
            5,
            1,
          ],
        ),
      );
      await controller.addSymbolLayer(
        _sourceId,
        _clusterCountLayerId,
        SymbolLayerProperties(
          textField: const ['get', 'point_count_abbreviated'],
          textColor: clusterTextColor,
          textSize: 13,
          textAllowOverlap: true,
        ),
        filter: const ['has', 'point_count'],
        enableInteraction: true,
      );
      await controller.addCircleLayer(
        _sourceId,
        _placeLayerId,
        CircleLayerProperties(
          circleColor: pinColor,
          circleRadius: 7,
          circleStrokeColor: pinStrokeColor,
          circleStrokeWidth: 2.5,
        ),
        filter: const [
          '!',
          ['has', 'point_count'],
        ],
        enableInteraction: true,
      );
      await controller.addCircleLayer(
        _selectedSourceId,
        _selectedLayerId,
        CircleLayerProperties(
          circleColor: selectedColor,
          circleRadius: 10,
          circleStrokeColor: selectedStrokeColor,
          circleStrokeWidth: 3.5,
        ),
        enableInteraction: true,
      );
      if (!mounted) return;
      setState(() {
        _styleLoaded = true;
        _timedOut = false;
      });
      await _fitAll();
    } catch (_) {
      if (mounted) setState(() => _timedOut = true);
    }
  }

  /// The base style labels countries in their own language and script
  /// (ESPAÑA, TÜRKIYE, RÉPUBLIQUE…). A themed style already asks for English
  /// names; the untouched provider style (fetch failed) is fixed up here.
  Future<void> _preferEnglishLabels(MapLibreMapController controller) async {
    const name = libraryMapEnglishName;
    try {
      final ids = await controller.getLayerIds();
      for (final id in ids.whereType<String>()) {
        if (id.startsWith('glimpse-')) continue;
        final lower = id.toLowerCase();
        final isNameLabel =
            lower.startsWith('place') ||
            lower.contains('country') ||
            lower.contains('state') ||
            lower.contains('water_name') ||
            lower.contains('poi');
        if (!isNameLabel) continue;
        try {
          await controller.setLayerProperties(
            id,
            const SymbolLayerProperties(textField: name),
          );
        } catch (_) {
          // Not a symbol layer; leave it as styled.
        }
      }
    } catch (_) {
      // Labels are cosmetic; the pins matter.
    }
  }

  Future<void> _replaceSource() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.setGeoJsonSource(_sourceId, _geoJson());
      await controller.setGeoJsonSource(_selectedSourceId, _selectedGeoJson());
    } catch (_) {
      return;
    }
  }

  Future<void> _replaceSourceAndFit() async {
    await _replaceSource();
    await _fitAll();
  }

  Map<String, dynamic> _geoJson() => {
    'type': 'FeatureCollection',
    'features': [
      for (final entity in _mapped)
        {
          'type': 'Feature',
          'id': entity.key,
          'properties': {'entity_key': entity.key, 'title': entity.title},
          'geometry': {
            'type': 'Point',
            'coordinates': [entity.mention.longitude, entity.mention.latitude],
          },
        },
    ],
  };

  Map<String, dynamic> _selectedGeoJson() {
    final selected = _mapped.where(
      (entity) => entity.key == widget.selectedKey,
    );
    return {
      'type': 'FeatureCollection',
      'features': [
        for (final entity in selected)
          {
            'type': 'Feature',
            'id': entity.key,
            'properties': {'entity_key': entity.key, 'title': entity.title},
            'geometry': {
              'type': 'Point',
              'coordinates': [
                entity.mention.longitude,
                entity.mention.latitude,
              ],
            },
          },
      ],
    };
  }

  void _handleFeatureTapped(
    Point<double> _,
    LatLng location,
    String id,
    String layerId,
    Annotation? _,
  ) {
    if (layerId == _clusterLayerId || layerId == _clusterCountLayerId) {
      final zoom = (_controller?.cameraPosition?.zoom ?? 2) + 2;
      unawaited(
        _controller?.animateCamera(
          CameraUpdate.newLatLngZoom(location, zoom.clamp(0, 16).toDouble()),
          duration: _motionDuration(const Duration(milliseconds: 360)),
        ),
      );
      return;
    }
    if (layerId != _placeLayerId && layerId != _selectedLayerId) return;
    for (final entity in _mapped) {
      if (entity.key == id) {
        widget.onEntityTapped(entity);
        return;
      }
    }
  }

  Future<void> _fitAll() async {
    final controller = _controller;
    if (controller == null || _mapped.isEmpty) return;
    if (_mapped.length == 1) {
      await _focus(_mapped.single.key);
      return;
    }
    var minLat = 90.0;
    var maxLat = -90.0;
    var minLon = 180.0;
    var maxLon = -180.0;
    for (final entity in _mapped) {
      final lat = entity.mention.latitude!;
      final lon = entity.mention.longitude!;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lon < minLon) minLon = lon;
      if (lon > maxLon) maxLon = lon;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLon),
          northeast: LatLng(maxLat, maxLon),
        ),
        left: 48,
        top: _topCameraPadding,
        right: 48,
        bottom: 48 + _bottomObstruction,
      ),
      duration: _motionDuration(const Duration(milliseconds: 450)),
    );
  }

  Future<void> _focus(String key) async {
    final controller = _controller;
    if (controller == null || !_styleLoaded) return;
    LibraryEntity? entity;
    for (final item in _mapped) {
      if (item.key == key) {
        entity = item;
        break;
      }
    }
    if (entity == null) return;
    const focusSpan = 0.04;
    final obstruction = _bottomObstruction;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            entity.mention.latitude! - focusSpan,
            entity.mention.longitude! - focusSpan,
          ),
          northeast: LatLng(
            entity.mention.latitude! + focusSpan,
            entity.mention.longitude! + focusSpan,
          ),
        ),
        left: 32,
        top: _topCameraPadding,
        right: 32,
        bottom: 32 + obstruction,
      ),
      duration: _motionDuration(const Duration(milliseconds: 380)),
    );
  }

  double get _bottomObstruction {
    final fraction = widget.bottomObstructionFraction?.value ?? 0;
    final height = context.size?.height ?? 0;
    return height * fraction.clamp(0, 0.9);
  }

  double get _topCameraPadding => widget.avoidTopSystemUi
      ? MediaQuery.paddingOf(context).top + kToolbarHeight + 24
      : 48;

  Duration _motionDuration(Duration duration) {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation
        ? Duration.zero
        : duration;
  }
}

@visibleForTesting
String resolveLibraryMapStyleUrl({
  required Brightness brightness,
  required String baseUrl,
  String lightOverride = '',
  String darkOverride = '',
}) {
  if (brightness == Brightness.dark && darkOverride.trim().isNotEmpty) {
    return darkOverride.trim();
  }
  if (lightOverride.trim().isNotEmpty) return lightOverride.trim();
  final endpoint = Uri.parse('$baseUrl/library-map/style.json');
  return endpoint
      .replace(
        queryParameters: {
          ...endpoint.queryParameters,
          'theme': brightness == Brightness.dark ? 'dark' : 'light',
        },
      )
      .toString();
}

String _colorHex(Color color) => libraryMapColorHex(color);

class _MapLoadingSurface extends StatelessWidget {
  const _MapLoadingSurface();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerLow);
  }
}

class _MapFallback extends StatelessWidget {
  const _MapFallback({this.noLocations = false});

  final bool noLocations;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.surfaceContainerLow,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.map, size: 42, color: cs.onSurfaceVariant),
              const SizedBox(height: 10),
              Text(
                noLocations
                    ? context.l10n.noMappedPlaces
                    : context.l10n.mapUnavailablePlacesListed,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
