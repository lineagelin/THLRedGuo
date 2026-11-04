import 'package:flutter/material.dart';

class PlayerCleanScreenIcon extends StatelessWidget {
  const PlayerCleanScreenIcon({super.key, required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) {
    final color =
        IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return Container(
      width: 23,
      height: 25,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.7),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Icon(
        active ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
        color: color,
        size: 20,
      ),
    );
  }
}
