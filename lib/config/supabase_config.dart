import 'dart:convert';

import 'package:flutter/services.dart';

/// Only public client settings belong here. Both flags must be supplied together
/// when overriding the bundled JSON for another deployment.
final class SupabaseConfig {
  const SupabaseConfig._(this.url, this.publishableKey);
  final String url;
  final String publishableKey;

  static Future<SupabaseConfig> load({
    AssetBundle? bundle,
    String urlOverride = const String.fromEnvironment('SUPABASE_URL'),
    String keyOverride = const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
  }) async {
    if (urlOverride.isNotEmpty || keyOverride.isNotEmpty) {
      return SupabaseConfig.fromJson({
        'SUPABASE_URL': urlOverride,
        'SUPABASE_PUBLISHABLE_KEY': keyOverride,
      });
    }
    final source = await (bundle ?? rootBundle).loadString(
      'config/supabase.json',
    );
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic>) {
      throw const FormatException(
        'Supabase configuration must be a JSON object.',
      );
    }
    return SupabaseConfig.fromJson(json);
  }

  factory SupabaseConfig.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['SUPABASE_URL'];
    final rawKey = json['SUPABASE_PUBLISHABLE_KEY'];
    if (rawUrl is! String || rawKey is! String) {
      throw const FormatException(
        'Supabase URL and publishable key are required.',
      );
    }
    final url = rawUrl.trim(), key = rawKey.trim();
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !key.startsWith('sb_publishable_') ||
        key.length <= 'sb_publishable_'.length) {
      throw const FormatException(
        'Supabase configuration is incomplete or invalid.',
      );
    }
    return SupabaseConfig._(url, key);
  }
}
