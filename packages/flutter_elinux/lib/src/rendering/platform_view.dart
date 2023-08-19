// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../services/platform_views.dart';

/// See: [_PlatformViewState] in `src/rendering/platform_view.dart`
enum _PlatformViewState {
  uninitialized,
  resizing,
  ready,
}

/// See: [RenderAndroidView] in `src/rendering/platform_view.dart`
class RenderELinuxView extends PlatformViewRenderBox {
  /// Creates a render object for an ELinux view.
  RenderELinuxView({
    required ELinuxViewController viewController,
    required PlatformViewHitTestBehavior hitTestBehavior,
    required Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
    Clip clipBehavior = Clip.hardEdge,
  })  : _viewController = viewController,
        _clipBehavior = clipBehavior,
        super(
            controller: viewController,
            hitTestBehavior: hitTestBehavior,
            gestureRecognizers: gestureRecognizers) {
    _viewController.pointTransformer = (Offset offset) => globalToLocal(offset);
    updateGestureRecognizers(gestureRecognizers);
    _viewController.addOnPlatformViewCreatedListener(_onPlatformViewCreated);
    this.hitTestBehavior = hitTestBehavior;
    _setOffset();
  }

  _PlatformViewState _state = _PlatformViewState.uninitialized;

  Size? _currentTextureSize;

  bool _isDisposed = false;

  /// The ELinux view controller for the ELinux view associated with this render object.
  @override
  ELinuxViewController get controller => _viewController;

  ELinuxViewController _viewController;

  /// Sets a new ELinux view controller.
  @override
  set controller(ELinuxViewController controller) {
    assert(!_isDisposed);
    if (_viewController == controller) {
      return;
    }
    _viewController.removeOnPlatformViewCreatedListener(_onPlatformViewCreated);
    super.controller = controller;
    _viewController = controller;
    _viewController.pointTransformer = (Offset offset) => globalToLocal(offset);
    _sizePlatformView();
    if (_viewController.isCreated) {
      markNeedsSemanticsUpdate();
    }
    _viewController.addOnPlatformViewCreatedListener(_onPlatformViewCreated);
  }

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// Defaults to [Clip.hardEdge], and must not be null.
  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior = Clip.hardEdge;
  set clipBehavior(Clip value) {
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }

  void _onPlatformViewCreated(int id) {
    assert(!_isDisposed);
    markNeedsSemanticsUpdate();
  }

  @override
  bool get sizedByParent => true;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  bool get isRepaintBoundary => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.biggest;
  }

  @override
  void performResize() {
    super.performResize();
    _sizePlatformView();
  }

  Future<void> _sizePlatformView() async {
    // ELinux virtual displays cannot have a zero size.
    // Trying to size it to 0 crashes the app, which was happening when starting the app
    // with a locked screen (see: https://github.com/flutter/flutter/issues/20456).
    if (_state == _PlatformViewState.resizing || size.isEmpty) {
      return;
    }

    _state = _PlatformViewState.resizing;
    markNeedsPaint();

    Size targetSize;
    do {
      targetSize = size;
      _currentTextureSize = await _viewController.setSize(targetSize);
      if (_isDisposed) {
        return;
      }
      // We've resized the platform view to targetSize, but it is possible that
      // while we were resizing the render object's size was changed again.
      // In that case we will resize the platform view again.
    } while (size != targetSize);

    _state = _PlatformViewState.ready;
    markNeedsPaint();
  }

  // Sets the offset of the underlying platform view on the platform side.
  //
  // This allows the ELinux native view to draw the a11y highlights in the same
  // location on the screen as the platform view widget in the Flutter framework.
  //
  // It also allows platform code to obtain the correct position of the ELinux
  // native view on the screen.
  void _setOffset() {
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (!_isDisposed) {
        if (attached) {
          await _viewController.setOffset(localToGlobal(Offset.zero));
        }
        // Schedule a new post frame callback.
        _setOffset();
      }
    });
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_viewController.textureId == null || _currentTextureSize == null) {
      return;
    }

    // As resizing the ELinux view happens asynchronously we don't know exactly when is a
    // texture frame with the new size is ready for consumption.
    // TextureLayer is unaware of the texture frame's size and always maps it to the
    // specified rect. If the rect we provide has a different size from the current texture frame's
    // size the texture frame will be scaled.
    // To prevent unwanted scaling artifacts while resizing, clip the texture.
    // This guarantees that the size of the texture frame we're painting is always
    // _currentELinuxTextureSize.
    final bool isTextureLargerThanWidget =
        _currentTextureSize!.width > size.width ||
            _currentTextureSize!.height > size.height;
    if (isTextureLargerThanWidget && clipBehavior != Clip.none) {
      _clipRectLayer.layer = context.pushClipRect(
        true,
        offset,
        offset & size,
        _paintTexture,
        clipBehavior: clipBehavior,
        oldLayer: _clipRectLayer.layer,
      );
      return;
    }
    _clipRectLayer.layer = null;
    _paintTexture(context, offset);
  }

  final LayerHandle<ClipRectLayer> _clipRectLayer =
      LayerHandle<ClipRectLayer>();

  @override
  void dispose() {
    _isDisposed = true;
    _clipRectLayer.layer = null;
    _viewController.removeOnPlatformViewCreatedListener(_onPlatformViewCreated);
    super.dispose();
  }

  void _paintTexture(PaintingContext context, Offset offset) {
    if (_currentTextureSize == null) {
      return;
    }

    context.addLayer(TextureLayer(
      rect: offset & _currentTextureSize!,
      textureId: _viewController.textureId!,
    ));
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    // Don't call the super implementation since `platformViewId` should
    // be set only when the platform view is created, but the concept of
    // a "created" platform view belongs to this subclass.
    config.isSemanticBoundary = true;

    if (_viewController.isCreated) {
      config.platformViewId = _viewController.viewId;
    }
  }
}
