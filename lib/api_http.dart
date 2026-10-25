import 'dart:convert';

import 'package:http/http.dart' as package_http;

import 'mobile_session.dart';
import 'red.dart';

export 'package:http/http.dart' show MultipartFile, Response;

const _requestTimeout = Duration(seconds: 15);

Map<String, String> _withAuthorization(Uri url, Map<String, String>? headers) {
  final result = <String, String>{...?headers};
  final token = MobileSession.accessToken;
  final apiHost = Uri.parse(urlCentral).host;
  if (token != null && url.host == apiHost) {
    result['Authorization'] = 'Bearer $token';
  }
  return result;
}

Future<package_http.Response> get(
  Uri url, {
  Map<String, String>? headers,
}) =>
    package_http
        .get(url, headers: _withAuthorization(url, headers))
        .timeout(_requestTimeout);

Future<package_http.Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    package_http
        .post(
          url,
          headers: _withAuthorization(url, headers),
          body: body,
          encoding: encoding,
        )
        .timeout(_requestTimeout);

Future<package_http.Response> delete(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    package_http
        .delete(
          url,
          headers: _withAuthorization(url, headers),
          body: body,
          encoding: encoding,
        )
        .timeout(_requestTimeout);

class MultipartRequest extends package_http.MultipartRequest {
  MultipartRequest(super.method, super.url) {
    headers.addAll(_withAuthorization(url, null));
  }
}
