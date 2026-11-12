import 'package:dio/dio.dart';
import 'package:flowers/core/network/api_client.dart';
import 'package:flowers/core/network/json_utils.dart';
import 'package:flowers/features/files/domain/entities/file_meta.dart';

class FilesRepository {
  FilesRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<FileMeta> upload({
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _api.postMultipart('/files/files', formData: form);
    return FileMeta.fromJson(asJsonMap(res.data));
  }

  Future<FileMeta> metadata(String id) {
    return _api.get<FileMeta>(
      '/files/files/$id/metadata',
      parse: (data) => FileMeta.fromJson(asJsonMap(data)),
    );
  }

  Future<List<int>> download(String id) => _api.getBytes('/files/files/$id');
}
