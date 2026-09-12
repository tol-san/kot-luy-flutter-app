import 'package:flutter/material.dart';

/// A [GlobalKey] for the root [ScaffoldMessenger] created by [MaterialApp].
///
/// Pass this key to [MaterialApp.scaffoldMessengerKey] in [main.dart].
/// Use [rootMessengerKey.currentState] anywhere in the app — including from
/// inside modal bottom sheets — to show [SnackBar]s above all routes and
/// overlays, so the user never has to close a modal to read a message.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
