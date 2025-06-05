// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

export 'dart:ui' show Offset, Size, TextDirection, VoidCallback;

export 'package:flutter/gestures.dart' show PointerEvent;

/// See: [PlatformViewsService] in `src/services/platform_view.dart`
class PlatformViewsServiceELinux {
  PlatformViewsServiceELinux._() {
    SystemChannels.platform_views.setMethodCallHandler(_onMethodCall);
  }

  static final PlatformViewsServiceELinux _instance = PlatformViewsServiceELinux._();

  Future<void> _onMethodCall(MethodCall call) {
    switch (call.method) {
      case 'viewFocused':
        final int id = call.arguments as int;
        if (_focusCallbacks.containsKey(id)) {
          _focusCallbacks[id]!();
        }
        break;
      default:
        throw UnimplementedError(
            "${call.method} was invoked but isn't implemented by PlatformViewsService");
    }
    return Future<void>.value();
  }

  /// Maps platform view IDs to focus callbacks.
  ///
  /// The callbacks are invoked when the platform view asks to be focused.
  final Map<int, VoidCallback> _focusCallbacks = <int, VoidCallback>{};

  /// {@template flutter.services.PlatformViewsService.initELinuxView}
  /// Creates a controller for a new ELinux view.
  ///
  /// `id` is an unused unique identifier generated with [platformViewsRegistry].
  ///
  /// `viewType` is the identifier of the ELinux view type to be created, a
  /// factory for this view type must have been registered on the platform side.
  /// Platform view factories are typically registered by plugin code.
  /// Plugins can register a platform view factory with
  /// [PlatformViewRegistry#registerViewFactory](/javadoc/io/flutter/plugin/platform/PlatformViewRegistry.html#registerViewFactory-java.lang.String-io.flutter.plugin.platform.PlatformViewFactory-).
  ///
  /// `creationParams` will be passed as the args argument of [PlatformViewFactory#create](/javadoc/io/flutter/plugin/platform/PlatformViewFactory.html#create-ELinux.content.Context-int-java.lang.Object-)
  ///
  /// `creationParamsCodec` is the codec used to encode `creationParams` before sending it to the
  /// platform side. It should match the codec passed to the constructor of [PlatformViewFactory](/javadoc/io/flutter/plugin/platform/PlatformViewFactory.html#PlatformViewFactory-io.flutter.plugin.common.MessageCodec-).
  /// This is typically one of: [StandardMessageCodec], [JSONMessageCodec], [StringCodec], or [BinaryCodec].
  ///
  /// `onFocus` is a callback that will be invoked when the ELinux View asks to get the
  /// input focus.
  ///
  /// The ELinux view will only be created after [ELinuxViewController.setSize] is called for the
  /// first time.
  ///
  /// The `id, `viewType, and `layoutDirection` parameters must not be null.
  /// If `creationParams` is non null then `creationParamsCodec` must not be null.
  /// {@endtemplate}
  ///
  /// This attempts to use the newest and most efficient platform view
  /// implementation when possible. In cases where that is not supported, it
  /// falls back to using Virtual Display.
  static ELinuxViewController initELinuxView({
    required int id,
    required String viewType,
    required TextDirection layoutDirection,
    dynamic creationParams,
    MessageCodec<dynamic>? creationParamsCodec,
    VoidCallback? onFocus,
  }) {
    assert(creationParams == null || creationParamsCodec != null);

    final TextureELinuxViewController controller = TextureELinuxViewController._(
      viewId: id,
      viewType: viewType,
      layoutDirection: layoutDirection,
      creationParams: creationParams,
      creationParamsCodec: creationParamsCodec,
    );

    _instance._focusCallbacks[id] = onFocus ?? () {};
    return controller;
  }

  /// {@macro flutter.services.PlatformViewsService.initELinuxView}
  ///
  /// This attempts to use the newest and most efficient platform view
  /// implementation when possible. In cases where that is not supported, it
  /// falls back to using Hybrid Composition, which is the mode used by
  /// [initExpensiveELinuxView].
  static SurfaceELinuxViewController initSurfaceELinuxView({
    required int id,
    required String viewType,
    required TextDirection layoutDirection,
    dynamic creationParams,
    MessageCodec<dynamic>? creationParamsCodec,
    VoidCallback? onFocus,
  }) {
    assert(creationParams == null || creationParamsCodec != null);

    final SurfaceELinuxViewController controller = SurfaceELinuxViewController._(
      viewId: id,
      viewType: viewType,
      layoutDirection: layoutDirection,
      creationParams: creationParams,
      creationParamsCodec: creationParamsCodec,
    );
    _instance._focusCallbacks[id] = onFocus ?? () {};
    return controller;
  }

  /// {@macro flutter.services.PlatformViewsService.initELinuxView}
  ///
  /// When this factory is used, the ELinux view and Flutter widgets are
  /// composed at the ELinux view hierarchy level.
  ///
  /// Using this method has a performance cost on devices running ELinux 9 or
  /// earlier, or on underpowered devices. In most situations, you should use
  /// [initELinuxView] or [initSurfaceELinuxView] instead.
  static ExpensiveELinuxViewController initExpensiveELinuxView({
    required int id,
    required String viewType,
    required TextDirection layoutDirection,
    dynamic creationParams,
    MessageCodec<dynamic>? creationParamsCodec,
    VoidCallback? onFocus,
  }) {
    final ExpensiveELinuxViewController controller = ExpensiveELinuxViewController._(
      viewId: id,
      viewType: viewType,
      layoutDirection: layoutDirection,
      creationParams: creationParams,
      creationParamsCodec: creationParamsCodec,
    );

    _instance._focusCallbacks[id] = onFocus ?? () {};
    return controller;
  }

  /// Whether the render surface of the ELinux `FlutterView` should be converted to a `FlutterImageView`.
  @Deprecated(
    'No longer necessary to improve performance. '
    'This feature was deprecated after v2.11.0-0.1.pre.',
  )
  static Future<void> synchronizeToNativeViewHierarchy(bool yes) async {}
}

/// See: [AndroidPointerProperties] in `src/services/platform_view.dart`
class ELinuxPointerProperties {
  /// Creates an [ELinuxPointerProperties] object.
  ///
  /// All parameters must not be null.
  const ELinuxPointerProperties({
    required this.id,
    required this.toolType,
  });

  /// See ELinux's [MotionEvent.PointerProperties#id](https://developer.android.com/reference/android/view/MotionEvent.PointerProperties.html#id).
  final int id;

  /// The type of tool used to make contact such as a finger or stylus, if known.
  /// See ELinux's [MotionEvent.PointerProperties#toolType](https://developer.android.com/reference/android/view/MotionEvent.PointerProperties.html#toolType).
  final int toolType;

  /// Value for `toolType` when the tool type is unknown.
  static const int kToolTypeUnknown = 0;

  /// Value for `toolType` when the tool type is a finger.
  static const int kToolTypeFinger = 1;

  /// Value for `toolType` when the tool type is a stylus.
  static const int kToolTypeStylus = 2;

  /// Value for `toolType` when the tool type is a mouse.
  static const int kToolTypeMouse = 3;

  /// Value for `toolType` when the tool type is an eraser.
  static const int kToolTypeEraser = 4;

  List<int> _asList() => <int>[id, toolType];

  @override
  String toString() {
    return '${objectRuntimeType(this, 'ELinuxPointerProperties')}(id: $id, toolType: $toolType)';
  }
}

/// See: [AndroidPointerCoords] in `src/services/platform_view.dart`
class ELinuxPointerCoords {
  /// Creates an ELinuxPointerCoords.
  ///
  /// All parameters must not be null.
  const ELinuxPointerCoords({
    required this.orientation,
    required this.pressure,
    required this.size,
    required this.toolMajor,
    required this.toolMinor,
    required this.touchMajor,
    required this.touchMinor,
    required this.x,
    required this.y,
  });

  /// The orientation of the touch area and tool area in radians clockwise from vertical.
  ///
  /// See ELinux's [MotionEvent.PointerCoords#orientation](https://developer.android.com/reference/android/view/MotionEvent.PointerCoords.html#orientation).
  final double orientation;

  /// A normalized value that describes the pressure applied to the device by a finger or other tool.
  ///
  /// See ELinux's [MotionEvent.PointerCoords#pressure](https://developer.android.com/reference/android/view/MotionEvent.PointerCoords.html#pressure).
  final double pressure;

  /// A normalized value that describes the approximate size of the pointer touch area in relation to the maximum detectable size of the device.
  ///
  /// See ELinux's [MotionEvent.PointerCoords#size](https://developer.android.com/reference/android/view/MotionEvent.PointerCoords.html#size).
  final double size;

  /// See ELinux's [MotionEvent.PointerCoords#toolMajor](https://developer.android.com/reference/android/view/MotionEvent.PointerCoords.html#toolMajor).
  final double toolMajor;

  /// See ELinux's [MotionEvent.PointerCoords#toolMinor](https://developer.android.com/reference/android/view/MotionEvent.PointerCoords.html#toolMinor).
  final double toolMinor;

  /// See ELinux's [MotionEvent.PointerCoords#touchMajor](https://developer.android.com/reference/android/view/MotionEvent.PointerCoords.html#touchMajor).
  final double touchMajor;

  /// See ELinux's [MotionEvent.PointerCoords#touchMinor](https://developer.android.com/reference/android/view/MotionEvent.PointerCoords.html#touchMinor).
  final double touchMinor;

  /// The X component of the pointer movement.
  ///
  /// See ELinux's [MotionEvent.PointerCoords#x](https://developer.android.com/reference/android/view/MotionEvent.PointerCoords.html#x).
  final double x;

  /// The Y component of the pointer movement.
  ///
  /// See ELinux's [MotionEvent.PointerCoords#y](https://developer.android.com/reference/android/view/MotionEvent.PointerCoords.html#y).
  final double y;

  List<double> _asList() {
    return <double>[
      orientation,
      pressure,
      size,
      toolMajor,
      toolMinor,
      touchMajor,
      touchMinor,
      x,
      y,
    ];
  }

  @override
  String toString() {
    return '${objectRuntimeType(this, 'ELinuxPointerCoords')}(orientation: $orientation, pressure: $pressure, size: $size, toolMajor: $toolMajor, toolMinor: $toolMinor, touchMajor: $touchMajor, touchMinor: $touchMinor, x: $x, y: $y)';
  }
}

/// See: [AndroidMotionEvent] in `src/services/platform_view.dart`
class ELinuxMotionEvent {
  /// Creates an ELinuxMotionEvent.
  ///
  /// All parameters must not be null.
  ELinuxMotionEvent({
    required this.downTime,
    required this.eventTime,
    required this.action,
    required this.pointerCount,
    required this.pointerProperties,
    required this.pointerCoords,
    required this.metaState,
    required this.buttonState,
    required this.xPrecision,
    required this.yPrecision,
    required this.deviceId,
    required this.edgeFlags,
    required this.source,
    required this.flags,
    required this.motionEventId,
  })  : assert(pointerProperties.length == pointerCount),
        assert(pointerCoords.length == pointerCount);

  /// The time (in ms) when the user originally pressed down to start a stream of position events,
  /// relative to an arbitrary timeline.
  ///
  /// See ELinux's [MotionEvent#getDownTime](https://developer.android.com/reference/android/view/MotionEvent.html#getDownTime()).
  final int downTime;

  /// The time this event occurred, relative to an arbitrary timeline.
  ///
  /// See ELinux's [MotionEvent#getEventTime](https://developer.android.com/reference/android/view/MotionEvent.html#getEventTime()).
  final int eventTime;

  /// A value representing the kind of action being performed.
  ///
  /// See ELinux's [MotionEvent#getAction](https://developer.android.com/reference/android/view/MotionEvent.html#getAction()).
  final int action;

  /// The number of pointers that are part of this event.
  /// This must be equivalent to the length of `pointerProperties` and `pointerCoords`.
  ///
  /// See ELinux's [MotionEvent#getPointerCount](https://developer.android.com/reference/android/view/MotionEvent.html#getPointerCount()).
  final int pointerCount;

  /// List of [ELinuxPointerProperties] for each pointer that is part of this event.
  final List<ELinuxPointerProperties> pointerProperties;

  /// List of [ELinuxPointerCoords] for each pointer that is part of this event.
  final List<ELinuxPointerCoords> pointerCoords;

  /// The state of any meta / modifier keys that were in effect when the event was generated.
  ///
  /// See ELinux's [MotionEvent#getMetaState](https://developer.android.com/reference/android/view/MotionEvent.html#getMetaState()).
  final int metaState;

  /// The state of all buttons that are pressed such as a mouse or stylus button.
  ///
  /// See ELinux's [MotionEvent#getButtonState](https://developer.android.com/reference/android/view/MotionEvent.html#getButtonState()).
  final int buttonState;

  /// The precision of the X coordinates being reported, in physical pixels.
  ///
  /// See ELinux's [MotionEvent#getXPrecision](https://developer.android.com/reference/android/view/MotionEvent.html#getXPrecision()).
  final double xPrecision;

  /// The precision of the Y coordinates being reported, in physical pixels.
  ///
  /// See ELinux's [MotionEvent#getYPrecision](https://developer.android.com/reference/android/view/MotionEvent.html#getYPrecision()).
  final double yPrecision;

  /// See ELinux's [MotionEvent#getDeviceId](https://developer.android.com/reference/android/view/MotionEvent.html#getDeviceId()).
  final int deviceId;

  /// A bit field indicating which edges, if any, were touched by this MotionEvent.
  ///
  /// See ELinux's [MotionEvent#getEdgeFlags](https://developer.android.com/reference/android/view/MotionEvent.html#getEdgeFlags()).
  final int edgeFlags;

  /// The source of this event (e.g a touchpad or stylus).
  ///
  /// See ELinux's [MotionEvent#getSource](https://developer.android.com/reference/android/view/MotionEvent.html#getSource()).
  final int source;

  /// See ELinux's [MotionEvent#getFlags](https://developer.android.com/reference/android/view/MotionEvent.html#getFlags()).
  final int flags;

  /// Used to identify this [MotionEvent](https://developer.android.com/reference/android/view/MotionEvent.html) uniquely in the Flutter Engine.
  final int motionEventId;

  List<dynamic> _asList(int viewId) {
    return <dynamic>[
      viewId,
      downTime,
      eventTime,
      action,
      pointerCount,
      pointerProperties.map<List<int>>((ELinuxPointerProperties p) => p._asList()).toList(),
      pointerCoords.map<List<double>>((ELinuxPointerCoords p) => p._asList()).toList(),
      metaState,
      buttonState,
      xPrecision,
      yPrecision,
      deviceId,
      edgeFlags,
      source,
      flags,
      motionEventId,
    ];
  }

  @override
  String toString() {
    return 'ELinuxPointerEvent(downTime: $downTime, eventTime: $eventTime, action: $action, pointerCount: $pointerCount, pointerProperties: $pointerProperties, pointerCoords: $pointerCoords, metaState: $metaState, buttonState: $buttonState, xPrecision: $xPrecision, yPrecision: $yPrecision, deviceId: $deviceId, edgeFlags: $edgeFlags, source: $source, flags: $flags, motionEventId: $motionEventId)';
  }
}

/// See: [_AndroidViewState] in `src/services/platform_view.dart`
enum _ELinuxViewState {
  waitingForSize,
  creating,
  created,
  disposed,
}

/// See: [_AndroidMotionEventConverter] in `src/services/platform_view.dart`
class _ELinuxMotionEventConverter {
  _ELinuxMotionEventConverter();

  final Map<int, ELinuxPointerCoords> pointerPositions = <int, ELinuxPointerCoords>{};
  final Map<int, ELinuxPointerProperties> pointerProperties = <int, ELinuxPointerProperties>{};
  final Set<int> usedELinuxPointerIds = <int>{};

  late PointTransformer pointTransformer;

  int? downTimeMillis;

  void handlePointerDownEvent(PointerDownEvent event) {
    if (pointerProperties.isEmpty) {
      downTimeMillis = event.timeStamp.inMilliseconds;
    }
    int ELinuxPointerId = 0;
    while (usedELinuxPointerIds.contains(ELinuxPointerId)) {
      ELinuxPointerId++;
    }
    usedELinuxPointerIds.add(ELinuxPointerId);
    pointerProperties[event.pointer] = propertiesFor(event, ELinuxPointerId);
  }

  void updatePointerPositions(PointerEvent event) {
    final Offset position = pointTransformer(event.position);
    pointerPositions[event.pointer] = ELinuxPointerCoords(
      orientation: event.orientation,
      pressure: event.pressure,
      size: event.size,
      toolMajor: event.radiusMajor,
      toolMinor: event.radiusMinor,
      touchMajor: event.radiusMajor,
      touchMinor: event.radiusMinor,
      x: position.dx,
      y: position.dy,
    );
  }

  void _remove(int pointer) {
    pointerPositions.remove(pointer);
    usedELinuxPointerIds.remove(pointerProperties[pointer]!.id);
    pointerProperties.remove(pointer);
    if (pointerProperties.isEmpty) {
      downTimeMillis = null;
    }
  }

  void handlePointerUpEvent(PointerUpEvent event) {
    _remove(event.pointer);
  }

  void handlePointerCancelEvent(PointerCancelEvent event) {
    // The pointer cancel event is handled like pointer up. Normally,
    // the difference is that pointer cancel doesn't perform any action,
    // but in this case neither up or cancel perform any action.
    _remove(event.pointer);
  }

  ELinuxMotionEvent? toELinuxMotionEvent(PointerEvent event) {
    final List<int> pointers = pointerPositions.keys.toList();
    final int pointerIdx = pointers.indexOf(event.pointer);
    final int numPointers = pointers.length;

    // This value must match the value in engine's FlutterView.java.
    // This flag indicates whether the original ELinux pointer events were batched together.
    const int kPointerDataFlagBatched = 1;

    // ELinux MotionEvent objects can batch information on multiple pointers.
    // Flutter breaks these such batched events into multiple PointerEvent objects.
    // When there are multiple active pointers we accumulate the information for all pointers
    // as we get PointerEvents, and only send it to the embedded ELinux view when
    // we see the last pointer. This way we achieve the same batching as ELinux.
    if (event.platformData == kPointerDataFlagBatched ||
        (isSinglePointerAction(event) && pointerIdx < numPointers - 1)) {
      return null;
    }

    final int action;
    if (event is PointerDownEvent) {
      action = numPointers == 1
          ? ELinuxViewController.kActionDown
          : ELinuxViewController.pointerAction(pointerIdx, ELinuxViewController.kActionPointerDown);
    } else if (event is PointerUpEvent) {
      action = numPointers == 1
          ? ELinuxViewController.kActionUp
          : ELinuxViewController.pointerAction(pointerIdx, ELinuxViewController.kActionPointerUp);
    } else if (event is PointerMoveEvent) {
      action = ELinuxViewController.kActionMove;
    } else if (event is PointerCancelEvent) {
      action = ELinuxViewController.kActionCancel;
    } else {
      return null;
    }

    return ELinuxMotionEvent(
      downTime: downTimeMillis!,
      eventTime: event.timeStamp.inMilliseconds,
      action: action,
      pointerCount: pointerPositions.length,
      pointerProperties:
          pointers.map<ELinuxPointerProperties>((int i) => pointerProperties[i]!).toList(),
      pointerCoords: pointers.map<ELinuxPointerCoords>((int i) => pointerPositions[i]!).toList(),
      metaState: 0,
      buttonState: 0,
      xPrecision: 1.0,
      yPrecision: 1.0,
      deviceId: 0,
      edgeFlags: 0,
      source: 0,
      flags: 0,
      motionEventId: event.embedderId,
    );
  }

  ELinuxPointerProperties propertiesFor(PointerEvent event, int pointerId) {
    int toolType = ELinuxPointerProperties.kToolTypeUnknown;
    switch (event.kind) {
      case PointerDeviceKind.touch:
      case PointerDeviceKind.trackpad:
        toolType = ELinuxPointerProperties.kToolTypeFinger;
        break;
      case PointerDeviceKind.mouse:
        toolType = ELinuxPointerProperties.kToolTypeMouse;
        break;
      case PointerDeviceKind.stylus:
        toolType = ELinuxPointerProperties.kToolTypeStylus;
        break;
      case PointerDeviceKind.invertedStylus:
        toolType = ELinuxPointerProperties.kToolTypeEraser;
        break;
      case PointerDeviceKind.unknown:
        toolType = ELinuxPointerProperties.kToolTypeUnknown;
        break;
    }
    return ELinuxPointerProperties(id: pointerId, toolType: toolType);
  }

  bool isSinglePointerAction(PointerEvent event) =>
      event is! PointerDownEvent && event is! PointerUpEvent;
}

/// See: [_CreationParams] in `src/services/platform_view.dart`
class _CreationParams {
  const _CreationParams(this.data, this.codec);
  final dynamic data;
  final MessageCodec<dynamic> codec;
}

/// See: [AndroidViewController] in `src/services/platform_view.dart`
abstract class ELinuxViewController extends PlatformViewController {
  ELinuxViewController._({
    required this.viewId,
    required String viewType,
    required TextDirection layoutDirection,
    dynamic creationParams,
    MessageCodec<dynamic>? creationParamsCodec,
  })  : assert(creationParams == null || creationParamsCodec != null),
        _viewType = viewType,
        _layoutDirection = layoutDirection,
        _creationParams =
            creationParams == null ? null : _CreationParams(creationParams, creationParamsCodec!);

  /// Action code for when a primary pointer touched the screen.
  ///
  /// ELinux's [MotionEvent.ACTION_DOWN](https://developer.android.com/reference/android/view/MotionEvent#ACTION_DOWN)
  static const int kActionDown = 0;

  /// Action code for when a primary pointer stopped touching the screen.
  ///
  /// ELinux's [MotionEvent.ACTION_UP](https://developer.android.com/reference/android/view/MotionEvent#ACTION_UP)
  static const int kActionUp = 1;

  /// Action code for when the event only includes information about pointer movement.
  ///
  /// ELinux's [MotionEvent.ACTION_MOVE](https://developer.android.com/reference/android/view/MotionEvent#ACTION_MOVE)
  static const int kActionMove = 2;

  /// Action code for when a motion event has been canceled.
  ///
  /// ELinux's [MotionEvent.ACTION_CANCEL](https://developer.android.com/reference/android/view/MotionEvent#ACTION_CANCEL)
  static const int kActionCancel = 3;

  /// Action code for when a secondary pointer touched the screen.
  ///
  /// ELinux's [MotionEvent.ACTION_POINTER_DOWN](https://developer.android.com/reference/android/view/MotionEvent#ACTION_POINTER_DOWN)
  static const int kActionPointerDown = 5;

  /// Action code for when a secondary pointer stopped touching the screen.
  ///
  /// ELinux's [MotionEvent.ACTION_POINTER_UP](https://developer.android.com/reference/android/view/MotionEvent#ACTION_POINTER_UP)
  static const int kActionPointerUp = 6;

  /// ELinux's [View.LAYOUT_DIRECTION_LTR](https://developer.android.com/reference/android/view/View.html#LAYOUT_DIRECTION_LTR) value.
  static const int kELinuxLayoutDirectionLtr = 0;

  /// ELinux's [View.LAYOUT_DIRECTION_RTL](https://developer.android.com/reference/android/view/View.html#LAYOUT_DIRECTION_RTL) value.
  static const int kELinuxLayoutDirectionRtl = 1;

  /// The unique identifier of the ELinux view controlled by this controller.
  @override
  final int viewId;

  final String _viewType;

  // Helps convert PointerEvents to ELinuxMotionEvents.
  final _ELinuxMotionEventConverter _motionEventConverter = _ELinuxMotionEventConverter();

  TextDirection _layoutDirection;

  _ELinuxViewState _state = _ELinuxViewState.waitingForSize;

  final _CreationParams? _creationParams;

  final List<PlatformViewCreatedCallback> _platformViewCreatedCallbacks =
      <PlatformViewCreatedCallback>[];

  static int _getELinuxDirection(TextDirection direction) {
    switch (direction) {
      case TextDirection.ltr:
        return kELinuxLayoutDirectionLtr;
      case TextDirection.rtl:
        return kELinuxLayoutDirectionRtl;
    }
  }

  /// Creates a masked ELinux MotionEvent action value for an indexed pointer.
  static int pointerAction(int pointerId, int action) {
    return ((pointerId << 8) & 0xff00) | (action & 0xff);
  }

  /// Sends the message to dispose the platform view.
  Future<void> _sendDisposeMessage();

  /// True if [_sendCreateMessage] can only be called with a non-null size.
  bool get _createRequiresSize;

  /// Sends the message to create the platform view with an initial [size].
  ///
  /// If [_createRequiresSize] is true, `size` is non-nullable, and the call
  /// should instead be deferred until the size is available.
  Future<void> _sendCreateMessage({required covariant Size? size, Offset? position});

  /// Sends the message to resize the platform view to [size].
  Future<Size> _sendResizeMessage(Size size);

  @override
  bool get awaitingCreation => _state == _ELinuxViewState.waitingForSize;

  @override
  Future<void> create({Size? size, Offset? position}) async {
    assert(_state != _ELinuxViewState.disposed, 'trying to create a disposed ELinux view');
    assert(_state == _ELinuxViewState.waitingForSize,
        'ELinux view is already sized. View id: $viewId');

    if (_createRequiresSize && size == null) {
      // Wait for a setSize call.
      return;
    }

    _state = _ELinuxViewState.creating;
    await _sendCreateMessage(size: size, position: position);
    _state = _ELinuxViewState.created;

    for (final PlatformViewCreatedCallback callback in _platformViewCreatedCallbacks) {
      callback(viewId);
    }
  }

  /// Sizes the ELinux View.
  ///
  /// [size] is the view's new size in logical pixel, it must not be null and must
  /// be bigger than zero.
  ///
  /// The first time a size is set triggers the creation of the ELinux view.
  ///
  /// Returns the buffer size in logical pixel that backs the texture where the platform
  /// view pixels are written to.
  ///
  /// The buffer size may or may not be the same as [size].
  ///
  /// As a result, consumers are expected to clip the texture using [size], while using
  /// the return value to size the texture.
  Future<Size> setSize(Size size) async {
    assert(_state != _ELinuxViewState.disposed, 'ELinux view is disposed. View id: $viewId');
    if (_state == _ELinuxViewState.waitingForSize) {
      // Either `create` hasn't been called, or it couldn't run due to missing
      // size information, so create the view now.
      await create(size: size);
      return size;
    } else {
      return _sendResizeMessage(size);
    }
  }

  /// Sets the offset of the platform view.
  ///
  /// [off] is the view's new offset in logical pixel.
  ///
  /// On ELinux, this allows the ELinux native view to draw the a11y highlights in the same
  /// location on the screen as the platform view widget in the Flutter framework.
  Future<void> setOffset(Offset off);

  /// Returns the texture entry id that the ELinux view is rendering into.
  ///
  /// Returns null if the ELinux view has not been successfully created, if it has been
  /// disposed, or if the implementation does not use textures.
  int? get textureId;

  /// True if the view requires native view composition rather than using a
  /// texture to render.
  ///
  /// This value may change during [create], but will not change after that
  /// call's future has completed.
  bool get requiresViewComposition => false;

  /// Sends an ELinux [MotionEvent](https://developer.android.com/reference/android/view/MotionEvent)
  /// to the view.
  ///
  /// The ELinux MotionEvent object is created with [MotionEvent.obtain](https://developer.android.com/reference/android/view/MotionEvent.html#obtain(long,%20long,%20int,%20float,%20float,%20float,%20float,%20int,%20float,%20float,%20int,%20int)).
  /// See documentation of [MotionEvent.obtain](https://developer.android.com/reference/android/view/MotionEvent.html#obtain(long,%20long,%20int,%20float,%20float,%20float,%20float,%20int,%20float,%20float,%20int,%20int))
  /// for description of the parameters.
  ///
  /// See [ELinuxViewController.dispatchPointerEvent] for sending a
  /// [PointerEvent].
  Future<void> sendMotionEvent(ELinuxMotionEvent event) async {
    await SystemChannels.platform_views.invokeMethod<dynamic>(
      'touch',
      event._asList(viewId),
    );
  }

  /// Converts a given point from the global coordinate system in logical pixels
  /// to the local coordinate system for this box.
  ///
  /// This is required to convert a [PointerEvent] to an [ELinuxMotionEvent].
  /// It is typically provided by using [RenderBox.globalToLocal].
  PointTransformer get pointTransformer => _motionEventConverter.pointTransformer;
  set pointTransformer(PointTransformer transformer) {
    _motionEventConverter.pointTransformer = transformer;
  }

  /// Whether the platform view has already been created.
  bool get isCreated => _state == _ELinuxViewState.created;

  /// Adds a callback that will get invoke after the platform view has been
  /// created.
  void addOnPlatformViewCreatedListener(PlatformViewCreatedCallback listener) {
    assert(_state != _ELinuxViewState.disposed);
    _platformViewCreatedCallbacks.add(listener);
  }

  /// Removes a callback added with [addOnPlatformViewCreatedListener].
  void removeOnPlatformViewCreatedListener(PlatformViewCreatedCallback listener) {
    assert(_state != _ELinuxViewState.disposed);
    _platformViewCreatedCallbacks.remove(listener);
  }

  /// The created callbacks that are invoked after the platform view has been
  /// created.
  @visibleForTesting
  List<PlatformViewCreatedCallback> get createdCallbacks => _platformViewCreatedCallbacks;

  /// Sets the layout direction for the ELinux view.
  Future<void> setLayoutDirection(TextDirection layoutDirection) async {
    assert(
      _state != _ELinuxViewState.disposed,
      'trying to set a layout direction for a disposed ELinux view. View id: $viewId',
    );

    if (layoutDirection == _layoutDirection) {
      return;
    }

    _layoutDirection = layoutDirection;

    // If the view was not yet created we just update _layoutDirection and return, as the new
    // direction will be used in _create.
    if (_state == _ELinuxViewState.waitingForSize) {
      return;
    }

    await SystemChannels.platform_views.invokeMethod<void>('setDirection', <String, dynamic>{
      'id': viewId,
      'direction': _getELinuxDirection(layoutDirection),
    });
  }

  /// Converts the [PointerEvent] and sends an ELinux [MotionEvent](https://developer.android.com/reference/android/view/MotionEvent)
  /// to the view.
  ///
  /// This method can only be used if a [PointTransformer] is provided to
  /// [ELinuxViewController.pointTransformer]. Otherwise, an [AssertionError]
  /// is thrown. See [ELinuxViewController.sendMotionEvent] for sending a
  /// `MotionEvent` without a [PointTransformer].
  ///
  /// The ELinux MotionEvent object is created with [MotionEvent.obtain](https://developer.android.com/reference/android/view/MotionEvent.html#obtain(long,%20long,%20int,%20float,%20float,%20float,%20float,%20int,%20float,%20float,%20int,%20int)).
  /// See documentation of [MotionEvent.obtain](https://developer.android.com/reference/android/view/MotionEvent.html#obtain(long,%20long,%20int,%20float,%20float,%20float,%20float,%20int,%20float,%20float,%20int,%20int))
  /// for description of the parameters.
  @override
  Future<void> dispatchPointerEvent(PointerEvent event) async {
    if (event is PointerHoverEvent) {
      return;
    }

    if (event is PointerDownEvent) {
      _motionEventConverter.handlePointerDownEvent(event);
    }

    _motionEventConverter.updatePointerPositions(event);

    final ELinuxMotionEvent? ELinuxEvent = _motionEventConverter.toELinuxMotionEvent(event);

    if (event is PointerUpEvent) {
      _motionEventConverter.handlePointerUpEvent(event);
    } else if (event is PointerCancelEvent) {
      _motionEventConverter.handlePointerCancelEvent(event);
    }

    if (ELinuxEvent != null) {
      await sendMotionEvent(ELinuxEvent);
    }
  }

  /// Clears the focus from the ELinux View if it is focused.
  @override
  Future<void> clearFocus() {
    if (_state != _ELinuxViewState.created) {
      return Future<void>.value();
    }
    return SystemChannels.platform_views.invokeMethod<void>('clearFocus', viewId);
  }

  /// Disposes the ELinux view.
  ///
  /// The [ELinuxViewController] object is unusable after calling this.
  /// The identifier of the platform view cannot be reused after the view is
  /// disposed.
  @override
  Future<void> dispose() async {
    final _ELinuxViewState state = _state;
    _state = _ELinuxViewState.disposed;
    _platformViewCreatedCallbacks.clear();
    PlatformViewsServiceELinux._instance._focusCallbacks.remove(viewId);
    if (state == _ELinuxViewState.creating || state == _ELinuxViewState.created) {
      await _sendDisposeMessage();
    }
  }
}

/// See: [SurfaceAndroidViewController] in `src/services/platform_view.dart`
class SurfaceELinuxViewController extends ELinuxViewController {
  SurfaceELinuxViewController._({
    required super.viewId,
    required super.viewType,
    required super.layoutDirection,
    super.creationParams,
    super.creationParamsCodec,
  }) : super._();

  // By default, assume the implementation will be texture-based.
  _ELinuxViewControllerInternals _internals = _TextureELinuxViewControllerInternals();

  @override
  bool get _createRequiresSize => true;

  @override
  Future<bool> _sendCreateMessage({required Size size, Offset? position}) async {
    assert(!size.isEmpty,
        'trying to create $TextureELinuxViewController without setting a valid size.');

    final dynamic response = await _ELinuxViewControllerInternals.sendCreateMessage(
      viewId: viewId,
      viewType: _viewType,
      hybrid: false,
      hybridFallback: true,
      layoutDirection: _layoutDirection,
      creationParams: _creationParams,
      size: size,
      position: position,
    );
    if (response is int) {
      (_internals as _TextureELinuxViewControllerInternals).textureId = response;
    } else {
      // A null response indicates fallback to Hybrid Composition, so swap out
      // the implementation.
      _internals = _HybridELinuxViewControllerInternals();
    }
    return true;
  }

  @override
  int? get textureId {
    return _internals.textureId;
  }

  @override
  bool get requiresViewComposition {
    return _internals.requiresViewComposition;
  }

  @override
  Future<void> _sendDisposeMessage() {
    return _internals.sendDisposeMessage(viewId: viewId);
  }

  @override
  Future<Size> _sendResizeMessage(Size size) {
    return _internals.setSize(size, viewId: viewId, viewState: _state);
  }

  @override
  Future<void> setOffset(Offset off) {
    return _internals.setOffset(off, viewId: viewId, viewState: _state);
  }
}

/// See: [ExpensiveAndroidViewController] in `src/services/platform_view.dart`
class ExpensiveELinuxViewController extends ELinuxViewController {
  ExpensiveELinuxViewController._({
    required super.viewId,
    required super.viewType,
    required super.layoutDirection,
    super.creationParams,
    super.creationParamsCodec,
  }) : super._();

  final _ELinuxViewControllerInternals _internals = _HybridELinuxViewControllerInternals();

  @override
  bool get _createRequiresSize => false;

  @override
  Future<void> _sendCreateMessage({required Size? size, Offset? position}) async {
    await _ELinuxViewControllerInternals.sendCreateMessage(
      viewId: viewId,
      viewType: _viewType,
      hybrid: true,
      layoutDirection: _layoutDirection,
      creationParams: _creationParams,
      position: position,
    );
  }

  @override
  int? get textureId {
    return _internals.textureId;
  }

  @override
  bool get requiresViewComposition {
    return _internals.requiresViewComposition;
  }

  @override
  Future<void> _sendDisposeMessage() {
    return _internals.sendDisposeMessage(viewId: viewId);
  }

  @override
  Future<Size> _sendResizeMessage(Size size) {
    return _internals.setSize(size, viewId: viewId, viewState: _state);
  }

  @override
  Future<void> setOffset(Offset off) {
    return _internals.setOffset(off, viewId: viewId, viewState: _state);
  }
}

/// See: [TextureAndroidViewController] in `src/services/platform_view.dart`
class TextureELinuxViewController extends ELinuxViewController {
  TextureELinuxViewController._({
    required super.viewId,
    required super.viewType,
    required super.layoutDirection,
    super.creationParams,
    super.creationParamsCodec,
  }) : super._();

  final _TextureELinuxViewControllerInternals _internals = _TextureELinuxViewControllerInternals();

  @override
  bool get _createRequiresSize => true;

  @override
  Future<void> _sendCreateMessage({required Size size, Offset? position}) async {
    assert(!size.isEmpty,
        'trying to create $TextureELinuxViewController without setting a valid size.');

    _internals.textureId = await _ELinuxViewControllerInternals.sendCreateMessage(
      viewId: viewId,
      viewType: _viewType,
      hybrid: false,
      layoutDirection: _layoutDirection,
      creationParams: _creationParams,
      size: size,
      position: position,
    ) as int;
  }

  @override
  int? get textureId {
    return _internals.textureId;
  }

  @override
  bool get requiresViewComposition {
    return _internals.requiresViewComposition;
  }

  @override
  Future<void> _sendDisposeMessage() {
    return _internals.sendDisposeMessage(viewId: viewId);
  }

  @override
  Future<Size> _sendResizeMessage(Size size) {
    return _internals.setSize(size, viewId: viewId, viewState: _state);
  }

  @override
  Future<void> setOffset(Offset off) {
    return _internals.setOffset(off, viewId: viewId, viewState: _state);
  }
}

/// See: [_AndroidViewControllerInternals] in `src/services/platform_view.dart`
abstract class _ELinuxViewControllerInternals {
  // Sends a create message with the given parameters, and returns the result
  // if any.
  //
  // This uses a dynamic return because depending on the mode that is selected
  // on the native side, the return type is different. Callers should cast
  // depending on the possible return types for their arguments.
  static Future<dynamic> sendCreateMessage(
      {required int viewId,
      required String viewType,
      required TextDirection layoutDirection,
      required bool hybrid,
      bool hybridFallback = false,
      _CreationParams? creationParams,
      Size? size,
      Offset? position}) {
    final Map<String, dynamic> args = <String, dynamic>{
      'id': viewId,
      'viewType': viewType,
      'direction': ELinuxViewController._getELinuxDirection(layoutDirection),
      if (hybrid) 'hybrid': hybrid,
      if (size != null) 'width': size.width,
      if (size != null) 'height': size.height,
      if (hybridFallback) 'hybridFallback': hybridFallback,
      if (position != null) 'left': position.dx,
      if (position != null) 'top': position.dy,
    };
    if (creationParams != null) {
      final ByteData paramsByteData = creationParams.codec.encodeMessage(creationParams.data)!;
      args['params'] = Uint8List.view(
        paramsByteData.buffer,
        0,
        paramsByteData.lengthInBytes,
      );
    }
    return SystemChannels.platform_views.invokeMethod<dynamic>('create', args);
  }

  int? get textureId;

  bool get requiresViewComposition;

  Future<Size> setSize(
    Size size, {
    required int viewId,
    required _ELinuxViewState viewState,
  });

  Future<void> setOffset(
    Offset offset, {
    required int viewId,
    required _ELinuxViewState viewState,
  });

  Future<void> sendDisposeMessage({required int viewId});
}

/// See: [_TextureAndroidViewControllerInternals] in `src/services/platform_view.dart`
class _TextureELinuxViewControllerInternals extends _ELinuxViewControllerInternals {
  _TextureELinuxViewControllerInternals();

  /// The current offset of the platform view.
  Offset _offset = Offset.zero;

  @override
  int? textureId;

  @override
  bool get requiresViewComposition => false;

  @override
  Future<Size> setSize(
    Size size, {
    required int viewId,
    required _ELinuxViewState viewState,
  }) async {
    assert(viewState != _ELinuxViewState.waitingForSize,
        'ELinux view must have an initial size. View id: $viewId');
    assert(!size.isEmpty);

    final Map<Object?, Object?>? meta =
        await SystemChannels.platform_views.invokeMapMethod<Object?, Object?>(
      'resize',
      <String, dynamic>{
        'id': viewId,
        'width': size.width,
        'height': size.height,
      },
    );
    assert(meta != null);
    assert(meta!.containsKey('width'));
    assert(meta!.containsKey('height'));
    return Size(meta!['width']! as double, meta['height']! as double);
  }

  @override
  Future<void> setOffset(
    Offset offset, {
    required int viewId,
    required _ELinuxViewState viewState,
  }) async {
    if (offset == _offset) {
      return;
    }

    // Don't set the offset unless the ELinux view has been created.
    // The implementation of this method channel throws if the ELinux view for this viewId
    // isn't addressable.
    if (viewState != _ELinuxViewState.created) {
      return;
    }

    _offset = offset;

    await SystemChannels.platform_views.invokeMethod<void>(
      'offset',
      <String, dynamic>{
        'id': viewId,
        'top': offset.dy,
        'left': offset.dx,
      },
    );
  }

  @override
  Future<void> sendDisposeMessage({required int viewId}) {
    return SystemChannels.platform_views.invokeMethod<void>('dispose', <String, dynamic>{
      'id': viewId,
      'hybrid': false,
    });
  }
}

/// See: [_HybridAndroidViewControllerInternals] in `src/services/platform_view.dart`
class _HybridELinuxViewControllerInternals extends _ELinuxViewControllerInternals {
  @override
  int get textureId {
    throw UnimplementedError('Not supported for hybrid composition.');
  }

  @override
  bool get requiresViewComposition => true;

  @override
  Future<Size> setSize(
    Size size, {
    required int viewId,
    required _ELinuxViewState viewState,
  }) {
    throw UnimplementedError('Not supported for hybrid composition.');
  }

  @override
  Future<void> setOffset(
    Offset offset, {
    required int viewId,
    required _ELinuxViewState viewState,
  }) {
    throw UnimplementedError('Not supported for hybrid composition.');
  }

  @override
  Future<void> sendDisposeMessage({required int viewId}) {
    return SystemChannels.platform_views.invokeMethod<void>('dispose', <String, dynamic>{
      'id': viewId,
      'hybrid': true,
    });
  }
}
