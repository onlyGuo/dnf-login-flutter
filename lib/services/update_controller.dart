import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'api_client.dart';

enum UpdatePhase { idle, checking, downloading, extracting, completed, failed }

const _scriptFileName = 'Script.pvf';

class VersionInfo {
  VersionInfo({
    required this.version,
    required this.downloadUrl,
    required this.description,
  });

  final String version;
  final String downloadUrl;
  final String description;

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      version: json['version']?.toString() ?? '',
      downloadUrl: json['downloadUrl']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }
}

class BigPictureItem {
  BigPictureItem({
    required this.id,
    required this.title,
    required this.imageUrl,
  });

  final int id;
  final String title;
  final String imageUrl;

  factory BigPictureItem.fromJson(Map<String, dynamic> json) {
    return BigPictureItem(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
    );
  }
}

class UpdateState {
  UpdateState({
    required this.phase,
    required this.progress,
    this.statusMessage,
    this.errorMessage,
    this.remoteVersion,
  });

  final UpdatePhase phase;
  final double progress;
  final String? statusMessage;
  final String? errorMessage;
  final VersionInfo? remoteVersion;

  bool get isBusy =>
      phase == UpdatePhase.checking ||
      phase == UpdatePhase.downloading ||
      phase == UpdatePhase.extracting;
  bool get shouldBlockUI => isBusy || phase == UpdatePhase.failed;

  UpdateState copyWith({
    UpdatePhase? phase,
    double? progress,
    String? statusMessage,
    String? errorMessage,
    VersionInfo? remoteVersion,
  }) {
    return UpdateState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage ?? this.errorMessage,
      remoteVersion: remoteVersion ?? this.remoteVersion,
    );
  }

  static UpdateState initial() => UpdateState(
        phase: UpdatePhase.idle,
        progress: 0,
      );
}

Future<String?> readLocalVersion() async {
  try {
    final file = File('${Directory.current.path}/version.json');
    if (!await file.exists()) {
      return null;
    }
    final content = await file.readAsString();
    final dynamic jsonData = jsonDecode(content);
    if (jsonData is Map<String, dynamic>) {
      final version = jsonData['version'];
      return version?.toString();
    }
    return null;
  } catch (_) {
    return null;
  }
}

Future<void> writeLocalVersion(String version) async {
  final file = File('${Directory.current.path}/version.json');
  await file.writeAsString(jsonEncode({'version': version}));
}

class UpdateController extends ChangeNotifier {
  UpdateController(this._apiClient);

  final ApiClient _apiClient;

  UpdateState _state = UpdateState.initial();
  UpdateState get state => _state;

  Future<void> checkAndUpdate() async {
    try {
      await _ensureBasePackage();

      _updateState(_state.copyWith(
          phase: UpdatePhase.checking,
          statusMessage: '正在检查更新...',
          progress: 0));

      final response = await _apiClient.fetchVersionInfo();
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('版本信息格式不正确');
      }
      final versionInfo = VersionInfo.fromJson(data);
      final localVersion = await readLocalVersion();
      if (localVersion == null || localVersion != versionInfo.version) {
        await _performUpdate(versionInfo);
      } else {
        _updateState(
            UpdateState.initial().copyWith(remoteVersion: versionInfo));
      }
    } catch (error) {
      _updateState(
        _state.copyWith(
          phase: UpdatePhase.failed,
          errorMessage: error.toString(),
          statusMessage: '更新失败',
        ),
      );
    } finally {
      if (_state.phase != UpdatePhase.failed &&
          _state.phase != UpdatePhase.completed) {
        _updateState(UpdateState.initial()
            .copyWith(remoteVersion: _state.remoteVersion));
      }
    }
  }

  Future<void> _ensureBasePackage() async {
    if (!Platform.isWindows) {
      return;
    }

    final scriptFile = File(p.join(Directory.current.path, _scriptFileName));
    if (await scriptFile.exists()) {
      return;
    }

    _updateState(
      _state.copyWith(
        phase: UpdatePhase.checking,
        statusMessage: '正在准备初始资源...',
        progress: 0,
      ),
    );

    final response = await _apiClient.fetchFullPackageInfo();
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('完整资源信息格式不正确');
    }
    final downloadUrl = data['downloadUrl']?.toString() ?? '';
    if (downloadUrl.isEmpty) {
      throw Exception('完整资源下载地址为空');
    }

    await _downloadAndExtractArchive(
      url: downloadUrl,
      tempFileName: 'full_package.zip',
      downloadingLabel: '正在下载完整资源...',
      extractingLabel: '正在解压完整资源...',
    );
  }

  Future<void> _downloadAndExtractArchive({
    required String url,
    required String tempFileName,
    required String downloadingLabel,
    required String extractingLabel,
    VersionInfo? versionInfo,
    bool writeVersion = false,
  }) async {
    _updateState(
      _state.copyWith(
        phase: UpdatePhase.downloading,
        statusMessage: '$downloadingLabel 0%',
        progress: 0,
        remoteVersion: versionInfo ?? _state.remoteVersion,
      ),
    );

    final tempFile = File(p.join(Directory.current.path, tempFileName));
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    await _apiClient.downloadFile(
      url,
      tempFile.path,
      (received, total) {
        if (total <= 0) {
          _updateState(
            _state.copyWith(
              phase: UpdatePhase.downloading,
              statusMessage: downloadingLabel,
              progress: 0,
              remoteVersion: versionInfo ?? _state.remoteVersion,
            ),
          );
          return;
        }
        final double progress = (received / total).clamp(0.0, 1.0);
        _updateState(
          _state.copyWith(
            phase: UpdatePhase.downloading,
            progress: progress,
            statusMessage:
                '$downloadingLabel ${(progress * 100).toStringAsFixed(0)}%',
            remoteVersion: versionInfo ?? _state.remoteVersion,
          ),
        );
      },
    );

    _updateState(
      _state.copyWith(
        phase: UpdatePhase.extracting,
        statusMessage: extractingLabel,
        progress: 1,
        remoteVersion: versionInfo ?? _state.remoteVersion,
      ),
    );

    final bytes = await tempFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final targetDir = Directory.current;
    for (final file in archive) {
      final filePath = p.join(targetDir.path, file.name);
      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>, flush: true);
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }

    await tempFile.delete();

    if (writeVersion && versionInfo != null) {
      await writeLocalVersion(versionInfo.version);
    }
  }

  Future<void> _performUpdate(VersionInfo info) async {
    await _downloadAndExtractArchive(
      url: info.downloadUrl,
      tempFileName: 'update_package.zip',
      downloadingLabel: '正在下载更新...',
      extractingLabel: '正在解压更新...',
      versionInfo: info,
      writeVersion: true,
    );

    _updateState(
      _state.copyWith(
        phase: UpdatePhase.completed,
        statusMessage: '更新完成',
        progress: 1,
        remoteVersion: info,
      ),
    );
  }

  void _updateState(UpdateState newState) {
    _state = newState;
    notifyListeners();
  }
}
