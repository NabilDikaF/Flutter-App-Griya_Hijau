import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Tinggi tetap per baris item pada menu [AppDropdown].
const double kDropdownItemHeight = 48.0;

/// Jumlah maksimum item yang terlihat penuh sebelum daftar mengaktifkan scroll.
const int kDropdownMaxVisibleItems = 5;

/// Padding vertikal atas/bawah di dalam panel menu [AppDropdown].
const double kDropdownMenuVerticalPadding = 4.0;

/// Jarak antara sisi bawah field dengan tepi atas menu [AppDropdown].
const double kDropdownMenuGap = 4.0;

/// Jarak aman minimum antara tepi bawah menu dengan tepi bawah layar.
const double kDropdownScreenEdgeMargin = 8.0;

/// Item pilihan pada [AppDropdown].
class AppDropdownItem<T> {
  const AppDropdownItem({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}

/// Dropdown seragam yang selalu membuka panel menu tepat di bawah field,
/// lebar mengikuti field, tanpa memunculkan keyboard, serta membatasi tampilan
/// hingga [kDropdownMaxVisibleItems] item penuh dengan scroll & scrollbar.
class AppDropdown<T> extends StatefulWidget {
  const AppDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.label,
    this.hint,
    this.enabled = true,
    this.validator,
    this.errorText,
    this.autovalidateMode,
    this.contentPadding,
    this.textStyle,
    this.menuKey,
  });

  final List<AppDropdownItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? hint;
  final bool enabled;
  final FormFieldValidator<T>? validator;
  final String? errorText;
  final AutovalidateMode? autovalidateMode;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? textStyle;
  final Key? menuKey;

  /// Menghitung tinggi ideal menu dari jumlah item (maksimal 5 item penuh + padding).
  static double idealMenuHeightForCount(int itemCount) {
    if (itemCount <= 0) return 0;
    final int visibleCount = math.min(itemCount, kDropdownMaxVisibleItems);
    return (visibleCount * kDropdownItemHeight) +
        (kDropdownMenuVerticalPadding * 2);
  }

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>>
    with WidgetsBindingObserver {
  final GlobalKey _fieldKey = GlobalKey();
  final GlobalKey<FormFieldState<T>> _formFieldKey =
      GlobalKey<FormFieldState<T>>();
  final OverlayPortalController _overlayController = OverlayPortalController();
  final ScrollController _scrollController = ScrollController();

  bool _isOpen = false;
  Rect? _fieldRect;
  Size? _overlaySize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant AppDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _formFieldKey.currentState?.didChange(widget.value);
        }
      });
    }
    if (_isOpen && (!_canInteract || oldWidget.items.length != widget.items.length)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_canInteract) {
          _closeMenu();
        } else if (_updateAnchorMetrics() && _isOpen) {
          setState(() {});
        }
      });
    }
  }

  @override
  void didChangeMetrics() {
    if (!_isOpen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isOpen) return;
      if (_updateAnchorMetrics()) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  bool get _canInteract =>
      widget.enabled && widget.onChanged != null && widget.items.isNotEmpty;

  AppDropdownItem<T>? _findSelectedItem() {
    for (final AppDropdownItem<T> item in widget.items) {
      if (item.value == widget.value) {
        return item;
      }
    }
    return null;
  }

  bool _updateAnchorMetrics() {
    final BuildContext? fieldContext = _fieldKey.currentContext;
    if (fieldContext == null || !mounted) return false;
    final RenderObject? fieldObject = fieldContext.findRenderObject();
    final OverlayState? overlay = Overlay.maybeOf(context);
    final RenderObject? overlayObject = overlay?.context.findRenderObject();
    if (fieldObject is! RenderBox ||
        !fieldObject.hasSize ||
        !fieldObject.attached ||
        overlayObject is! RenderBox ||
        !overlayObject.hasSize ||
        !overlayObject.attached) {
      return false;
    }
    final Offset topLeft = fieldObject.localToGlobal(
      Offset.zero,
      ancestor: overlayObject,
    );
    final Rect nextRect = topLeft & fieldObject.size;
    final Size nextOverlaySize = overlayObject.size;
    if (_fieldRect == nextRect && _overlaySize == nextOverlaySize) {
      return false;
    }
    _fieldRect = nextRect;
    _overlaySize = nextOverlaySize;
    return true;
  }

  void _toggleMenu() {
    if (_isOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    if (!_canInteract) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _updateAnchorMetrics();
    if (_fieldRect == null || _overlaySize == null) return;
    setState(() {
      _isOpen = true;
    });
    if (!_overlayController.isShowing) {
      _overlayController.show();
    }
  }

  void _closeMenu() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
    if (_isOpen && mounted) {
      setState(() {
        _isOpen = false;
      });
    }
  }

  void _selectItem(AppDropdownItem<T> item) {
    _formFieldKey.currentState?.didChange(item.value);
    _closeMenu();
    widget.onChanged?.call(item.value);
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final Rect? fieldRect = _fieldRect;
    final Size? overlaySize = _overlaySize;
    if (fieldRect == null || overlaySize == null || widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final MediaQueryData mediaQuery = MediaQuery.of(overlayContext);
    final double bottomInset =
        math.max(mediaQuery.padding.bottom, mediaQuery.viewInsets.bottom);
    final double menuTop = fieldRect.bottom + kDropdownMenuGap;
    final double maxBottom =
        overlaySize.height - bottomInset - kDropdownScreenEdgeMargin;
    final double availableHeight = math.max(0.0, maxBottom - menuTop);
    final double idealHeight =
        AppDropdown.idealMenuHeightForCount(widget.items.length);
    final double menuHeight = math.min(idealHeight, availableHeight);
    final double menuWidth = math.min(fieldRect.width, overlaySize.width);
    final double menuLeft = fieldRect.left.clamp(
      0.0,
      math.max(0.0, overlaySize.width - menuWidth),
    );
    final double verticalPadding =
        math.min(kDropdownMenuVerticalPadding, menuHeight / 2);
    final double listHeight = math.max(0.0, menuHeight - (verticalPadding * 2));
    final bool needsScroll =
        widget.items.length > kDropdownMaxVisibleItems ||
            (widget.items.length * kDropdownItemHeight) > listHeight + 0.5;

    Widget listView = ListView.builder(
      key: const Key('app_dropdown_menu_list'),
      controller: _scrollController,
      primary: false,
      padding: EdgeInsets.zero,
      cacheExtent: 0,
      itemExtent: kDropdownItemHeight,
      physics: needsScroll
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: widget.items.length,
      itemBuilder: (BuildContext context, int index) {
        final AppDropdownItem<T> item = widget.items[index];
        final bool isSelected = item.value == widget.value;
        return Material(
          color: isSelected ? AppColors.emerald50 : Colors.transparent,
          child: InkWell(
            onTap: () => _selectItem(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (widget.textStyle ?? AppTypography.bodyMedium15)
                          .copyWith(
                        color: isSelected
                            ? AppColors.emerald800
                            : AppColors.slate900,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (isSelected) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(
                      Icons.check,
                      size: 18,
                      color: AppColors.emerald600,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );

    if (needsScroll) {
      listView = Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        interactive: true,
        child: listView,
      );
    }

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeMenu,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: menuLeft,
          top: menuTop,
          width: menuWidth,
          height: menuHeight,
          child: Material(
            key: widget.menuKey ?? const Key('app_dropdown_menu'),
            color: AppColors.white,
            elevation: 6,
            shadowColor: AppColors.slate900.withValues(alpha: 0.14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              side: const BorderSide(color: AppColors.slate200),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: verticalPadding),
              child: listView,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppDropdownItem<T>? selectedItem = _findSelectedItem();
    final String displayText = selectedItem?.label ?? widget.hint ?? '';
    final bool hasSelection = selectedItem != null;
    final bool isInteractive = _canInteract;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.label != null) ...<Widget>[
          Text(widget.label!, style: AppTypography.inputLabel),
          const SizedBox(height: AppSpacing.fieldGap),
        ],
        FormField<T>(
          key: _formFieldKey,
          initialValue: widget.value,
          enabled: widget.enabled,
          validator: widget.validator,
          autovalidateMode: widget.autovalidateMode,
          builder: (FormFieldState<T> field) {
            final String? effectiveError = widget.errorText ?? field.errorText;
            final TextStyle baseStyle =
                widget.textStyle ?? AppTypography.bodyMedium15;
            final TextStyle effectiveStyle = baseStyle.copyWith(
              color: !isInteractive
                  ? AppColors.slate500
                  : (hasSelection ? AppColors.slate900 : AppColors.slate500),
            );

            return OverlayPortal(
              controller: _overlayController,
              overlayChildBuilder: _buildOverlay,
              child: Semantics(
                button: true,
                enabled: isInteractive,
                expanded: _isOpen,
                label: widget.label ?? widget.hint,
                value: selectedItem?.label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  onTap: isInteractive ? _toggleMenu : null,
                  child: KeyedSubtree(
                    key: _fieldKey,
                    child: InputDecorator(
                      isFocused: _isOpen,
                      isEmpty: !hasSelection,
                      decoration: InputDecoration(
                        isDense: true,
                        enabled: isInteractive,
                        contentPadding: widget.contentPadding ??
                            const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 13,
                            ),
                        errorText: effectiveError,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 22),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                displayText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: effectiveStyle,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Icon(
                              _isOpen
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 20,
                              color: isInteractive
                                  ? AppColors.slate600
                                  : AppColors.slate500,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
