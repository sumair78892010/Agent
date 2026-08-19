import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:agent_cypher/services/file_operation_service.dart';

void main() {
  late FileOperationService svc;
  late String tempDir;

  setUp(() {
    svc = FileOperationService();
    tempDir = Directory.systemTemp.path;
  });

  // ----------------------------------------------------------------
  // writeTextFile / readTextFile
  // ----------------------------------------------------------------

  group('writeTextFile and readTextFile', () {
    test('round-trips content correctly', () async {
      final path = p.join(tempDir, 'roundtrip_test.txt');
      const content = 'Hello from Agent Cypher!';
      expect(await svc.writeTextFile(path, content), isTrue);

      final read = await svc.readTextFile(path);
      expect(read, equals(content));

      await File(path).delete();
    });

    test('creates parent directories automatically', () async {
      final path = p.join(tempDir, 'nested', 'sub', 'dir', 'auto.txt');
      expect(await svc.writeTextFile(path, 'nested content'), isTrue);
      expect(await File(path).exists(), isTrue);

      // Cleanup
      await File(path).delete();
      await Directory(p.join(tempDir, 'nested', 'sub', 'dir'))
          .delete();
      await Directory(p.join(tempDir, 'nested', 'sub')).delete();
      await Directory(p.join(tempDir, 'nested')).delete();
    });

    test('overwrites existing file', () async {
      final path = p.join(tempDir, 'overwrite_test.txt');
      await File(path).writeAsString('old');

      expect(await svc.writeTextFile(path, 'new'), isTrue);
      expect(await svc.readTextFile(path), equals('new'));

      await File(path).delete();
    });

    test('handles empty content', () async {
      final path = p.join(tempDir, 'empty_test.txt');
      expect(await svc.writeTextFile(path, ''), isTrue);
      expect(await svc.readTextFile(path), equals(''));

      await File(path).delete();
    });
  });

  // ----------------------------------------------------------------
  // readTextFile error cases
  // ----------------------------------------------------------------

  group('readTextFile error handling', () {
    test('returns error for non-existent file', () async {
      final result =
          await svc.readTextFile(p.join(tempDir, 'no_such_file_xyz.txt'));
      expect(result, startsWith('Error'));
    });
  });

  // ----------------------------------------------------------------
  // createDirectory / listDirectory
  // ----------------------------------------------------------------

  group('createDirectory and listDirectory', () {
    test('creates and lists a directory', () async {
      final dirPath = p.join(tempDir, 'list_test_dir');
      expect(await svc.createDirectory(dirPath), isTrue);
      expect(await Directory(dirPath).exists(), isTrue);

      // Write a file inside so listDirectory has content.
      await File(p.join(dirPath, 'a.txt')).writeAsString('aaa');
      await Directory(p.join(dirPath, 'sub')).create();

      final items = await svc.listDirectory(dirPath);
      expect(items.length, equals(2));
      // Directories sort before files.
      expect(items[0].isDirectory, isTrue);
      expect(items[0].name, equals('sub'));
      expect(items[1].isDirectory, isFalse);
      expect(items[1].name, equals('a.txt'));

      // Cleanup
      await File(p.join(dirPath, 'a.txt')).delete();
      await Directory(p.join(dirPath, 'sub')).delete();
      await Directory(dirPath).delete();
    });

    test('returns empty list for non-existent directory', () async {
      final items = await svc.listDirectory(p.join(tempDir, 'no_such_dir'));
      expect(items, isEmpty);
    });

    test('createDirectory is idempotent', () async {
      final dirPath = p.join(tempDir, 'idempotent_dir');
      expect(await svc.createDirectory(dirPath), isTrue);
      expect(await svc.createDirectory(dirPath), isTrue);

      await Directory(dirPath).delete();
    });
  });

  // ----------------------------------------------------------------
  // copyFile
  // ----------------------------------------------------------------

  group('copyFile', () {
    test('copies file content to destination', () async {
      final src = p.join(tempDir, 'copy_src.txt');
      final dst = p.join(tempDir, 'copy_dst.txt');
      await File(src).writeAsString('copy me');

      expect(await svc.copyFile(src, dst), isTrue);
      expect(await File(dst).readAsString(), equals('copy me'));
      expect(await File(src).exists(), isTrue); // source preserved

      await File(src).delete();
      await File(dst).delete();
    });

    test('creates destination parent directories', () async {
      final src = p.join(tempDir, 'copy_src2.txt');
      final dst = p.join(tempDir, 'new', 'nested', 'copy_dst2.txt');
      await File(src).writeAsString('nested copy');

      expect(await svc.copyFile(src, dst), isTrue);
      expect(await File(dst).exists(), isTrue);

      // Cleanup
      await File(src).delete();
      await File(dst).delete();
      await Directory(p.join(tempDir, 'new', 'nested')).delete(recursive: true);
    });

    test('returns false for non-existent source', () async {
      final result = await svc.copyFile(
        p.join(tempDir, 'no_such_src.txt'),
        p.join(tempDir, 'dst.txt'),
      );
      expect(result, isFalse);
    });
  });

  // ----------------------------------------------------------------
  // moveFile
  // ----------------------------------------------------------------

  group('moveFile', () {
    test('moves file and removes source', () async {
      final src = p.join(tempDir, 'move_src.txt');
      final dst = p.join(tempDir, 'move_dst.txt');
      await File(src).writeAsString('move me');

      expect(await svc.moveFile(src, dst), isTrue);
      expect(await File(dst).readAsString(), equals('move me'));
      expect(await File(src).exists(), isFalse);

      await File(dst).delete();
    });

    test('returns false for non-existent source', () async {
      final result = await svc.moveFile(
        p.join(tempDir, 'no_such_move.txt'),
        p.join(tempDir, 'dst.txt'),
      );
      expect(result, isFalse);
    });
  });

  // ----------------------------------------------------------------
  // deleteFile / deleteDirectory
  // ----------------------------------------------------------------

  group('deleteFile and deleteDirectory', () {
    test('deletes an existing file', () async {
      final path = p.join(tempDir, 'to_delete.txt');
      await File(path).writeAsString('bye');

      expect(await svc.deleteFile(path), isTrue);
      expect(await File(path).exists(), isFalse);
    });

    test('returns false for non-existent file', () async {
      expect(
        await svc.deleteFile(p.join(tempDir, 'no_such_del.txt')),
        isFalse,
      );
    });

    test('deletes a directory recursively', () async {
      final dir = p.join(tempDir, 'del_dir');
      await Directory(dir).create(recursive: true);
      await File(p.join(dir, 'inner.txt')).writeAsString('x');

      expect(await svc.deleteDirectory(dir), isTrue);
      expect(await Directory(dir).exists(), isFalse);
    });
  });

  // ----------------------------------------------------------------
  // searchFiles
  // ----------------------------------------------------------------

  group('searchFiles', () {
    test('finds files matching query', () async {
      final dir = p.join(tempDir, 'search_test_dir');
      await Directory(dir).create();
      await File(p.join(dir, 'report_q3.pdf')).writeAsString('data');
      await File(p.join(dir, 'notes.txt')).writeAsString('text');

      final results = await svc.searchFiles(dir, 'report');
      expect(results.length, equals(1));
      expect(results.first.name, equals('report_q3.pdf'));

      // Cleanup
      await File(p.join(dir, 'report_q3.pdf')).delete();
      await File(p.join(dir, 'notes.txt')).delete();
      await Directory(dir).delete();
    });

    test('returns empty for non-existent directory', () async {
      final results =
          await svc.searchFiles(p.join(tempDir, 'no_such_search'), 'x');
      expect(results, isEmpty);
    });

    test('search is case-insensitive', () async {
      final dir = p.join(tempDir, 'search_ci_dir');
      await Directory(dir).create();
      await File(p.join(dir, 'MyFile.txt')).writeAsString('');

      final results = await svc.searchFiles(dir, 'MYFILE');
      expect(results.length, equals(1));

      await File(p.join(dir, 'MyFile.txt')).delete();
      await Directory(dir).delete();
    });
  });

  // ----------------------------------------------------------------
  // getFileInfo
  // ----------------------------------------------------------------

  group('getFileInfo', () {
    test('returns info for an existing file', () async {
      final path = p.join(tempDir, 'info_test.txt');
      await File(path).writeAsString('info content here');

      final info = await svc.getFileInfo(path);
      expect(info, isNotNull);
      expect(info!.name, equals('info_test.txt'));
      expect(info.isDirectory, isFalse);
      expect(info.size, greaterThan(0));

      await File(path).delete();
    });

    test('returns info for an existing directory', () async {
      final path = p.join(tempDir, 'info_dir');
      await Directory(path).create();

      final info = await svc.getFileInfo(path);
      expect(info, isNotNull);
      expect(info!.isDirectory, isTrue);

      await Directory(path).delete();
    });

    test('returns null for non-existent path', () async {
      final info =
          await svc.getFileInfo(p.join(tempDir, 'no_such_info_xyz'));
      expect(info, isNull);
    });
  });

  // ----------------------------------------------------------------
  // formatFileSize
  // ----------------------------------------------------------------

  group('formatFileSize', () {
    test('formats bytes correctly', () {
      expect(FileOperationService.formatFileSize(0), equals('0.00 B'));
      expect(FileOperationService.formatFileSize(512), equals('512.00 B'));
      expect(FileOperationService.formatFileSize(1024), equals('1.00 KB'));
      expect(FileOperationService.formatFileSize(1048576),
          equals('1.00 MB'));
      expect(FileOperationService.formatFileSize(1073741824),
          equals('1.00 GB'));
    });
  });

  // ----------------------------------------------------------------
  // FileInfo.type
  // ----------------------------------------------------------------

  group('FileInfo.type', () {
    test('identifies file types by extension', () {
      expect(
        FileInfo(
          name: 'doc.pdf',
          path: '/a/doc.pdf',
          isDirectory: false,
          size: 100,
          modified: DateTime.now(),
        ).type,
        equals('PDF Document'),
      );
      expect(
        FileInfo(
          name: 'photo.jpg',
          path: '/a/photo.jpg',
          isDirectory: false,
          size: 200,
          modified: DateTime.now(),
        ).type,
        equals('Image'),
      );
      expect(
        FileInfo(
          name: 'folder',
          path: '/a/folder',
          isDirectory: true,
          size: 0,
          modified: DateTime.now(),
        ).type,
        equals('Folder'),
      );
      expect(
        FileInfo(
          name: 'data.xlsx',
          path: '/a/data.xlsx',
          isDirectory: false,
          size: 300,
          modified: DateTime.now(),
        ).type,
          equals('Spreadsheet'),
      );
    });
  });
}
