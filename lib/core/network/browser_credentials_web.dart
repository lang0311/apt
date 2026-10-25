import 'package:dio/dio.dart';
import 'package:dio/browser.dart';

void configureCredentials(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter()..withCredentials = true;
}
