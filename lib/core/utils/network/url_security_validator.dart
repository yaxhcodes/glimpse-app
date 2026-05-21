import 'dart:io';

typedef HostResolver = Future<List<InternetAddress>> Function(String host);

/// Validates user-supplied URLs before any preview/network fetch.
class UrlSecurityValidator {
  UrlSecurityValidator({HostResolver? resolver})
      : _resolver = resolver ?? InternetAddress.lookup;

  final HostResolver _resolver;

  Future<bool> isSafePublicUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    if (_isBlockedHostSyntax(uri.host)) return false;
    return !await resolvesToPrivateIp(uri.host);
  }

  Future<bool> resolvesToPrivateIp(String host) async {
    final normalized = _normalizeHost(host);
    final literal = InternetAddress.tryParse(normalized);
    if (literal != null) return _isPrivateAddress(literal);

    List<InternetAddress> addresses;
    try {
      addresses = await _resolver(normalized);
    } on SocketException {
      return true;
    }
    if (addresses.isEmpty) return true;
    return addresses.any(_isPrivateAddress);
  }

  Future<bool> validateRedirectChain(List<String> urls) async {
    if (urls.isEmpty) return false;
    for (final url in urls) {
      if (!await isSafePublicUrl(url)) return false;
    }
    return true;
  }

  static bool hasAllowedPublicUrlSyntax(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    return !_isBlockedHostSyntax(uri.host);
  }

  static bool _isBlockedHostSyntax(String host) {
    final normalized = _normalizeHost(host);
    if (normalized.isEmpty) return true;
    if (normalized == 'localhost' || normalized.endsWith('.localhost')) {
      return true;
    }

    final literal = InternetAddress.tryParse(normalized);
    if (literal != null) return _isPrivateAddress(literal);

    // Dotless hosts are usually local network names.
    if (!normalized.contains('.')) return true;
    return false;
  }

  static String _normalizeHost(String host) {
    var h = host.trim().toLowerCase();
    if (h.startsWith('[') && h.endsWith(']')) {
      h = h.substring(1, h.length - 1);
    }
    if (h.endsWith('.')) h = h.substring(0, h.length - 1);
    return h;
  }

  static bool _isPrivateAddress(InternetAddress address) {
    if (address.isLoopback || address.isLinkLocal || address.isMulticast) {
      return true;
    }
    if (address.type == InternetAddressType.IPv4) {
      final b = address.rawAddress;
      if (b.isEmpty) return true;
      final first = b[0];
      final second = b.length > 1 ? b[1] : 0;
      return first == 10 ||
          first == 127 ||
          first == 0 ||
          (first == 169 && second == 254) ||
          (first == 172 && second >= 16 && second <= 31) ||
          (first == 192 && second == 168) ||
          (first == 100 && second >= 64 && second <= 127);
    }

    if (address.type == InternetAddressType.IPv6) {
      final b = address.rawAddress;
      if (b.isEmpty) return true;
      final first = b[0];
      final second = b.length > 1 ? b[1] : 0;
      return address.address == '::1' ||
          (first & 0xfe) == 0xfc ||
          (first == 0xfe && (second & 0xc0) == 0x80);
    }

    return true;
  }
}

final urlSecurityValidator = UrlSecurityValidator();

Future<bool> isSafePublicUrl(String url) =>
    urlSecurityValidator.isSafePublicUrl(url);

Future<bool> resolvesToPrivateIp(String host) =>
    urlSecurityValidator.resolvesToPrivateIp(host);

Future<bool> validateRedirectChain(List<String> urls) =>
    urlSecurityValidator.validateRedirectChain(urls);
