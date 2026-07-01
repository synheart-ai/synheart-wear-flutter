/// Builds authentication headers for an outbound request.
///
/// [url] is the absolute request URL and [bodyBytes] is the exact body that
/// will be sent (null for requests without a body). When supplied, the
/// returned headers are used in place of the default app credentials.
typedef WearRequestSigner = Future<Map<String, String>> Function({
  required String method,
  required Uri url,
  List<int>? bodyBytes,
});
