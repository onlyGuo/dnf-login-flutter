import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'api_client.dart';

enum UpdatePhase { idle, checking, downloading, extracting, completed, failed }

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
    _updateState(_state.copyWith(
        phase: UpdatePhase.checking, statusMessage: '正在检查更新...'));
    try {
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

  Future<void> _performUpdate(VersionInfo info) async {
    _updateState(
      _state.copyWith(
        phase: UpdatePhase.downloading,
        statusMessage: '正在下载更新...',
        progress: 0,
        remoteVersion: info,
      ),
    );

    final tempFile = File(p.join(Directory.current.path, 'update_package.zip'));
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    await _apiClient.downloadFile(
      info.downloadUrl,
      tempFile.path,
      (received, total) {
        if (total <= 0) {
          return;
        }
        final progress = received / total;
        _updateState(
          _state.copyWith(
            phase: UpdatePhase.downloading,
            progress: progress.clamp(0, 1),
            statusMessage: '正在下载更新... ${(progress * 100).toStringAsFixed(0)}%',
            remoteVersion: info,
          ),
        );
      },
    );

    _updateState(
      _state.copyWith(
        phase: UpdatePhase.extracting,
        statusMessage: '正在解压更新...',
        progress: 1,
        remoteVersion: info,
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
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }

    await tempFile.delete();
    await writeLocalVersion(info.version);

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
