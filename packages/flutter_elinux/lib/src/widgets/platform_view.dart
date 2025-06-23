// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../rendering/platform_view.dart';
import '../services/platform_views.dart';

/// See: [AndroidView] in `src/widgets/platform_view.dart`
class ELinuxView extends StatefulWidget {
  const ELinuxView({
    super.key,
    required this.viewType,
    this.onPlatformViewCreated,
    this.hitTestBehavior = PlatformViewHitTestBehavior.opaque,
    this.layoutDirection,
    this.gestureRecognizers,
    this.creationParams,
    this.creationParamsCodec,
    this.clipBehavior = Clip.hardEdge,
  }) : assert(creationParams == null || creationParamsCodec != null);

  final String viewType;
  final PlatformViewCreatedCallback? onPlatformViewCreated;
  final PlatformViewHitTestBehavior hitTestBehavior;
  final TextDirection? layoutDirection;
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;
  final dynamic creationParams;
  final MessageCodec<dynamic>? creationParamsCodec;
  final Clip clipBehavior;

  @override
  State<ELinuxView> createState() => _ELinuxViewState();
}

/// See: [_AndroidViewState] in `src/widgets/platform_view.dart`
class _ELinuxViewState extends State<ELinuxView> {
  int? _id;
  late ELinuxViewController _controller;
  TextDirection? _layoutDirection;
  bool _initialized = false;
  FocusNode? _focusNode;

  static final Set<Factory<OneSequenceGestureRecognizer>> _emptyRecognizersSet =
      <Factory<OneSequenceGestureRecognizer>>{};

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: _onFocusChange,
      child: _ELinuxPlatformView(
        controller: _controller,
        hitTestBehavior: widget.hitTestBehavior,
        gestureRecognizers: widget.gestureRecognizers ?? _emptyRecognizersSet,
        clipBehavior: widget.clipBehavior,
      ),
    );
  }

  void _initializeOnce() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _createNewELinuxView();
    _focusNode = FocusNode(debugLabel: 'ELinuxView(id: $_id)');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final TextDirection newLayoutDirection = _findLayoutDirection();
    final bool didChangeLayoutDirection = _layoutDirection != newLayoutDirection;
    _layoutDirection = newLayoutDirection;

    _initializeOnce();
    if (didChangeLayoutDirection) {
      // The native view will update asynchronously, in the meantime we don't want
      // to block the framework. (so this is intentionally not awaiting).
      _controller.setLayoutDirection(_layoutDirection!);
    }
  }

  @override
  void didUpdateWidget(ELinuxView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final TextDirection newLayoutDirection = _findLayoutDirection();
    final bool didChangeLayoutDirection = _layoutDirection != newLayoutDirection;
    _layoutDirection = newLayoutDirection;

    if (widget.viewType != oldWidget.viewType) {
      //_controller.disposePostFrame();
      _controller.dispose();
      _createNewELinuxView();
      return;
    }

    if (didChangeLayoutDirection) {
      _controller.setLayoutDirection(_layoutDirection!);
    }
  }

  TextDirection _findLayoutDirection() {
    assert(widget.layoutDirection != null || debugCheckHasDirectionality(context));
    return widget.layoutDirection ?? Directionality.of(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode?.dispose();
    _focusNode = null;
    super.dispose();
  }

  void _createNewELinuxView() {
    _id = platformViewsRegistry.getNextPlatformViewId();
    _controller = PlatformViewsServiceELinux.initELinuxView(
      id: _id!,
      viewType: widget.viewType,
      layoutDirection: _layoutDirection!,
      creationParams: widget.creationParams,
      creationParamsCodec: widget.creationParamsCodec,
      onFocus: () {
        _focusNode!.requestFocus();
      },
    );
    if (widget.onPlatformViewCreated != null) {
      _controller.addOnPlatformViewCreatedListener(widget.onPlatformViewCreated!);
    }
  }

  void _onFocusChange(bool isFocused) {
    if (!_controller.isCreated) {
      return;
    }
    if (!isFocused) {
      _controller.clearFocus().catchError((dynamic e) {
        if (e is MissingPluginException) {
          return;
        }
      });
      return;
    }
    SystemChannels.textInput.invokeMethod<void>(
      'TextInput.setPlatformViewClient',
      <String, dynamic>{'platformViewId': _id},
    ).catchError((dynamic e) {
      if (e is MissingPluginException) {
        return;
      }
    });
  }
}

/// See: [_AndroidPlatformView] in `src/widgets/platform_view.dart`
class _ELinuxPlatformView extends LeafRenderObjectWidget {
  const _ELinuxPlatformView({
    required this.controller,
    required this.hitTestBehavior,
    required this.gestureRecognizers,
    this.clipBehavior = Clip.hardEdge,
  });

  final ELinuxViewController controller;
  final PlatformViewHitTestBehavior hitTestBehavior;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;
  final Clip clipBehavior;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderELinuxView(
        viewController: controller,
        hitTestBehavior: hitTestBehavior,
        gestureRecognizers: gestureRecognizers,
        clipBehavior: clipBehavior,
      );

  @override
  void updateRenderObject(BuildContext context, RenderELinuxView renderObject) {
    renderObject.controller = controller;
    renderObject.hitTestBehavior = hitTestBehavior;
    renderObject.updateGestureRecognizers(gestureRecognizers);
    renderObject.clipBehavior = clipBehavior;
  }
}

/// See: [AndroidViewSurface] in `src/widgets/platform_view.dart`
class ELinuxViewSurface extends StatefulWidget {
  const ELinuxViewSurface({
    super.key,
    required this.controller,
    required this.hitTestBehavior,
    required this.gestureRecognizers,
  });

  final ELinuxViewController controller;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;
  final PlatformViewHitTestBehavior hitTestBehavior;

  @override
  State<StatefulWidget> createState() {
    return _ELinuxViewSurfaceState();
  }
}

/// See: [AndroidViewSurfaceState] in `src/widgets/platform_view.dart`
class _ELinuxViewSurfaceState extends State<ELinuxViewSurface> {
  @override
  void initState() {
    super.initState();
    if (!widget.controller.isCreated) {
      widget.controller.addOnPlatformViewCreatedListener(_onPlatformViewCreated);
    }
  }

  @override
  void dispose() {
    widget.controller.removeOnPlatformViewCreatedListener(_onPlatformViewCreated);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.requiresViewComposition) {
      return _PlatformLayerBasedELinuxViewSurface(
        controller: widget.controller,
        hitTestBehavior: widget.hitTestBehavior,
        gestureRecognizers: widget.gestureRecognizers,
      );
    } else {
      return _TextureBasedELinuxViewSurface(
        controller: widget.controller,
        hitTestBehavior: widget.hitTestBehavior,
        gestureRecognizers: widget.gestureRecognizers,
      );
    }
  }

  void _onPlatformViewCreated(int _) {
    setState(() {});
  }
}

/// See: [_TextureBasedAndroidViewSurface] in `src/widgets/platform_view.dart`
class _TextureBasedELinuxViewSurface extends PlatformViewSurface {
  const _TextureBasedELinuxViewSurface({
    required ELinuxViewController super.controller,
    required super.hitTestBehavior,
    required super.gestureRecognizers,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    final ELinuxViewController viewController = controller as ELinuxViewController;
    // Use GL texture based composition.
    // App should use GL texture unless they require to embed a SurfaceView.
    final RenderELinuxView renderBox = RenderELinuxView(
      viewController: viewController,
      gestureRecognizers: gestureRecognizers,
      hitTestBehavior: hitTestBehavior,
    );
    viewController.pointTransformer = (Offset position) => renderBox.globalToLocal(position);
    return renderBox;
  }
}

/// See: [_PlatformLayerBasedAndroidViewSurface] in `src/widgets/platform_view.dart`
class _PlatformLayerBasedELinuxViewSurface extends PlatformViewSurface {
  const _PlatformLayerBasedELinuxViewSurface({
    required ELinuxViewController super.controller,
    required super.hitTestBehavior,
    required super.gestureRecognizers,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    final ELinuxViewController viewController = controller as ELinuxViewController;
    final PlatformViewRenderBox renderBox =
        super.createRenderObject(context) as PlatformViewRenderBox;
    viewController.pointTransformer = (Offset position) => renderBox.globalToLocal(position);
    return renderBox;
  }
}
