import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final List<Widget>? actions;
  final Color? backgroundColor;

  const AppHeader({
    super.key,
    required this.title,
    this.showBack = true,
    this.actions,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? Colors.transparent,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: showBack,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: 0.5,
        ),
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
