import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

extension Loc on BuildContext {
  AppLocalizations get loc => AppLocalizations.of(this)!;
}