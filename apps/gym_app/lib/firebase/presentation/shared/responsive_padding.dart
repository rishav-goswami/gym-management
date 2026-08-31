import 'package:flutter/material.dart';

/// Consistent breathing room for the app's main tab panels (Home, Training,
/// Progress) — narrower on phones, wider on tablets/web.
EdgeInsets memberPanelPadding(BuildContext context) {
  final wide = MediaQuery.sizeOf(context).width >= 600;
  return EdgeInsets.fromLTRB(wide ? 28 : 16, 20, wide ? 28 : 16, 40);
}
