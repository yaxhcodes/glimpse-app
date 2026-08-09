import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/services/ai_proxy_config.dart';
import 'library_entity.dart';

class LibraryPlacesMap extends StatefulWidget {
  const LibraryPlacesMap({
    super.key,
    required this.entities,
    required this.onEntityTapped,
    this.selectedKey,
    this.borderRadius = BorderRadius.zero,
    this.showFitAllControl = true,
    this.showAttribution = true,
    this.attributionBottom = 6,
    this.bottomObstructionFraction,
  });

  final List<LibraryEntity> entities;
  final ValueChanged<LibraryEntity> onEntityTapped;
  final String? selectedKey;
  final BorderRadius borderRadius;
  final bool showFitAllControl;
  final bool showAttribution;
  final double attributionBottom;
  final ValueListenable<double>? bottomObstructionFraction;

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
  static const _mapStyleOverride = String.fromEnvironment(
    'LIBRARY_MAP_STYLE_URL',
  );

  MapLibreMapController? _controller;
  bool _styleLoaded = false;
  bool _timedOut = false;
  Timer? _loadTimer;
  Timer? _obstructionTimer;

  List<LibraryEntity> get _mapped => widget.entities
      .where((entity) => entity.mention.hasCoordinates)
      .toList(growable: false);

  String get _styleUrl => _mapStyleOverride.isNotEmpty
      ? _mapStyleOverride
      : '${AiProxyConfig.baseUrl}/library-map/style.json';

  @override
  void initState() {
    super.initState();
    _loadTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && !_styleLoaded) setState(() => _timedOut = true);
    });
    widget.bottomObstructionFraction?.addListener(_handleObstructionChanged);
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
      if (widget.selectedKey != null) {
        unawaited(_focus(widget.selectedKey!));
      }
    }
    if (_styleLoaded && oldWidget.entities != widget.entities) {
      unawaited(_replaceSource());
    }
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
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MapLibreMap(
            styleString: _styleUrl,
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
          if (_timedOut && !_styleLoaded)
            const Positioned.fill(child: _MapFallback()),
          if (widget.showFitAllControl && _mapped.length > 1)
            Positioned(
              top: 12,
              right: 12,
              child: IconButton.filledTonal(
                tooltip: 'Fit all places',
                onPressed: _styleLoaded ? () => unawaited(_fitAll()) : null,
                icon: const Icon(Icons.center_focus_strong_rounded),
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
    final pinColor = _colorHex(colorScheme.tertiary);
    final pinStrokeColor = _colorHex(colorScheme.onTertiary);
    final selectedColor = _colorHex(colorScheme.primary);
    final selectedStrokeColor = _colorHex(colorScheme.onPrimary);
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
          circleColor: pinColor,
          circleRadius: const [
            'step',
            ['get', 'point_count'],
            18,
            8,
            22,
            24,
            28,
          ],
          circleStrokeColor: pinStrokeColor,
          circleStrokeWidth: 2,
        ),
        filter: const ['has', 'point_count'],
        enableInteraction: true,
      );
      await controller.addSymbolLayer(
        _sourceId,
        _clusterCountLayerId,
        const SymbolLayerProperties(
          textField: ['get', 'point_count_abbreviated'],
          textColor: '#FFFFFF',
          textSize: 12,
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
          circleRadius: 9,
          circleStrokeColor: pinStrokeColor,
          circleStrokeWidth: 3,
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
          circleRadius: 13,
          circleStrokeColor: selectedStrokeColor,
          circleStrokeWidth: 4,
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
        top: 48,
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
        top: 32,
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

  Duration _motionDuration(Duration duration) {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation
        ? Duration.zero
        : duration;
  }
}

String _colorHex(Color color) {
  final value = color.toARGB32() & 0x00FFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
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
              Icon(Icons.map_outlined, size: 42, color: cs.onSurfaceVariant),
              const SizedBox(height: 10),
              Text(
                noLocations
                    ? 'No mapped places yet'
                    : 'Map unavailable — your places are still listed below',
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
