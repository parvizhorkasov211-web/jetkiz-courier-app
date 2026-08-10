import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jetkiz_courier_app/core/network/apiClient.dart';
import 'package:jetkiz_courier_app/core/storage/token_storage.dart';

/// Application-wide courier tracking coordinator.
///
/// The backend remains the source of truth for whether a courier may be
/// tracked. The app only starts a GPS stream when the courier is online or has
/// an active delivery. Android uses a foreground location notification so an
/// active delivery can continue to publish positions while the app is in the
/// background.
class CourierTrackingService with WidgetsBindingObserver {
  CourierTrackingService._();

  static final CourierTrackingService instance = CourierTrackingService._();

  final ApiClient _api = ApiClient();
  final TokenStorage _tokenStorage = TokenStorage();

  Timer? _stateTimer;
  StreamSubscription<Position>? _positionSubscription;
  bool _started = false;
  bool _syncingState = false;
  bool _sendingLocation = false;
  DateTime? _lastSentAt;
  Position? _lastSentPosition;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);

    await _syncTrackingState();
    _stateTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _syncTrackingState(),
    );
  }

  Future<void> stop() async {
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _stateTimer?.cancel();
    _stateTimer = null;
    await _stopPositionStream();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncTrackingState());
    }
  }

  Future<void> _syncTrackingState() async {
    if (!_started || _syncingState) return;
    _syncingState = true;

    try {
      final hasSession = await _tokenStorage.hasSession();
      if (!hasSession) {
        await _stopPositionStream();
        return;
      }

      final raw = await _api.get('/couriers/me');
      if (raw is! Map) {
        await _stopPositionStream();
        return;
      }

      final me = Map<String, dynamic>.from(raw);
      final isOnline = me['isOnline'] == true;
      final activeOrders = me['activeOrders'];
      final activeOrder = me['activeOrder'];
      final hasActiveOrder =
          (activeOrders is List && activeOrders.isNotEmpty) ||
          (activeOrder is Map && activeOrder.isNotEmpty);

      if (isOnline || hasActiveOrder) {
        await _ensurePositionStream();
      } else {
        await _stopPositionStream();
      }
    } catch (_) {
      // Network loss must not tear down an already-running active delivery
      // stream. The next state tick or token refresh will reconcile the state.
    } finally {
      _syncingState = false;
    }
  }

  Future<void> _ensurePositionStream() async {
    if (_positionSubscription != null) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final settings = _buildLocationSettings();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) => unawaited(_handlePosition(position)),
      onError: (_) {
        unawaited(_stopPositionStream());
      },
      cancelOnError: false,
    );

    // Do not wait for the first stream event if the OS can provide a current
    // fix immediately.
    try {
      final first = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      ).timeout(const Duration(seconds: 12));
      await _handlePosition(first, force: true);
    } catch (_) {
      // The stream will keep trying.
    }
  }

  LocationSettings _buildLocationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'JETKIZ — курьер на линии',
          notificationText: 'Геопозиция используется для доставки заказов',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }

  Future<void> _handlePosition(Position position, {bool force = false}) async {
    if (_sendingLocation) return;

    final now = DateTime.now();
    final lastSentAt = _lastSentAt;
    final lastPosition = _lastSentPosition;

    final elapsed = lastSentAt == null
        ? const Duration(days: 1)
        : now.difference(lastSentAt);
    final movedMeters = lastPosition == null
        ? double.infinity
        : Geolocator.distanceBetween(
            lastPosition.latitude,
            lastPosition.longitude,
            position.latitude,
            position.longitude,
          );

    // Normally send every 5 seconds. If the courier is stationary, 15 seconds
    // is sufficient to keep the backend freshness window healthy.
    final shouldSend = force ||
        elapsed >= const Duration(seconds: 15) ||
        (elapsed >= const Duration(seconds: 5) && movedMeters >= 10);

    if (!shouldSend) return;

    _sendingLocation = true;
    try {
      await _api.post('/couriers/me/location', {
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        if (position.heading.isFinite && position.heading >= 0)
          'heading': position.heading,
        if (position.speed.isFinite && position.speed >= 0)
          'speed': position.speed,
        'capturedAt': position.timestamp.toUtc().toIso8601String(),
      });

      _lastSentAt = now;
      _lastSentPosition = position;
    } catch (_) {
      // Keep the stream alive; ApiClient already performs one token refresh.
      // State reconciliation will stop tracking if the backend says the courier
      // is no longer online or assigned.
      unawaited(_syncTrackingState());
    } finally {
      _sendingLocation = false;
    }
  }

  Future<void> _stopPositionStream() async {
    final subscription = _positionSubscription;
    _positionSubscription = null;
    if (subscription != null) {
      await subscription.cancel();
    }
    _lastSentAt = null;
    _lastSentPosition = null;
  }
}
