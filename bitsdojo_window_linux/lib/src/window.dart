import 'dart:ffi' hide Size;

import 'package:bitsdojo_window_platform_interface/bitsdojo_window_platform_interface.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/painting.dart';

import './gtk.dart';
import './native_api.dart' as native;

var isInsideDoWhenWindowReady = false;

bool isValidHandle(int? handle, String operation) {
  if (handle == null) {
    print("Could not $operation - handle is null");
    return false;
  }
  return true;
}

class CachedWindowInfo {
  Rect? rect;
}

Rect getScreenRectForWindow(int handle) {
  Pointer<Int32> gtkRect = malloc.allocate(sizeOf<Int32>() * 4);
  native.getScreenRect(
      handle, gtkRect + 0, gtkRect + 1, gtkRect + 2, gtkRect + 3);
  Rect result = Rect.fromLTWH(gtkRect[0].toDouble(), gtkRect[1].toDouble(),
      gtkRect[2].toDouble(), gtkRect[3].toDouble());
  malloc.free(gtkRect);

  return result;
}

class GtkWindow extends DesktopWindow {
  int? nonWindowsHandle;
  Size? _minSize;
  Size? _maxSize;
  Alignment? _alignment;
  // size and position are cached during doWhenWindowReady
  // because the window operations for setting size/position
  // are scheduled and do not run immediately so the results
  // from native getSize/getPosition are not reliable
  // immediatly after the operation

  CachedWindowInfo _cached = CachedWindowInfo();

  GtkWindow() {
    //_alignment = Alignment.center;
  }

  @Deprecated("use isVisible instead")
  @override
  bool get visible {
    return isVisible;
  }

  @override
  bool get isVisible {
    //TODO: implement
    return true;
  }

  @override
  Rect get rect {
    if (!isValidHandle(nonWindowsHandle, "get rectangle")) return Rect.zero;

    if (isInsideDoWhenWindowReady == true && _cached.rect != null) {
      return _cached.rect!;
    }

    Pointer<Int32> gtkRect = malloc.allocate(sizeOf<Int32>() * 4);
    native.getPosition(nonWindowsHandle!, gtkRect + 0, gtkRect + 1);
    native.getSize(nonWindowsHandle!, gtkRect + 2, gtkRect + 3);
    Rect result = Rect.fromLTWH(gtkRect[0].toDouble(), gtkRect[1].toDouble(),
        gtkRect[2].toDouble(), gtkRect[3].toDouble());

    malloc.free(gtkRect);
    return result;
  }

  @override
  set rect(Rect newRect) {
    if (!isValidHandle(nonWindowsHandle, "set rectangle")) return;
    _cached.rect = newRect;
    native.setRect(nonWindowsHandle!, newRect.left.toInt(), newRect.top.toInt(),
        newRect.width.toInt(), newRect.height.toInt());
  }

  @override
  Size get size {
    if (!isValidHandle(nonWindowsHandle, "get size")) return Size.zero;

    if (isInsideDoWhenWindowReady == true && _cached.rect != null) {
      return _cached.rect!.size;
    }

    Pointer<Int32> nativeResult = malloc.allocate(sizeOf<Int32>() * 2);
    native.getSize(nonWindowsHandle!, nativeResult + 0, nativeResult + 1);
    Size result = Size(nativeResult[0].toDouble(), nativeResult[1].toDouble());
    malloc.free(nativeResult);
    final gotSize = getLogicalSize(result);
    return gotSize;
  }

  Size get sizeOnScreen {
    if (isInsideDoWhenWindowReady == true && _cached.rect != null) {
      final sizeOnScreen = getSizeOnScreen(_cached.rect!.size);
      return sizeOnScreen;
    }
    final winRect = this.rect;
    return Size(winRect.width, winRect.height);
  }

  @override
  double get borderSize {
    return 0.0;
  }

  int get dpi {
    return (96.0 * this.scaleFactor).toInt();
  }

  @override
  double get scaleFactor {
    if (!isValidHandle(nonWindowsHandle, "get scaleFactor")) return 1;
    Pointer<Int32> scaleFactorPtr = malloc.allocate(sizeOf<Int32>());
    native.getScaleFactor(nonWindowsHandle!, scaleFactorPtr + 1);
    double result = scaleFactorPtr[0].toDouble();
    malloc.free(scaleFactorPtr);
    return result;
  }

  @override
  double get titleBarHeight {
    // NOTE: This might be difficult to retrieve from gtk
    return 32.0;
  }

  @override
  Size get titleBarButtonSize {
    // NOTE: This might be difficult to retrieve from gtk
    Size result = Size(32, 32);
    return result;
  }

  Size getSizeOnScreen(Size inSize) {
    double scaleFactor = this.scaleFactor;
    double newWidth = inSize.width * scaleFactor;
    double newHeight = inSize.height * scaleFactor;
    return Size(newWidth, newHeight);
  }

  Size getLogicalSize(Size inSize) {
    double scaleFactor = this.scaleFactor;
    double newWidth = inSize.width / scaleFactor;
    double newHeight = inSize.height / scaleFactor;
    return Size(newWidth, newHeight);
  }

  @override
  Alignment? get alignment => _alignment;

  /// How the window should be aligned on screen
  @override
  set alignment(Alignment? newAlignment) {
    final sizeOnScreen = this.sizeOnScreen;
    _alignment = newAlignment;
    if (_alignment != null) {
      if (!isValidHandle(nonWindowsHandle, "set alignment")) return;
      final screenRect = getScreenRectForWindow(nonWindowsHandle!);
      this.rect = getRectOnScreen(sizeOnScreen, _alignment!, screenRect);
    }
  }

  @override
  set minSize(Size? newSize) {
    if (!isValidHandle(nonWindowsHandle, "set minSize")) return;

    _minSize = newSize;
    if (newSize == null) {
      //TODO - add handling for setting minSize to null
      return;
    }
    native.setMinSize(
        nonWindowsHandle!, _minSize!.width.toInt(), _minSize!.height.toInt());
  }

  @override
  set maxSize(Size? newSize) {
    if (!isValidHandle(nonWindowsHandle, "set maxSize")) return;

    _maxSize = newSize;
    if (newSize == null) {
      //TODO - add handling for setting maxSize to null
      return;
    }
    native.setMaxSize(
        nonWindowsHandle!, _maxSize!.width.toInt(), _maxSize!.height.toInt());
  }

  @override
  set size(Size newSize) {
    if (!isValidHandle(nonWindowsHandle, "set size")) return;

    var width = newSize.width;

    if (_minSize != null) {
      if (newSize.width < _minSize!.width) width = _minSize!.width;
    }

    if (_maxSize != null) {
      if (newSize.width > _maxSize!.width) width = _maxSize!.width;
    }

    var height = newSize.height;

    if (_minSize != null) {
      if (newSize.height < _minSize!.height) height = _minSize!.height;
    }

    if (_maxSize != null) {
      if (newSize.height > _maxSize!.height) height = _maxSize!.height;
    }

    Size sizeToSet = Size(width, height);

    // Save cached rect
    final double left = _cached.rect != null ? _cached.rect!.left : 0;
    final double top = _cached.rect != null ? _cached.rect!.top : 0;
    _cached.rect = Rect.fromLTWH(left, top, width, height);

    if (_alignment == null) {
      native.setSize(
          nonWindowsHandle!, sizeToSet.width.toInt(), sizeToSet.height.toInt());
      //native.setWindowSize(nonWindowsHandle!, sizeToSet);
    } else {
      final sizeOnScreen = getSizeOnScreen((sizeToSet));
      final screenRect = getScreenRectForWindow(nonWindowsHandle!);
      this.rect = getRectOnScreen(sizeOnScreen, _alignment!, screenRect);
    }
  }

  @override
  bool get isMaximized {
    if (!isValidHandle(nonWindowsHandle, "get isMaximized")) return false;
    return gtkWindowIsMaximized(nonWindowsHandle!) == 1;
  }

  @override
  Offset get position {
    if (isInsideDoWhenWindowReady == true && _cached.rect != null) {
      return _cached.rect!.topLeft;
    }
    return this.rect.topLeft;
  }

  @override
  set position(Offset newPosition) {
    if (!isValidHandle(nonWindowsHandle, "set position")) return;
    // Save cached rect
    final double width = _cached.rect != null ? _cached.rect!.width : 0;
    final double height = _cached.rect != null ? _cached.rect!.height : 0;
    _cached.rect = Rect.fromLTWH(newPosition.dx, newPosition.dy, width, height);
    native.setPosition(
        nonWindowsHandle!, newPosition.dx.toInt(), newPosition.dy.toInt());
  }

  @override
  void show() {
    if (!isValidHandle(nonWindowsHandle, "show")) return;
    Offset currentPosition = this.position;
    native.showWindow(nonWindowsHandle!);
    this.position = currentPosition;
  }

  @override
  void hide() {
    if (!isValidHandle(nonWindowsHandle, "hide")) return;
    native.hideWindow(nonWindowsHandle!);
  }

  @Deprecated("use show()/hide() instead")
  @override
  set visible(bool isVisible) {
    if (isVisible) {
      show();
    } else {
      hide();
    }
  }

  @override
  void close() {
    if (!isValidHandle(nonWindowsHandle, "close")) return;
    gtkWindowClose(nonWindowsHandle!);
  }

  @override
  void maximize() {
    if (!isValidHandle(nonWindowsHandle, "maximize")) return;
    native.maximizeWindow(nonWindowsHandle!);
  }

  @override
  void minimize() {
    if (!isValidHandle(nonWindowsHandle, "minimize")) return;
    native.minimizeWindow(nonWindowsHandle!);
  }

  @override
  void restore() {
    if (!isValidHandle(nonWindowsHandle, "restore")) return;
    native.unmaximizeWindow(nonWindowsHandle!);
  }

  @override
  void maximizeOrRestore() {
    if (!isValidHandle(nonWindowsHandle, "maximizeOrRestore")) return;
    if (this.isMaximized) {
      this.restore();
    } else {
      this.maximize();
    }
  }

  @override
  set title(String newTitle) {
    if (!isValidHandle(nonWindowsHandle, "set title")) return;
    final nativeString = newTitle.toNativeUtf8();
    native.setWindowTitle(nonWindowsHandle!, nativeString);
  }

  @override
  void startDragging() {
    BitsdojoWindowPlatform.instance.dragAppWindow();
  }
}
