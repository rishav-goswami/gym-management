import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // This automatically checks if there's a screen to go back to.
    final canPop = Navigator.of(context).canPop();

    return AppBar(
      // The elevation, backgroundColor, etc., will be determined by your app's theme.
      // You can override them here if needed.
      backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      elevation: theme.appBarTheme.elevation ?? 0,
      
      // Use the theme's title text style.
      title: Text(
        title,
        style: theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge,
      ),
      centerTitle: true,

      // --- The "Smart" Back Button ---
      // Only show the leading back button if Navigator.canPop() is true.
      leading: canPop
          ? IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: theme.appBarTheme.iconTheme?.color ?? theme.colorScheme.onSurface,
              ),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null, // If we can't pop, don't show any leading widget.
      
      actions: actions,
    );
  }

  // This is required when implementing PreferredSizeWidget.
  // It tells the Scaffold how much height the AppBar needs.
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
