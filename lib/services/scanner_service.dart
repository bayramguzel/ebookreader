import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fb2_parse/fb2_parse.dart';
import 'package:epubx/epubx.dart' as epub;
import 'package:image/image.dart' as img;
import 'package:archive/archive.dart' as zip;
import 'package:pdfx/pdfx.dart';
import '../models/book.dart';

class ScannerService {
  final List<String> supportedExtensions = [
    'pdf',
    'epub',
    'fb2',
    'txt',
    'cbz',
    'html',
    'htm',
    'mobi',
    'azw',
    'azw3',
    'prc',
    'xml',
    'md',
  ];

  Future<List<Book>> scanForBooks({Directory? customDirectory}) async {
    List<Book> foundBooks = [];

    try {
      if (customDirectory != null) {
        await _scanDirectories([customDirectory], foundBooks);
        return foundBooks;
      }

      if (Platform.isAndroid) {
        // Android 11 (API 30) ve üzeri için MANAGE_EXTERNAL_STORAGE gerekebilir
        // Ancak Download ve Documents klasörleri için bazen normal izinler yeterli olabilir.
        bool granted = await Permission.storage.request().isGranted;
        if (!granted) {
          granted = await Permission.manageExternalStorage.request().isGranted;
        }

        if (granted) {
          final directories = [
            Directory('/storage/emulated/0/Download'),
            Directory('/storage/emulated/0/Documents'),
          ];
          await _scanDirectories(directories, foundBooks);
        } else {
          print('Depolama izni reddedildi.');
        }
      } else if (Platform.isIOS) {
        // iOS Dosyalar / Documents dizini ve Inbox
        final docDir = await getApplicationDocumentsDirectory();
        List<Directory> dirsToScan = [docDir];
        final inboxDir = Directory('${docDir.path}/Inbox');
        if (await inboxDir.exists()) {
          dirsToScan.add(inboxDir);
        }
        await _scanDirectories(dirsToScan, foundBooks);
      } else if (Platform.isWindows) {
        final docDir = await getApplicationDocumentsDirectory();
        final downloadDir = Directory(
          '${Platform.environment['USERPROFILE']}\\Downloads',
        );

        List<Directory> dirsToScan = [docDir];
        if (await downloadDir.exists()) {
          dirsToScan.add(downloadDir);
        }

        await _scanDirectories(dirsToScan, foundBooks);
      }
    } catch (e) {
      print('Tarama sırasında genel hata: $e');
    }

    return foundBooks;
  }

  Future<Book?> processSingleFile(String path) async {
    if (!await File(path).exists()) return null;

    String ext = path.split('.').last.toLowerCase();
    if (supportedExtensions.contains(ext)) {
      String name = path.split(Platform.pathSeparator).last;
      String? coverPath;

      if (ext == 'fb2') {
        coverPath = await _extractFb2Cover(path, name);
      } else if (ext == 'pdf') {
        coverPath = await _extractPdfCover(path, name);
      } else if (ext == 'epub') {
        coverPath = await _extractEpubCover(path, name);
      } else if (ext == 'cbz') {
        coverPath = await _extractCbzCover(path, name);
      }

      return Book(path, name, coverPath: coverPath, ext: ext);
    }
    return null;
  }

  Future<void> _scanDirectories(
    List<Directory> directories,
    List<Book> foundBooks,
  ) async {
    for (var dir in directories) {
      if (await dir.exists()) {
        try {
          await for (var entity in dir.list(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is File) {
              String path = entity.path;
              String ext = path.split('.').last.toLowerCase();
              if (supportedExtensions.contains(ext)) {
                String name = path.split(Platform.pathSeparator).last;
                String? coverPath;

                // Kapak resmi denemesi
                if (ext == 'fb2') {
                  coverPath = await _extractFb2Cover(path, name);
                } else if (ext == 'pdf') {
                  coverPath = await _extractPdfCover(path, name);
                } else if (ext == 'epub') {
                  coverPath = await _extractEpubCover(path, name);
                } else if (ext == 'cbz') {
                  coverPath = await _extractCbzCover(path, name);
                }

                foundBooks.add(
                  Book(path, name, coverPath: coverPath, ext: ext),
                );
              }
            }
          }
        } catch (e) {
          print('Dizin tarama hatası ($dir): $e');
        }
      }
    }
  }

  Future<String?> _extractPdfCover(String path, String name) async {
    try {
      final document = await PdfDocument.openFile(path);
      final page = await document.getPage(1);
      final pageImage = await page.render(
        width: page.width,
        height: page.height,
        format: PdfPageImageFormat.png,
      );
      await page.close();
      await document.close();

      if (pageImage != null) {
        final tempDir = await getTemporaryDirectory();
        final coverFile = File('${tempDir.path}/${name}_cover.png');
        await coverFile.writeAsBytes(pageImage.bytes);
        return coverFile.path;
      }
    } catch (e) {
      print('PDF kapak çıkarma hatası: $e');
    }
    return null;
  }

  Future<String?> _extractFb2Cover(String path, String name) async {
    try {
      final fb2Book = FB2Book(path);
      await fb2Book.parse();
      if (fb2Book.images.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${name}_cover.png');
        await tempFile.writeAsBytes(
          base64Decode(fb2Book.images.first.bytes.trim()),
        );
        return tempFile.path;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _extractEpubCover(String path, String name) async {
    try {
      final bytes = await File(path).readAsBytes();
      final epubBook = await epub.EpubReader.readBook(bytes);
      final coverImage = epubBook.CoverImage;
      if (coverImage != null) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${name}_cover.png');
        final encoded = img.encodePng(coverImage);
        await tempFile.writeAsBytes(encoded);
        return tempFile.path;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _extractCbzCover(String path, String name) async {
    try {
      final bytes = await File(path).readAsBytes();
      final archive = zip.ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        if (file.isFile) {
          final nameLower = file.name.toLowerCase();
          if (nameLower.endsWith('.jpg') ||
              nameLower.endsWith('.jpeg') ||
              nameLower.endsWith('.png')) {
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/${name}_cover.png');
            await tempFile.writeAsBytes(file.content as List<int>);
            return tempFile.path;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
