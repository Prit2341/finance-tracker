import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:finance_tracker/shared/database/app_database.dart';

/// Metadata for a tracked model version.
class ModelVersion {
  final String id;
  final String modelType;
  final int version;
  final double? accuracy;
  final DateTime createdAt;
  final bool isActive;

  const ModelVersion({
    required this.id,
    required this.modelType,
    required this.version,
    this.accuracy,
    required this.createdAt,
    this.isActive = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'model_type': modelType,
        'version': version,
        'accuracy': accuracy,
        'created_at': createdAt.toIso8601String(),
        'is_active': isActive ? 1 : 0,
      };

  factory ModelVersion.fromMap(Map<String, dynamic> map) => ModelVersion(
        id: map['id'] as String,
        modelType: map['model_type'] as String,
        version: (map['version'] as int?) ?? 1,
        accuracy: (map['accuracy'] as num?)?.toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
        isActive: (map['is_active'] as int?) == 1,
      );
}

/// Manages model versioning, swapping, and rollback.
///
/// Models live in the app's documents directory under `models/`.
/// The base model ships with the APK in assets; personalized models
/// are written to the documents directory after on-device retraining.
///
/// Workflow:
/// 1. On first launch, copy base model from assets to documents dir
/// 2. After retraining, save new model as next version
/// 3. Validate new model; if better, activate it
/// 4. If worse, rollback to previous version
class ModelManager {
  static const String _modelsDir = 'models';

  /// Get the directory where personalized models are stored.
  Future<Directory> get _modelDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _modelsDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Path to a specific model file in the documents directory.
  Future<String> modelPath(String modelType, {int? version}) async {
    final dir = await _modelDirectory;
    final v = version ?? await getActiveVersion(modelType);
    return p.join(dir.path, '${modelType}_v$v.tflite');
  }

  /// Copy the base model from assets to the documents directory if not present.
  Future<void> ensureBaseModel(String modelType, String assetPath) async {
    final dir = await _modelDirectory;
    final basePath = p.join(dir.path, '${modelType}_v1.tflite');

    if (!await File(basePath).exists()) {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      await File(basePath).writeAsBytes(bytes);

      // Register base model in metadata
      await _registerVersion(
        ModelVersion(
          id: '${modelType}_v1',
          modelType: modelType,
          version: 1,
          createdAt: DateTime.now(),
          isActive: true,
        ),
      );
    }
  }

  /// Save a new model version after retraining.
  /// Returns the new version number.
  Future<int> saveNewVersion(
    String modelType,
    List<int> modelBytes, {
    double? accuracy,
  }) async {
    final dir = await _modelDirectory;
    final currentVersion = await getActiveVersion(modelType);
    final newVersion = currentVersion + 1;

    final filePath = p.join(dir.path, '${modelType}_v$newVersion.tflite');
    await File(filePath).writeAsBytes(modelBytes);

    await _registerVersion(
      ModelVersion(
        id: '${modelType}_v$newVersion',
        modelType: modelType,
        version: newVersion,
        accuracy: accuracy,
        createdAt: DateTime.now(),
        isActive: false, // Not active until explicitly activated
      ),
    );

    return newVersion;
  }

  /// Activate a specific model version (deactivates others of same type).
  Future<void> activate(String modelType, int version) async {
    final db = await AppDatabase.database;

    // Deactivate all versions of this model type
    await db.update(
      'model_metadata',
      {'is_active': 0},
      where: 'model_type = ?',
      whereArgs: [modelType],
    );

    // Activate the target version
    await db.update(
      'model_metadata',
      {'is_active': 1},
      where: 'id = ?',
      whereArgs: ['${modelType}_v$version'],
    );
  }

  /// Rollback to the previous active version.
  Future<bool> rollback(String modelType) async {
    final versions = await getVersionHistory(modelType);
    if (versions.length < 2) return false;

    // Find the currently active version and the one before it
    final activeIdx = versions.indexWhere((v) => v.isActive);
    if (activeIdx < 0 || activeIdx + 1 >= versions.length) return false;

    final previousVersion = versions[activeIdx + 1];
    await activate(modelType, previousVersion.version);
    return true;
  }

  /// Get the currently active version number for a model type.
  Future<int> getActiveVersion(String modelType) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      'model_metadata',
      where: 'model_type = ? AND is_active = 1',
      whereArgs: [modelType],
    );

    if (rows.isEmpty) return 1;
    return (rows.first['version'] as int?) ?? 1;
  }

  /// Get the active model's file path (returns null if no model exists).
  Future<String?> getActiveModelPath(String modelType) async {
    final path = await modelPath(modelType);
    if (await File(path).exists()) return path;
    return null;
  }

  /// Get version history for a model type (newest first).
  Future<List<ModelVersion>> getVersionHistory(String modelType) async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      'model_metadata',
      where: 'model_type = ?',
      whereArgs: [modelType],
      orderBy: 'version DESC',
    );
    return rows.map(ModelVersion.fromMap).toList();
  }

  /// Get accuracy improvement from base to current active.
  Future<double?> getAccuracyImprovement(String modelType) async {
    final versions = await getVersionHistory(modelType);
    if (versions.length < 2) return null;

    final active = versions.firstWhere((v) => v.isActive,
        orElse: () => versions.first);
    final base = versions.last; // v1 is always the base

    if (active.accuracy == null || base.accuracy == null) return null;
    return active.accuracy! - base.accuracy!;
  }

  /// Delete old versions, keeping the active one and the previous one.
  Future<void> pruneOldVersions(String modelType) async {
    final versions = await getVersionHistory(modelType);
    if (versions.length <= 2) return;

    final dir = await _modelDirectory;
    final activeVersion = await getActiveVersion(modelType);

    for (final v in versions) {
      // Keep active and the one right before it
      if (v.version == activeVersion || v.version == activeVersion - 1) {
        continue;
      }
      // Also always keep v1 (base)
      if (v.version == 1) continue;

      // Delete file and metadata
      final filePath = p.join(dir.path, '${modelType}_v${v.version}.tflite');
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      final db = await AppDatabase.database;
      await db.delete(
        'model_metadata',
        where: 'id = ?',
        whereArgs: [v.id],
      );
    }
  }

  Future<void> _registerVersion(ModelVersion version) async {
    final db = await AppDatabase.database;
    await db.insert('model_metadata', version.toMap());
  }
}
