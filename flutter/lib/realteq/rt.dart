import 'package:flutter/material.dart';

/// Obsidiana: tokens de cor e componentes base do Realteq Desk.
/// Toda tela nova usa só isto, para a identidade ficar num lugar só.
class RtPalette {
  final Color bg, rail, panel, panel2, field, line, ink, mut, accent, accentInk;
  final Color ok, danger;
  const RtPalette._(this.bg, this.rail, this.panel, this.panel2, this.field,
      this.line, this.ink, this.mut, this.accent, this.accentInk, this.ok,
      this.danger);

  static const dark = RtPalette._(
      Color(0xFF17150F),
      Color(0xFF110F0A),
      Color(0xFF201D15),
      Color(0xFF2A251A),
      Color(0xFF15130D),
      Color(0xFF332E22),
      Color(0xFFF3EAD8),
      Color(0xFF9B917A),
      Color(0xFFE6A800),
      Color(0xFF241B00),
      Color(0xFF3BB273),
      Color(0xFFD6402B));

  static const light = RtPalette._(
      Color(0xFFF8F0E3),
      Color(0xFFEFE4D2),
      Color(0xFFFFFFFF),
      Color(0xFFF3E8D2),
      Color(0xFFFFFDF8),
      Color(0xFFE8DCC6),
      Color(0xFF2A2418),
      Color(0xFF8A7D66),
      Color(0xFFE6A800),
      Color(0xFF241B00),
      Color(0xFF2F9E66),
      Color(0xFFD6402B));

  static RtPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

extension RtCtx on BuildContext {
  RtPalette get rt => RtPalette.of(this);
}

class RtPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  const RtPanel(
      {Key? key,
      required this.child,
      this.padding = const EdgeInsets.all(22),
      this.color,
      this.radius = 18})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final p = context.rt;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: p.line),
      ),
      child: child,
    );
  }
}

class RtLabel extends StatelessWidget {
  final String text;
  const RtLabel(this.text, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
          color: context.rt.mut));
}

class RtButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;
  final bool expand;
  const RtButton(this.label,
      {Key? key,
      this.icon,
      this.onTap,
      this.primary = false,
      this.danger = false,
      this.expand = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final p = context.rt;
    final bg = danger ? p.danger : (primary ? p.accent : p.panel2);
    final fg = danger ? Colors.white : (primary ? p.accentInk : p.ink);
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                ],
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RtIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  const RtIconButton(this.icon,
      {Key? key, this.tooltip = '', this.onTap, this.active = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final p = context.rt;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? p.panel2 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 19, color: active ? p.accent : p.mut),
          ),
        ),
      ),
    );
  }
}

class RtToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const RtToggle({Key? key, required this.value, this.onChanged})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final p = context.rt;
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 40,
        height: 23,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? p.accent : p.line,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
              color: value ? p.accentInk : Colors.white,
              shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class RtSegmented extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;
  const RtSegmented(
      {Key? key,
      required this.options,
      required this.selected,
      required this.onSelect})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final p = context.rt;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: p.field, borderRadius: BorderRadius.circular(11)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < options.length; i++)
          GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: i == selected ? p.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(options[i],
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: i == selected ? p.accentInk : p.mut)),
            ),
          ),
      ]),
    );
  }
}

class RtRow extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget trailing;
  const RtRow({Key? key, required this.title, this.sub, required this.trailing})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final p = context.rt;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500, color: p.ink)),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(sub!, style: TextStyle(fontSize: 12, color: p.mut)),
              ),
          ]),
        ),
        const SizedBox(width: 12),
        trailing,
      ]),
    );
  }
}

class RtDot extends StatelessWidget {
  final Color color;
  const RtDot(this.color, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
