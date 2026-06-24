import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ProductImageCacheService {
  ProductImageCacheService._();

  static final ProductImageCacheService instance = ProductImageCacheService._();

  final BaseCacheManager _cacheManager = DefaultCacheManager();
  final Set<String> _queuedUrls = <String>{};
  bool _isPrefetching = false;

  Future<void> prefetchUrls(Iterable<String> urls) async {
    if (kIsWeb) {
      return;
    }

    _queuedUrls.addAll(
      urls.map((url) => url.trim()).where((url) => url.startsWith('http')),
    );

    if (_isPrefetching) {
      return;
    }

    _isPrefetching = true;
    try {
      while (_queuedUrls.isNotEmpty) {
        final nextUrl = _queuedUrls.first;
        _queuedUrls.remove(nextUrl);
        try {
          await _cacheManager.downloadFile(nextUrl, force: false);
        } catch (_) {
          // Ignore image cache failures so catalog loading stays fast.
        }
      }
    } finally {
      _isPrefetching = false;
    }
  }

  void prefetchInBackground(Iterable<String> urls) {
    unawaited(prefetchUrls(urls));
  }
}
