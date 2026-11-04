import 'package:flutter/material.dart';
import 'package:THLRedLook/core/store/local_store.dart';
import 'package:THLRedLook/utils/theme/app_colors.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key, required this.store});
  final LocalStore store;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('外观与主题')),
    body: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Card(
          child: ListTile(
            leading: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: AppColors.hongguoRed,
                shape: BoxShape.circle,
              ),
            ),
            title: const Text('品牌视觉色'),
            subtitle: const Text('经典活力红 · 专为短剧打造的沉浸式主题色'),
            trailing: const Icon(
              Icons.done_all_rounded,
              color: AppColors.hongguoRed,
            ),
          ),
        ),
      ],
    ),
  );
}
