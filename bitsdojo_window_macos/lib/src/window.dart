import 'package:bitsdojo_window_platform_interface/bitsdojo_window_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import './window_util.dart';
import './native_api.dart';

bool isValidHandle(int? handle, String operation) {
  if (handle == null) {
    print("Could not $operation - handle is null");
    return false;
  }
  return true;
}

class MacOSWindow extends DesktopWindow {
  int? nonWindowsHandle;
  Size? _minSize;
  Size? _maxSize;
  Alignment? _alignment;
  bool _setTitleOnNextShow = false;
  String? _titleToSet;

  MacOSWindow() {
    _alignment = Alignment.center;
    _setTitleOnNextShow = false;
  }

  Size get size {
    final winRect = this.rect;
    return Size(winRect.right - winRect.left, winRect.bottom - winRect.top);
  }

  Rect get rect {
    if (!isValidHandle(nonWindowsHandle, "get rectangle")) return Rect.zero;
    return getRectForWindow(nonWindowsHandle!);
  }

  double get scaleFactor {
    //TODO: implement
    return 1;
  }

  set rect(Rect newRect) {
    if (!isValidHandle(nonWindowsHandle, "set rectangle")) return;
    var widthToSet = ((_minSize != null) && (newRect.width < _minSize!.width))
        ? _minSize!.width
        : newRect.width;
    var heightToSet =
        ((_minSize != null) && (newRect.height < _minSize!.height))
            ? _minSize!.height
            : newRect.height;
    final rectToSet =
        Rect.fromLTWH(newRect.left, newRect.top, widthToSet, heightToSet);
    setRectForWindow(nonWindowsHandle!, rectToSet);
  }

  Offset get position {
    final winRect = this.rect;
    return Offset(winRect.left, winRect.top);
  }

  set position(Offset newPosition) {
    if (!isValidHandle(nonWindowsHandle, "set position")) return;
    setPositionForWindow(nonWindowsHandle!, newPosition);
  }

  Alignment? get alignment => _alignment;
  set alignment(Alignment? newAlignment) {
    _alignment = newAlignment;
    if (_alignment != null) {
      if (!isValidHandle(nonWindowsHandle, "set alignment")) return;
      final screenInfo = getScreenInfoForWindow(nonWindowsHandle!);
      if (screenInfo.workingRect == null) {
        print("Can't set alignment - don't have a workingRect");
        return;
      }
      final windowRect =
          getRectOnScreen(this.size, _alignment!, screenInfo.workingRect!);
      final menuBarHeight = screenInfo.workingRect!.top;
      // We need to subtract menuBarHeight because .position uses
      // setFrameTopLeftPoint internally and that needs an offset
      // relative to the start of the working rectangle (after the menu bar)
      final positionToSet = windowRect.topLeft.translate(0, -menuBarHeight);
      this.position = positionToSet;
    }
  }

  set minSize(Size? newSize) {
    if (!isValidHandle(nonWindowsHandle, "set minSize")) return;
    _minSize = newSize;
    if (newSize == null) {
      //TODO - add handling for setting minSize to null
      return;
    }
    setMinSize(
        nonWindowsHandle!, _minSize!.width.toInt(), _minSize!.height.toInt());
  }

  set maxSize(Size? newSize) {
    if (!isValidHandle(nonWindowsHandle, "set maxSize")) return;
    _maxSize = newSize;
    if (newSize == null) {
      //TODO - add handling for setting maxSize to null
      return;
    }
    setMaxSize(
        nonWindowsHandle!, _maxSize!.width.toInt(), _maxSize!.height.toInt());
  }

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
    if (_alignment == null) {
      setSize(
          nonWindowsHandle!, sizeToSet.width.toInt(), sizeToSet.height.toInt());
    } else {
      final screenInfo = getScreenInfoForWindow(nonWindowsHandle!);
      if (screenInfo.workingRect == null) {
        print("Can't set size - don't have a workingRect");
        return;
      }
      this.rect =
          getRectOnScreen(sizeToSet, _alignment!, screenInfo.workingRect!);
    }
  }

  Size get titleBarButtonSize {
    if (!isValidHandle(nonWindowsHandle, "get titleBarButtonSize"))
      return Size.zero;
    throw UnimplementedError(
        'titleBarButtonSize getter has not been implemented.');
  }

  double get titleBarHeight {
    if (!isValidHandle(nonWindowsHandle, "get titleBarHeight")) return 0;
    return getTitleBarHeight(nonWindowsHandle!);
  }

  set title(String newTitle) {
    if (!isValidHandle(nonWindowsHandle, "set title")) return;
    // Save title internally because window might be hidden
    // so title won't be set. Will set it on next show()
    if (this.isVisible == false) {
      _setTitleOnNextShow = true;
      _titleToSet = newTitle;
    }
    setWindowTitle(nonWindowsHandle!, newTitle);
  }

  double get borderSize {
    //borderSize is zero on macOS
    return 0;
  }

  @Deprecated("use isVisible instead")
  bool get visible {
    return isVisible;
  }

  bool get isVisible {
    if (!isValidHandle(nonWindowsHandle, "get isVisible")) return false;
    return isWindowVisible(nonWindowsHandle!);
  }

  @Deprecated("use show()/hide() instead")
  set visible(bool isVisible) {
    if (isVisible) {
      show();
    } else {
      hide();
    }
  }

  void show() {
    if (!isValidHandle(nonWindowsHandle, "show")) return;
    showWindow(nonWindowsHandle!);
    if (_setTitleOnNextShow) {
      _setTitleOnNextShow = false;
      if (_titleToSet != null) {
        setWindowTitle(nonWindowsHandle!, _titleToSet!);
      }
    }
  }

  void hide() {
    if (!isValidHandle(nonWindowsHandle, "hide")) return;
    hideWindow(nonWindowsHandle!);
  }

  void close() {
    if (!isValidHandle(nonWindowsHandle, "close")) return;
    closeWindow(nonWindowsHandle!);
  }

  void minimize() {
    if (!isValidHandle(nonWindowsHandle, "minimize")) return;
    minimizeWindow(nonWindowsHandle!);
  }

  void maximize() {
    if (!isValidHandle(nonWindowsHandle, "maximize")) return;
    maximizeWindow(nonWindowsHandle!);
  }

  void restore() {
    if (this.isMaximized) {
      maximizeOrRestore();
    }
  }

  bool get isMaximized {
    if (!isValidHandle(nonWindowsHandle, "get isMaximized")) return false;
    return isWindowMaximized(nonWindowsHandle!);
  }

  void startDragging() {
    if (!isValidHandle(nonWindowsHandle, "start dragging")) return;
    moveWindow(nonWindowsHandle!);
  }

  void maximizeOrRestore() {
    if (!isValidHandle(nonWindowsHandle, "maximizeOrRestore")) return;
    maximizeOrRestoreWindow(nonWindowsHandle!);
  }
}
