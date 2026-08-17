import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// File management service
/// Per spec section 21: File operations respecting scoped storage and SAF
class FileOperationService {
  // Common document directories
  static const List<String> commonPaths = [
    'Downloads',
    'Documents',
    'Pictures',
    'Videos',
    'Music',
    'DCIM',
  ];

  /// Get application documents directory
  Future<String> getDocumentsDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// Get application cache directory
  Future<String> getCacheDirectory() async {
    final dir = await getApplicationCacheDirectory();
    return dir.path;
  }

  /// List files in a directory
  Future<List<FileInfo>> listDirectory(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        return [];
      }

      final files = <FileInfo>[];
      await for (final entity in dir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          files.add(
            FileInfo(
              name: entity.path.split('/').last,
              path: entity.path,
              isDirectory: false,
              size: stat.size,
              modified: stat.modified,
            ),
          );
        } else if (entity is Directory) {
          files.add(
            FileInfo(
              name: entity.path.split('/').last,
              path: entity.path,
              isDirectory: true,
              size: 0,
              modified: DateTime.now(),
            ),
          );
        }
      }

      // Sort: directories first, then by name
      files.sort((a, b) {
        if (a.isDirectory != b.isDirectory) {
          return a.isDirectory ? -1 : 1;
        }
        return a.name.compareTo(b.name);
      });

      return files;
    } catch (e) {
      return [];
    }
  }

  /// Search for files by name
  Future<List<FileInfo>> searchFiles(String directory, String query) async {
    try {
      final dir = Directory(directory);
      final results = <FileInfo>[];

      if (!await dir.exists()) return results;

      final queryLower = query.toLowerCase();

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final name = entity.path.split('/').last;
          if (name.toLowerCase().contains(queryLower)) {
            final stat = await entity.stat();
            results.add(
              FileInfo(
                name: name,
                path: entity.path,
                isDirectory: false,
                size: stat.size,
                modified: stat.modified,
              ),
            );
          }
        }
      }

      return results;
    } catch (e) {
      return [];
    }
  }

  /// Read text file
  Future<String> readTextFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return 'Error: File does not exist';
      }

      return await file.readAsString();
    } catch (e) {
      return 'Error reading file: $e';
    }
  }

  /// Write text to file
  Future<bool> writeTextFile(String path, String content) async {
    try {
      final file = File(path);

      // Create parent directories if needed
      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      await file.writeAsString(content);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Append text to file
  Future<bool> appendTextFile(String path, String content) async {
    try {
      final file = File(path);

      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      await file.writeAsString(content, mode: FileMode.append);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Create directory
  Future<bool> createDirectory(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Copy file
  Future<bool> copyFile(String sourcePath, String destinationPath) async {
    try {
      final source = File(sourcePath);
      if (!await source.exists()) {
        return false;
      }

      // Create destination directory if needed
      final destDir = File(destinationPath).parent;
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }

      await source.copy(destinationPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Copy directory recursively
  Future<bool> copyDirectory(String sourcePath, String destinationPath) async {
    try {
      final source = Directory(sourcePath);
      if (!await source.exists()) {
        return false;
      }

      final dest = Directory(destinationPath);
      if (!await dest.exists()) {
        await dest.create(recursive: true);
      }

      await for (final entity in source.list(recursive: false)) {
        final destPath = '$destinationPath/${entity.path.split('/').last}';

        if (entity is File) {
          await entity.copy(destPath);
        } else if (entity is Directory) {
          await copyDirectory(entity.path, destPath);
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Move file
  Future<bool> moveFile(String sourcePath, String destinationPath) async {
    try {
      final source = File(sourcePath);
      if (!await source.exists()) {
        return false;
      }

      // Create destination directory if needed
      final destDir = File(destinationPath).parent;
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }

      await source.rename(destinationPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Rename file
  Future<bool> renameFile(String path, String newName) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return false;
      }

      final newPath = '${file.parent.path}/$newName';
      await file.rename(newPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete file
  Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return false;
      }

      await file.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete directory
  Future<bool> deleteDirectory(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        return false;
      }

      await dir.delete(recursive: true);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get file info (size, modified date, etc.)
  Future<FileInfo?> getFileInfo(String path) async {
    try {
      if (await FileSystemEntity.type(path) == FileSystemEntityType.file) {
        final file = File(path);
        final stat = await file.stat();
        return FileInfo(
          name: path.split('/').last,
          path: path,
          isDirectory: false,
          size: stat.size,
          modified: stat.modified,
        );
      } else if (await FileSystemEntity.type(path) ==
          FileSystemEntityType.directory) {
        return FileInfo(
          name: path.split('/').last,
          path: path,
          isDirectory: true,
          size: 0,
          modified: DateTime.now(),
        );
      }
    } catch (e) {}

    return null;
  }

  /// Format file size for display
  static String formatFileSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    int unitIndex = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
  }
}

/// File information
class FileInfo {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime modified;

  FileInfo({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modified,
  });

  String get formattedSize => FileOperationService.formatFileSize(size);

  String get type {
    if (isDirectory) return 'Folder';

    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'PDF Document';
      case 'doc':
      case 'docx':
        return 'Word Document';
      case 'xls':
      case 'xlsx':
        return 'Spreadsheet';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'Image';
      case 'mp4':
      case 'avi':
      case 'mkv':
        return 'Video';
      case 'mp3':
      case 'wav':
      case 'flac':
        return 'Audio';
      case 'txt':
        return 'Text File';
      default:
        return 'File';
    }
  }
}
