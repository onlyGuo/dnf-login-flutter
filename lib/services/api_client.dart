import 'dart:typed_data';

import 'package:dio/dio.dart';

class ApiClient {
  ApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://dnf.cv58.xyz/api/v1',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            headers: const {
              'Content-Type': 'application/json',
            },
          ),
        );

  final Dio _dio;

  Future<Response<dynamic>> login({
    required String account,
    required String password,
  }) {
    return _dio.post(
      '/client/login',
      data: {
        'accountname': account,
        'password': password,
      },
    );
  }

  Future<Response<dynamic>> register({
    required String account,
    required String password,
    required String validationIndex,
    required String captcha,
    String? recommender,
  }) {
    return _dio.post(
      '/client/register',
      data: {
        'accountname': account,
        'password': password,
        'validationIndex': validationIndex,
        'valicode': captcha,
        'recommender': recommender ?? '',
      },
    );
  }

  Future<Uint8List> fetchCaptcha(String uuid) async {
    final response = await _dio.get<List<int>>(
      '/vc/img/$uuid',
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: '验证码获取失败',
      );
    }
    return Uint8List.fromList(data);
  }

  Future<Response<dynamic>> fetchVersionInfo() {
    // return _dio.get('/client/version');
    // 先返回一个假数据
    return Future.value(
      Response(
        requestOptions: RequestOptions(path: '/client/version'),
        data: {
          'version': '1.0.0',
          'downloadUrl': 'https://dnf.cv58.xyz/download/1.png.zip',
          'description': 'Initial release.',
        },
        statusCode: 200,
      ),
    );
  }

  Future<Response<dynamic>> fetchBigPictureList() {
    // return _dio.get('/client/big-pic-list');
    return Future.value(
      Response(
        requestOptions: RequestOptions(path: '/client/big-pic-list'),
        data: [
          {
            'id': 1,
            'title': 'QQ:3346459909 群:716855350',
            'imageUrl': 'https://oss.icoding.ink/.inner/dnf/login_1.png',
          },
        ],
        statusCode: 200,
      ),
    );
  }

  Future<void> downloadFile(
    String url,
    String savePath,
    ProgressCallback onReceiveProgress,
  ) async {
    final downloadDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
    await downloadDio.download(
      url,
      savePath,
      onReceiveProgress: onReceiveProgress,
      options: Options(responseType: ResponseType.stream),
    );
  }
}
