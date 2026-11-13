import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:epub_view/epub_view.dart' hide Image;
import 'package:fb2_parse/fb2_parse.dart';
import 'package:glassmorphic_ui_kit/glassmorphic_ui_kit.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive.dart' as zip;
import 'package:flutter_html/flutter_html.dart';
import 'package:dart_mobi/dart_mobi.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_microsoft_clarity/flutter_microsoft_clarity.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'models/book.dart';
import 'services/settings_service.dart';
import 'services/scanner_service.dart';
import 'services/localization_service.dart';
import 'services/ad_service.dart';
import 'services/platform_utils.dart';
import 'screens/settings_screen.dart';
import 'widgets/ad_banner_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Unity LevelPlay / Unity Ads
  unawaited(AdService().initialize());

  // Initialize Microsoft Clarity
  try {
    FlutterMicrosoftClarity().init(projectId: 'utjuctedx0');
  } catch (e) {
    debugPrint('Clarity init error: $e');
  }

  final settingsService = SettingsService();
  await settingsService.init();
  final showSplash = await settingsService.shouldShowSplash();

  runApp(MyApp(initialShowSplash: showSplash));
}

class MyApp extends StatefulWidget {
  final bool initialShowSplash;
  const MyApp({super.key, required this.initialShowSplash});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SettingsService _settingsService = SettingsService();
  bool _isDarkMode = false;
  String _language = 'tr';
  Color _themeColor = Colors.green;
  late bool _showSplash;

  @override
  void initState() {
    super.initState();
    _showSplash = widget.initialShowSplash;
    _settingsService.addListener(_updateSettings);
    _updateSettings();
  }

  @override
  void dispose() {
    _settingsService.removeListener(_updateSettings);
    super.dispose();
  }

  void _updateSettings() async {
    final isDark = await _settingsService.getDarkMode();
    final lang = await _settingsService.getLanguage();
    final colorVal = await _settingsService.getThemeColor();
    LocalizationService.currentLanguage = lang;
    if (mounted) {
      setState(() {
        _isDarkMode = isDark;
        _language = lang;
        _themeColor = Color(colorVal);
      });
    }
  }

  void _onSplashFinished() {
    if (mounted) {
      setState(() {
        _showSplash = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return MaterialApp(
          title: LocalizationService.translate('app_name', _language),
          locale: Locale(_language),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('tr'), Locale('de')],
          themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _themeColor,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _themeColor,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: _showSplash
              ? SplashScreen(onFinished: _onSplashFinished, language: _language)
              : const MainNavigation(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  final SettingsService _settingsService = SettingsService();
  final ScannerService _scannerService = ScannerService();
  List<Book> _allBooks = [];
  bool _isLoading = true;
  String _language = 'tr';

  @override
  void initState() {
    super.initState();
    _settingsService.addListener(_loadData);
    _loadData();
  }

  @override
  void dispose() {
    _settingsService.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    final loadedBooks = await _settingsService.loadBooks();
    final lang = await _settingsService.getLanguage();
    LocalizationService.currentLanguage = lang;

    // Copy sample books on first load
    bool addedNew = false;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final sampleBooks = ['alice_in_wonderland.epub', 'frankenstein.epub'];

      for (var bookFile in sampleBooks) {
        final targetPath = '${docDir.path}/$bookFile';
        final file = File(targetPath);
        if (!await file.exists()) {
          final data = await DefaultAssetBundle.of(
            context,
          ).load('assets/$bookFile');
          final bytes = data.buffer.asUint8List();
          await file.writeAsBytes(bytes, flush: true);
        }

        bool existsInLibrary = loadedBooks.any((b) => b.path == targetPath);
        if (!existsInLibrary) {
          String niceName = bookFile
              .replaceAll('.epub', '')
              .replaceAll('_', ' ');
          niceName = niceName
              .split(' ')
              .map((w) => w[0].toUpperCase() + w.substring(1))
              .join(' ');
          loadedBooks.add(Book(targetPath, niceName, ext: 'epub'));
          addedNew = true;
        }
      }
    } catch (e) {
      debugPrint('Error copying sample books: $e');
    }

    if (addedNew) {
      await _settingsService.saveBooks(loadedBooks);
    }

    if (mounted) {
      setState(() {
        _allBooks = loadedBooks;
        _language = lang;
        _isLoading = false;
      });
      _checkRatingPrompt();
    }
  }

  Future<void> _checkRatingPrompt() async {
    await _settingsService.incrementOpenCount();
    final shouldPrompt = await _settingsService.shouldPromptRating();
    if (shouldPrompt && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRatingDialog();
      });
    }
  }

  void _showRatingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _t('rate_us_title'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (index) => const Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _t('rate_us_desc'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _settingsService.setHasRated(true);
            },
            child: Text(
              _t('rate_never'),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_t('rate_later')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _settingsService.setHasRated(true);
                  await PlatformUtils.openStoreRating();
                },
                child: Text(_t('rate_now')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _t(String key) {
    return LocalizationService.translate(key, _language);
  }

  Future<void> _saveBooks() async {
    await _settingsService.saveBooks(_allBooks);
  }

  void _updateBooks(List<Book> newBooks) {
    setState(() {
      _allBooks = newBooks;
    });
    _saveBooks();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Widget> screens = [
      HomeScreen(
        books: _allBooks,
        onBooksChanged: _updateBooks,
        settingsService: _settingsService,
        scannerService: _scannerService,
      ),
      FavoritesScreen(
        books: _allBooks.where((b) => b.isFavorite).toList(),
        onBooksChanged: _updateBooks,
        allBooks: _allBooks,
        settingsService: _settingsService,
      ),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Banner reklam veya 41software.com fallback görseli tab menü üzerinde
            const AdBannerWidget(),
            NavigationBarTheme(
              data: NavigationBarThemeData(
                height: 56,
                indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    );
                  }
                  return const TextStyle(fontSize: 11);
                }),
              ),
              child: NavigationBar(
                height: 56,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.library_books_outlined, size: 22),
                    selectedIcon: const Icon(Icons.library_books, size: 22),
                    label: _t('library'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.favorite_outline, size: 22),
                    selectedIcon: const Icon(Icons.favorite, size: 22),
                    label: _t('favorites'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.settings_outlined, size: 22),
                    selectedIcon: const Icon(Icons.settings, size: 22),
                    label: _t('settings'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final List<Book> books;
  final Function(List<Book>) onBooksChanged;
  final SettingsService settingsService;
  final ScannerService scannerService;

  const HomeScreen({
    super.key,
    required this.books,
    required this.onBooksChanged,
    required this.settingsService,
    required this.scannerService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _gridView = true;
  String _searchQuery = '';
  bool _isScanning = false;
  bool _showHidden = false;
  String _language = 'tr';

  @override
  void initState() {
    super.initState();
    widget.settingsService.addListener(_loadSettings);
    _loadSettings();
  }

  @override
  void dispose() {
    widget.settingsService.removeListener(_loadSettings);
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final gridView = await widget.settingsService.getGridView();
    final language = await widget.settingsService.getLanguage();
    if (mounted) {
      setState(() {
        _gridView = gridView;
        _language = language;
      });
    }
  }

  String _t(String key) {
    return LocalizationService.translate(key, _language);
  }

  List<Book> get _filteredBooks {
    return widget.books.where((b) {
      if (!_showHidden && b.isHidden) return false;
      if (_searchQuery.isNotEmpty &&
          !b.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  void _confirmDeleteBook(Book book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('delete')),
        content: Text(_t('confirm_delete_book')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final newBooks = [...widget.books];
              newBooks.remove(book);
              widget.onBooksChanged(newBooks);
            },
            child: Text(
              _t('delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleHideBook(Book book) {
    setState(() {
      book.isHidden = !book.isHidden;
    });
    widget.onBooksChanged(widget.books);
  }

  Future<void> _scanBooks() async {
    setState(() => _isScanning = true);
    try {
      final foundBooks = await widget.scannerService.scanForBooks();

      // Sadece yeni olanları ekle
      final existingPaths = widget.books.map((b) => b.path).toSet();
      final newBooks = [...widget.books];

      int addedCount = 0;
      for (var book in foundBooks) {
        if (!existingPaths.contains(book.path)) {
          newBooks.add(book);
          addedCount++;
        }
      }

      widget.onBooksChanged(newBooks);

      if (mounted) {
        final msg = addedCount > 0
            ? '$addedCount ${_t('new_books_found')}'
            : _t('no_books_found');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${_t('scan_error')}: $e')));
      }
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _pickBook() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
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
      ],
    );

    if (result != null && result.files.isNotEmpty) {
      final newBooks = [...widget.books];
      int addedCount = 0;

      setState(() => _isScanning = true);

      try {
        for (var file in result.files) {
          if (file.path == null) continue;

          // Zaten ekli mi kontrol et
          if (newBooks.any((b) => b.path == file.path)) {
            continue;
          }

          final book = await widget.scannerService.processSingleFile(
            file.path!,
          );
          if (book != null) {
            newBooks.add(book);
            addedCount++;
          }
        }

        if (addedCount > 0) {
          widget.onBooksChanged(newBooks);
        }

        if (mounted) {
          final msg = addedCount > 0
              ? '$addedCount ${_t('new_books_found')}'
              : _t('no_books_found');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${_t('error')}: $e')));
        }
      } finally {
        setState(() => _isScanning = false);
      }
    }
  }

  void _openBook(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ReaderScreen(book: book, settingsService: widget.settingsService),
      ),
    );
  }

  void _showBookDetails(Book book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BookDetailsSheet(
          book: book,
          books: widget.books,
          onBooksChanged: widget.onBooksChanged,
          onOpenBook: _openBook,
        );
      },
    );
  }

  Future<void> _scanFolder() async {
    String? selectedDirectory = await FilePicker.getDirectoryPath();

    if (selectedDirectory != null) {
      setState(() => _isScanning = true);
      try {
        final foundBooks = await widget.scannerService.scanForBooks(
          customDirectory: Directory(selectedDirectory),
        );

        final existingPaths = widget.books.map((b) => b.path).toSet();
        final newBooks = [...widget.books];

        int addedCount = 0;
        for (var book in foundBooks) {
          if (!existingPaths.contains(book.path)) {
            newBooks.add(book);
            addedCount++;
          }
        }

        widget.onBooksChanged(newBooks);

        if (mounted) {
          final msg = addedCount > 0
              ? '$addedCount ${_t('new_books_found')}'
              : _t('no_books_found');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${_t('scan_error')}: $e')));
        }
      } finally {
        setState(() => _isScanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(_t('library')),
            pinned: true,
            actions: [
              IconButton(
                icon: Icon(
                  _showHidden ? Icons.visibility_off : Icons.visibility,
                ),
                tooltip: _showHidden
                    ? _t('hide_hidden_books')
                    : _t('show_hidden_books'),
                onPressed: () => setState(() => _showHidden = !_showHidden),
              ),
              IconButton(
                icon: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                onPressed: () async {
                  final isDark = await widget.settingsService.getDarkMode();
                  await widget.settingsService.setDarkMode(!isDark);
                },
              ),
              Builder(
                builder: (btnCtx) => IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {
                    PlatformUtils.shareText(
                      '${_t('share_app_desc')}\n\n${PlatformUtils.storeUrl}',
                      context: btnCtx,
                    );
                  },
                ),
              ),
              IconButton(
                icon: Icon(_gridView ? Icons.list : Icons.grid_view),
                onPressed: () {
                  setState(() => _gridView = !_gridView);
                  widget.settingsService.setGridView(_gridView);
                },
              ),
              if (_isScanning)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sync),
                  onSelected: (value) {
                    if (value == 'all') {
                      _scanBooks();
                    } else if (value == 'folder') {
                      _scanFolder();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'all', child: Text(_t('scan_device'))),
                    PopupMenuItem(
                      value: 'folder',
                      child: Text(_t('select_folder')),
                    ),
                  ],
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SearchBar(
                elevation: const WidgetStatePropertyAll(1),
                hintText: _t('search_books'),
                leading: const Icon(Icons.search),
                trailing: [
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _searchQuery = ''),
                    ),
                ],
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _isScanning ? null : _scanBooks,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.phonelink_ring, size: 20),
                      label: Text(
                        _t('scan_device'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _isScanning ? null : _scanFolder,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.folder_open, size: 20),
                      label: Text(
                        _t('select_folder'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_filteredBooks.isEmpty)
            SliverFillRemaining(
              child: Center(child: Text(_t('no_books_found'))),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _gridView ? _buildGridView() : _buildListView(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickBook,
        icon: const Icon(Icons.add),
        label: Text(_t('add_book')),
      ),
    );
  }

  Widget _buildGridView() {
    final books = _filteredBooks;
    final List<dynamic> items = []; // List<Book?> (çift)
    for (int i = 0; i < books.length; i += 2) {
      items.add([books[i], i + 1 < books.length ? books[i + 1] : null]);
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = items[index];
        final pair = item as List<dynamic>;
        final b1 = pair[0] as Book;
        final b2 = pair[1] as Book?;
        return Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _BookGridItem(
                  book: b1,
                  language: _language,
                  onTap: () => _showBookDetails(b1),
                  onDelete: () => _confirmDeleteBook(b1),
                  onHide: () => _toggleHideBook(b1),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: b2 != null
                    ? _BookGridItem(
                        book: b2,
                        language: _language,
                        onTap: () => _showBookDetails(b2),
                        onDelete: () => _confirmDeleteBook(b2),
                        onHide: () => _toggleHideBook(b2),
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        );
      }, childCount: items.length),
    );
  }

  Widget _buildListView() {
    final books = _filteredBooks;
    final List<dynamic> items = [];
    for (int i = 0; i < books.length; i++) {
      items.add(books[i]);
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = items[index];
        final book = item as Book;
        return _BookListItem(
          book: book,
          language: _language,
          onTap: () => _showBookDetails(book),
          onDelete: () => _confirmDeleteBook(book),
          onHide: () => _toggleHideBook(book),
        );
      }, childCount: items.length),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}

class _BookGridItem extends StatelessWidget {
  final Book book;
  final String language;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onHide;

  const _BookGridItem({
    required this.book,
    required this.language,
    required this.onTap,
    required this.onDelete,
    required this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    final pageLabel = LocalizationService.translate('page', language);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 0.75,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  book.coverPath != null
                      ? Image.file(File(book.coverPath!), fit: BoxFit.cover)
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.colorScheme.primary.withValues(
                                  alpha: 0.15,
                                ),
                                theme.colorScheme.surfaceContainerHighest,
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.menu_book_rounded,
                              size: 46,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ),
                  // Format Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        book.normalizedExt.toUpperCase(),
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  if (book.isFavorite)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                      ),
                    ),
                  if (book.lastPage > 0)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '$pageLabel ${book.lastPage}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.sp,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: onHide,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            book.isHidden
                                ? Icons.visibility
                                : Icons.visibility_off_outlined,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: onDelete,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Colors.red.shade400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookListItem extends StatelessWidget {
  final Book book;
  final String language;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onHide;

  const _BookListItem({
    required this.book,
    required this.language,
    required this.onTap,
    required this.onDelete,
    required this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    final pageLabel = LocalizationService.translate('page', language);
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(8.w),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: book.coverPath != null
              ? Image.file(
                  File(book.coverPath!),
                  width: 50.w,
                  height: 75.h,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 50.w,
                  height: 75.h,
                  color: Colors.grey[200],
                  child: const Icon(Icons.menu_book),
                ),
        ),
        subtitle: Row(
          children: [
            Text(book.normalizedExt.toUpperCase()),
            if (book.lastPage > 0) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  '$pageLabel ${book.lastPage}',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (book.isFavorite)
              const Icon(Icons.favorite, color: Colors.red, size: 20),
            IconButton(
              icon: Icon(
                book.isHidden ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey,
                size: 20,
              ),
              onPressed: onHide,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Colors.red.shade300,
                size: 20,
              ),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class FavoritesScreen extends StatefulWidget {
  final List<Book> books;
  final List<Book> allBooks;
  final Function(List<Book>) onBooksChanged;
  final SettingsService settingsService;

  const FavoritesScreen({
    super.key,
    required this.books,
    required this.allBooks,
    required this.onBooksChanged,
    required this.settingsService,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String _language = 'tr';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final lang = await widget.settingsService.getLanguage();
    if (mounted) {
      setState(() {
        _language = lang;
      });
    }
  }

  String _t(String key) {
    return LocalizationService.translate(key, _language);
  }

  void _openBook(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ReaderScreen(book: book, settingsService: widget.settingsService),
      ),
    );
  }

  void _showBookDetails(Book book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BookDetailsSheet(
          book: book,
          books: widget.allBooks,
          onBooksChanged: widget.onBooksChanged,
          onOpenBook: _openBook,
        );
      },
    );
  }

  void _removeFavorite(Book book) {
    final newBooks = [...widget.allBooks];
    final idx = newBooks.indexWhere((b) => b.path == book.path);
    if (idx != -1) {
      newBooks[idx].isFavorite = false;
      widget.onBooksChanged(newBooks);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('favorites')),
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () async {
              final isDark = await widget.settingsService.getDarkMode();
              await widget.settingsService.setDarkMode(!isDark);
            },
          ),
        ],
      ),
      body: widget.books.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite_border,
                        size: 72,
                        color: Colors.red.shade300,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _t('no_favorites_yet'),
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t('no_favorites_desc'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Navigate to Library tab
                        final nav = context
                            .findAncestorStateOfType<_MainNavigationState>();
                        nav?.setState(() => nav._selectedIndex = 0);
                      },
                      icon: const Icon(Icons.library_books_outlined),
                      label: Text(_t('library')),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.books.length,
              itemBuilder: (context, index) {
                final book = widget.books[index];
                return _BookListItem(
                  book: book,
                  language: _language,
                  onTap: () => _showBookDetails(book),
                  onDelete: () => _removeFavorite(book),
                  onHide: () {
                    final newBooks = [...widget.allBooks];
                    final idx = newBooks.indexWhere((b) => b.path == book.path);
                    if (idx != -1) {
                      newBooks[idx].isHidden = !newBooks[idx].isHidden;
                      widget.onBooksChanged(newBooks);
                    }
                  },
                );
              },
            ),
    );
  }
}

class BookDetailsSheet extends StatefulWidget {
  final Book book;
  final List<Book> books;
  final Function(List<Book>) onBooksChanged;
  final Function(Book) onOpenBook;

  const BookDetailsSheet({
    super.key,
    required this.book,
    required this.books,
    required this.onBooksChanged,
    required this.onOpenBook,
  });

  @override
  State<BookDetailsSheet> createState() => _BookDetailsSheetState();
}

class _BookDetailsSheetState extends State<BookDetailsSheet> {
  String _language = 'tr';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final lang = await SettingsService().getLanguage();
    if (mounted) {
      setState(() {
        _language = lang;
      });
    }
  }

  String _t(String key) {
    return LocalizationService.translate(key, _language);
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
      blur: 20,
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 40.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: widget.book.path,
                  child: GestureDetector(
                    onTap: () async {
                      FilePickerResult? result = await FilePicker.pickFiles(
                        type: FileType.image,
                      );
                      if (result != null && result.files.single.path != null) {
                        setState(() {
                          widget.book.coverPath = result.files.single.path;
                        });
                        widget.onBooksChanged(widget.books);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: widget.book.coverPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12.r),
                              child: Image.file(
                                File(widget.book.coverPath!),
                                width: 100.w,
                                height: 150.h,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              width: 100.w,
                              height: 150.h,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Icon(Icons.add_a_photo, size: 50.sp),
                            ),
                    ),
                  ),
                ),
                SizedBox(width: 20.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.book.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20.sp,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Format: ${widget.book.ext?.toUpperCase() ?? _t('error')}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14.sp,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          _ActionButton(
                            icon: widget.book.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Colors.red,
                            onTap: () {
                              setState(() {
                                widget.book.isFavorite =
                                    !widget.book.isFavorite;
                              });
                              widget.onBooksChanged(widget.books);
                            },
                          ),
                          SizedBox(width: 12.w),
                          Builder(
                            builder: (btnCtx) => _ActionButton(
                              icon: Icons.share,
                              color: Colors.blue,
                              onTap: () async {
                                await PlatformUtils.shareFiles(
                                  [XFile(widget.book.path)],
                                  text: widget.book.name,
                                  context: btnCtx,
                                );
                              },
                            ),
                          ),
                          SizedBox(width: 12.w),
                          _ActionButton(
                            icon: Icons.delete_outline,
                            color: Colors.orange,
                            onTap: () {
                              final newBooks = [...widget.books];
                              newBooks.remove(widget.book);
                              widget.onBooksChanged(newBooks);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            const Divider(),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _t('notes'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final note = await _showNoteDialog(
                      context,
                      widget.book.note,
                    );
                    if (note != null) {
                      setState(() {
                        widget.book.note = note;
                      });
                      widget.onBooksChanged(widget.books);
                    }
                  },
                  icon: Icon(Icons.edit, size: 18.sp),
                  label: Text(
                    widget.book.note == null || widget.book.note!.isEmpty
                        ? _t('add_note')
                        : _t('edit_note'),
                    style: TextStyle(fontSize: 14.sp),
                  ),
                ),
              ],
            ),
            if (widget.book.note != null && widget.book.note!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  widget.book.note!,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 14.sp,
                  ),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Text(
                  _t('no_notes'),
                  style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                ),
              ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              height: 56.h,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onOpenBook(widget.book);
                },
                icon: Icon(Icons.chrome_reader_mode, size: 24.sp),
                label: Text(
                  _t('start_reading'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 16.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showNoteDialog(BuildContext context, String? currentNote) {
    final controller = TextEditingController(text: currentNote);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('book_note')),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: _t('write_thoughts'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(_t('save')),
          ),
        ],
      ),
    );
  }
}

class ReaderScreen extends StatefulWidget {
  final Book book;
  final SettingsService settingsService;

  const ReaderScreen({
    super.key,
    required this.book,
    required this.settingsService,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  EpubController? _epubController;
  int? _pdfPage;
  bool _darkMode = false;
  List<int> _bookmarks = [];
  double _fontSize = 16.0;
  String _language = 'tr';

  @override
  void initState() {
    super.initState();
    _loadReaderSettings();
  }

  @override
  void dispose() {
    _saveLastPage();
    _epubController?.dispose();
    super.dispose();
  }

  String _t(String key) {
    return LocalizationService.translate(key, _language);
  }

  Future<void> _saveLastPage() async {
    int currentPage = 0;
    final ext = widget.book.normalizedExt;

    if (ext == 'pdf') {
      currentPage = _pdfViewerController.pageNumber;
    } else if (ext == 'epub' && _epubController != null) {
      // EpubView doesn't have a simple page number
    }

    if (currentPage > 0) {
      widget.book.lastPage = currentPage;
      final books = await widget.settingsService.loadBooks();
      final index = books.indexWhere((b) => b.path == widget.book.path);
      if (index != -1) {
        books[index].lastPage = currentPage;
        await widget.settingsService.saveBooks(books);
      }
    }
  }

  Future<void> _loadReaderSettings() async {
    final darkMode = await widget.settingsService.getDarkMode();
    final bookmarks = await widget.settingsService.loadBookmarks(
      widget.book.path,
    );
    final fontSize = await widget.settingsService.getFontSize();
    final language = await widget.settingsService.getLanguage();

    final ext = widget.book.normalizedExt;
    if (ext == 'epub') {
      _epubController = EpubController(
        document: EpubDocument.openFile(File(widget.book.path)),
      );
    }

    if (mounted) {
      setState(() {
        _darkMode = darkMode;
        _bookmarks = bookmarks;
        _fontSize = fontSize;
        _language = language;
      });
    }
  }

  Future<void> _saveBookmarks() async {
    await widget.settingsService.saveBookmarks(widget.book.path, _bookmarks);
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.book.path);
    if (!file.existsSync()) {
      return Scaffold(
        appBar: AppBar(title: Text(_t('error'))),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_t('file_not_found')),
              const SizedBox(height: 8),
              Text(
                widget.book.path,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_t('go_back')),
              ),
            ],
          ),
        ),
      );
    }

    final ext = widget.book.normalizedExt;
    Widget content;

    if (ext == 'pdf') {
      content = SfPdfViewer.file(
        File(widget.book.path),
        controller: _pdfViewerController,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        onDocumentLoaded: (details) {
          if (widget.book.lastPage > 0) {
            _pdfViewerController.jumpToPage(widget.book.lastPage);
          }
        },
        onDocumentLoadFailed: (details) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_t('pdf_load_failed')}: ${details.description}'),
            ),
          );
        },
        onPageChanged: (details) {
          if (mounted) {
            setState(() {
              _pdfPage = details.newPageNumber;
            });
          }
        },
      );
    } else if (ext == 'epub') {
      if (_epubController == null) {
        content = const Center(child: CircularProgressIndicator());
      } else {
        content = EpubView(
          controller: _epubController!,
          builders: EpubViewBuilders<DefaultBuilderOptions>(
            options: DefaultBuilderOptions(
              textStyle: TextStyle(
                color: _darkMode ? Colors.white : Colors.black,
                fontSize: _fontSize.sp,
                height: 1.5,
              ),
            ),
          ),
        );
      }
    } else if (ext == 'fb2') {
      content = FutureBuilder<FB2Book>(
        future: () async {
          final fb2Book = FB2Book(widget.book.path);
          await fb2Book.parse();
          return fb2Book;
        }(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('${_t('fb2_load_failed')}: ${snapshot.error}'),
            );
          } else {
            final fb2Book = snapshot.data;
            String html = '';
            if (fb2Book != null && fb2Book.body.sections != null) {
              for (var section in fb2Book.body.sections!) {
                html += section.content ?? '';
              }
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Html(
                data: html,
                style: {
                  "body": Style(
                    color: _darkMode ? Colors.white : Colors.black,
                    fontSize: FontSize(_fontSize),
                    lineHeight: LineHeight(1.5),
                  ),
                },
              ),
            );
          }
        },
      );
    } else if (ext == 'txt' || ext == 'xml' || ext == 'md') {
      content = FutureBuilder<String>(
        future: File(widget.book.path).readAsString(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('${_t('file_read_failed')}: ${snapshot.error}'),
            );
          } else {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                snapshot.data ?? '',
                style: TextStyle(
                  color: _darkMode ? Colors.white : Colors.black,
                  fontSize: _fontSize.sp,
                  height: 1.5,
                ),
              ),
            );
          }
        },
      );
    } else if (ext == 'html' || ext == 'htm') {
      content = FutureBuilder<String>(
        future: File(widget.book.path).readAsString(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('${_t('html_load_failed')}: ${snapshot.error}'),
            );
          } else {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Html(
                data: snapshot.data ?? '',
                style: {
                  "body": Style(
                    color: _darkMode ? Colors.white : Colors.black,
                    fontSize: FontSize(_fontSize.sp),
                  ),
                },
              ),
            );
          }
        },
      );
    } else if (ext == 'cbz') {
      content = CbzViewer(filePath: widget.book.path);
    } else if (ext == 'mobi' || ext == 'azw' || ext == 'azw3' || ext == 'prc') {
      content = FutureBuilder<MobiData>(
        future: () async {
          final bytes = await File(widget.book.path).readAsBytes();
          return await DartMobiReader.read(bytes);
        }(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('${_t('mobi_load_failed')}: ${snapshot.error}'),
            );
          } else {
            String text = '';
            final mobiData = snapshot.data;
            if (mobiData != null) {
              var part = mobiData.rawml.markup;
              while (part != null) {
                if (part.data != null) {
                  text += utf8.decode(part.data!, allowMalformed: true);
                }
                part = part.next;
              }
            }
            if (text.contains('<html') ||
                text.contains('<body') ||
                text.contains('<p')) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Html(
                  data: text,
                  style: {
                    "body": Style(
                      color: _darkMode ? Colors.white : Colors.black,
                      fontSize: FontSize(_fontSize.sp),
                      lineHeight: const LineHeight(1.5),
                    ),
                  },
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                text,
                style: TextStyle(
                  color: _darkMode ? Colors.white : Colors.black,
                  fontSize: _fontSize.sp,
                  height: 1.5,
                ),
              ),
            );
          }
        },
      );
    } else {
      content = Center(child: Text(_t('unsupported_format')));
    }

    return Theme(
      data: _darkMode ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: _darkMode ? Colors.black : Colors.white,
        appBar: AppBar(
          title: Text(widget.book.name, style: const TextStyle(fontSize: 16)),
          actions: [
            if (ext == 'pdf')
              IconButton(
                icon: const Icon(Icons.bookmark_add_outlined),
                onPressed: () {
                  if (_pdfPage != null) {
                    setState(() {
                      if (!_bookmarks.contains(_pdfPage)) {
                        _bookmarks.add(_pdfPage!);
                        _saveBookmarks();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${_t('page')} $_pdfPage ${_t('added_to_bookmarks')}',
                            ),
                          ),
                        );
                      }
                    });
                  }
                },
              ),
            IconButton(
              icon: Icon(_darkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: () {
                setState(() => _darkMode = !_darkMode);
                widget.settingsService.setDarkMode(_darkMode);
              },
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: Text(_t('increase_font_size')),
                  onTap: () {
                    setState(() => _fontSize += 2);
                    widget.settingsService.setFontSize(_fontSize);
                  },
                ),
                PopupMenuItem(
                  child: Text(_t('decrease_font_size')),
                  onTap: () {
                    setState(() => _fontSize = (_fontSize - 2).clamp(10, 40));
                    widget.settingsService.setFontSize(_fontSize);
                  },
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              const AdBanner(),
              Expanded(child: content),
            ],
          ),
        ),
        drawer: _bookmarks.isNotEmpty
            ? Drawer(
                child: Column(
                  children: [
                    DrawerHeader(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      child: Center(
                        child: Text(
                          _t('bookmarks'),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _bookmarks.length,
                        itemBuilder: (context, index) {
                          final b = _bookmarks[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.bookmark,
                              color: Colors.amber,
                            ),
                            title: Text('${_t('page')} $b'),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                setState(() {
                                  _bookmarks.remove(b);
                                });
                                _saveBookmarks();
                              },
                            ),
                            onTap: () {
                              if (ext == 'pdf') {
                                _pdfViewerController.jumpToPage(b);
                              }
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}

class CbzViewer extends StatefulWidget {
  final String filePath;

  const CbzViewer({super.key, required this.filePath});

  @override
  State<CbzViewer> createState() => _CbzViewerState();
}

class _CbzViewerState extends State<CbzViewer> {
  List<Uint8List> _images = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final archive = zip.ZipDecoder().decodeBytes(bytes);
      List<Uint8List> extractedImages = [];

      for (final file in archive) {
        if (file.isFile) {
          final name = file.name.toLowerCase();
          if (name.endsWith('.jpg') ||
              name.endsWith('.jpeg') ||
              name.endsWith('.png') ||
              name.endsWith('.webp')) {
            extractedImages.add(file.content as Uint8List);
          }
        }
      }

      // Dosya isimlerine göre sırala (genellikle 001.jpg, 002.jpg şeklindedir)
      // archive içindeki dosyalar her zaman sıralı olmayabilir
      // Ama burada file.content aldığımız için isimleri de saklamalıydık.
      // Düzeltme:
      List<MapEntry<String, Uint8List>> namedImages = [];
      for (final file in archive) {
        if (file.isFile) {
          final name = file.name.toLowerCase();
          if (name.endsWith('.jpg') ||
              name.endsWith('.jpeg') ||
              name.endsWith('.png') ||
              name.endsWith('.webp')) {
            namedImages.add(MapEntry(file.name, file.content as Uint8List));
          }
        }
      }
      namedImages.sort((a, b) => a.key.compareTo(b.key));

      if (mounted) {
        setState(() {
          _images = namedImages.map((e) => e.value).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => LocalizationService.translate(key);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('${t('error')}: $_error'));
    if (_images.isEmpty) return Center(child: Text(t('no_images_found')));

    return PageView.builder(
      itemCount: _images.length,
      itemBuilder: (context, index) {
        return InteractiveViewer(
          child: Image.memory(_images[index], fit: BoxFit.contain),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;
  final String language;

  const SplashScreen({
    super.key,
    required this.onFinished,
    required this.language,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/splash.mp4')
      ..setVolume(0);
    _controller
        .initialize()
        .then((_) {
          _controller.play();
          _controller.setLooping(false);
          if (mounted) {
            setState(() {
              _initialized = true;
            });
          }
          _timer = Timer(const Duration(seconds: 3), _finishSplash);
        })
        .catchError((_) {
          _timer = Timer(const Duration(seconds: 1), _finishSplash);
        });
  }

  void _finishSplash() {
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _initialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: TextButton(
              onPressed: _finishSplash,
              style: TextButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                LocalizationService.translate('skip', widget.language),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
