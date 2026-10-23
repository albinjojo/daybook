import 'dart:convert';

import 'package:daybook/config/supabase_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class ConfigBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    expect(key, 'config/supabase.json');
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'SUPABASE_URL': 'https://example.supabase.co',
          'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_test',
        }),
      ),
    );
    return ByteData.sublistView(bytes);
  }
}

void main() {
  test(
    'ordinary Flutter launch loads bundled JSON without build flags',
    () async {
      final config = await SupabaseConfig.load(
        bundle: ConfigBundle(),
        urlOverride: '',
        keyOverride: '',
      );
      expect(config.url, 'https://example.supabase.co');
      expect(config.publishableKey, 'sb_publishable_test');
    },
  );
  test('complete deployment overrides take precedence', () async {
    final config = await SupabaseConfig.load(
      urlOverride: 'https://other.supabase.co',
      keyOverride: 'sb_publishable_other',
    );
    expect(config.url, 'https://other.supabase.co');
  });
  test('partial overrides and non-public keys are rejected', () async {
    await expectLater(
      SupabaseConfig.load(
        urlOverride: 'https://other.supabase.co',
        keyOverride: '',
      ),
      throwsFormatException,
    );
    expect(
      () => SupabaseConfig.fromJson({
        'SUPABASE_URL': 'https://example.supabase.co',
        'SUPABASE_PUBLISHABLE_KEY': 'sb_secret_test',
      }),
      throwsFormatException,
    );
  });
}
