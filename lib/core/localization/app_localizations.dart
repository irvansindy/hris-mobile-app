import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// The material_ui delegate targets the new Material widget namespace. This app
// still uses package:flutter/material.dart, so its matching delegate is kept
// behind this compatibility boundary until the whole UI namespace is migrated.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates =
    // ignore: deprecated_member_use
    GlobalMaterialLocalizations.delegates;
