import 'package:flutter/material.dart';

import '../api/model/model.dart';
import '../generated/l10n/zulip_localizations.dart';
import '../model/store.dart';
import 'theme.dart';

/// The kind of administrator a message's sender is, for [RoleBadge].
enum SenderRole {
  owner,
  administrator,
  channelAdministrator,
}

/// Which [SenderRole] to show on [sender]'s avatar for a message in [channel],
/// or null if none.
///
/// Organization owners and administrators are shown as such everywhere.
/// A channel administrator is shown only on messages in that channel,
/// where [channel] is null for a message that isn't in a channel.
SenderRole? senderRoleFor(PerAccountStore store, User? sender, ZulipStream? channel) {
  if (sender == null) return null;
  if (sender.role == UserRole.owner) return SenderRole.owner;
  if (sender.role == UserRole.administrator) return SenderRole.administrator;
  if (channel != null && store.userCanAdministerChannel(sender, channel)) {
    return SenderRole.channelAdministrator;
  }
  return null;
}

/// A small shield on the corner of a sender's avatar,
/// marking them as an administrator.
///
/// The colour says which kind; the label for accessibility spells it out.
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role, this.size = 14});

  final SenderRole role;
  final double size;

  // These carry the brand's meaning for each role rather than coming from
  // the theme, and read on both light and dark backgrounds.
  static const _ownerColor = Color(0xffe19209);
  static const _administratorColor = Color(0xff1f69ff);
  static const _channelAdministratorColor = Color(0xff1a9383);

  @override
  Widget build(BuildContext context) {
    final zulipLocalizations = ZulipLocalizations.of(context);
    final designVariables = DesignVariables.of(context);

    final (color, label) = switch (role) {
      SenderRole.owner =>
        (_ownerColor, zulipLocalizations.userRoleOwner),
      SenderRole.administrator =>
        (_administratorColor, zulipLocalizations.userRoleAdministrator),
      SenderRole.channelAdministrator =>
        (_channelAdministratorColor, zulipLocalizations.channelAdministratorLabel),
    };

    return Semantics(
      label: label,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RoleBadgePainter(
            color: color,
            // The shield is separated from the avatar by a ring of this colour,
            // and the figure is cut out of it in the same colour.
            cutoutColor: designVariables.bgMessageRegular))));
  }
}

class _RoleBadgePainter extends CustomPainter {
  _RoleBadgePainter({required this.color, required this.cutoutColor});

  final Color color;
  final Color cutoutColor;

  // The shield and the person inside it, drawn in a 24-by-24 box.
  // This is the same artwork as the badge in the web app.
  static final _shield = Path()
    ..moveTo(12, 1.5)
    ..lineTo(3, 5.2)
    ..lineTo(3, 11.3)
    ..cubicTo(3, 16.7, 6.7, 20.9, 12, 22.5)
    ..cubicTo(17.3, 20.9, 21, 16.7, 21, 11.3)
    ..lineTo(21, 5.2)
    ..close();

  static final _head = Path()
    ..addOval(Rect.fromCircle(center: const Offset(12, 9.4), radius: 3.1));

  static final _shoulders = Path()
    ..moveTo(12, 13.4)
    ..cubicTo(9, 13.4, 6.8, 15.2, 6.1, 17.8)
    ..cubicTo(7.6, 19.5, 9.6, 20.8, 12, 21.6)
    ..cubicTo(14.4, 20.8, 16.4, 19.5, 17.9, 17.8)
    ..cubicTo(17.2, 15.2, 15, 13.4, 12, 13.4)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / 24);

    // The ring goes first, so that the shield covers its inner half.
    canvas.drawPath(_shield, Paint()
      ..color = cutoutColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(_shield, Paint()..color = color);

    final cutout = Paint()..color = cutoutColor;
    canvas.drawPath(_head, cutout);
    canvas.drawPath(_shoulders, cutout);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RoleBadgePainter oldDelegate) =>
    oldDelegate.color != color || oldDelegate.cutoutColor != cutoutColor;
}
