import 'package:flutter/material.dart';
import 'package:glassmorphic_ui_kit/glassmorphic_ui_kit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_service.dart';
import '../services/localization_service.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/free_ebooks_dialog.dart';
import '../services/platform_utils.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  bool _darkMode = false;
  double _fontSize = 16.0;
  bool _gridView = true;
  String _language = 'tr';
  int _themeColor = Colors.green.value;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _settingsService.addListener(_loadSettings);
    _loadSettings();
  }

  @override
  void dispose() {
    _settingsService.removeListener(_loadSettings);
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final darkMode = await _settingsService.getDarkMode();
    final fontSize = await _settingsService.getFontSize();
    final gridView = await _settingsService.getGridView();
    final language = await _settingsService.getLanguage();
    final themeColor = await _settingsService.getThemeColor();

    if (mounted) {
      setState(() {
        _darkMode = darkMode;
        _fontSize = fontSize;
        _gridView = gridView;
        _language = language;
        _themeColor = themeColor;
        _isLoading = false;
      });
    }
  }

  String _t(String key) {
    return LocalizationService.translate(key, _language);
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_t('link_not_opened')}: $urlString')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('settings')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          GlassContainer(
            borderRadius: BorderRadius.zero,
            blur: 24,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            child: Container(),
          ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 80),
              const AdBannerWidget(),
              const SizedBox(height: 16),
              _buildSectionTitle(_t('language')),
              _buildSettingTile(
                _t('language'),
                _t('select_language'),
                Icons.language,
                DropdownButton<String>(
                  value: _language,
                  underline: const SizedBox(),
                  onChanged: (value) async {
                    if (value != null) {
                      setState(() => _language = value);
                      LocalizationService.currentLanguage = value;
                      await _settingsService.setLanguage(value);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'tr',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🇹🇷', style: TextStyle(fontSize: 18)),
                          SizedBox(width: 8),
                          Text('Türkçe'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'en',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🇬🇧', style: TextStyle(fontSize: 18)),
                          SizedBox(width: 8),
                          Text('English'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'de',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🇩🇪', style: TextStyle(fontSize: 18)),
                          SizedBox(width: 8),
                          Text('Deutsch'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(_t('appearance')),
              _buildSettingTile(
                _t('dark_mode'),
                _t('use_dark_theme'),
                Icons.dark_mode,
                Switch(
                  value: _darkMode,
                  onChanged: (value) async {
                    setState(() => _darkMode = value);
                    await _settingsService.setDarkMode(value);
                  },
                ),
              ),
              _buildSettingTile(
                _t('grid_view'),
                _t('show_books_in_grid'),
                Icons.grid_view,
                Switch(
                  value: _gridView,
                  onChanged: (value) async {
                    setState(() => _gridView = value);
                    await _settingsService.setGridView(value);
                  },
                ),
              ),
              _buildThemeColorTile(),
              const SizedBox(height: 20),
              _buildSectionTitle(_t('reading')),
              _buildFontSizeTile(),
              _buildSettingTile(
                _t('free_ebooks'),
                _t('free_ebooks_desc'),
                Icons.library_books,
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) =>
                          FreeEbooksDialog(language: _language),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(_t('data')),
              _buildSettingTile(
                _t('clear_all_data'),
                _t('delete_books_settings'),
                Icons.delete_forever,
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(_t('clear_all_data')),
                        content: Text(_t('confirm_clear')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(_t('cancel')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              _t('delete'),
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await _settingsService.clearAll();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_t('data_cleared'))),
                        );
                        Navigator.pop(context, true);
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(_t('social_donation')),
              _buildSettingTile(
                _t('donate'),
                _t('support_us'),
                Icons.coffee,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.coffee_outlined),
                      onPressed: () =>
                          _launchURL('https://buymeacoffee.com/41software'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.paypal),
                      onPressed: () =>
                          _launchURL('https://www.paypal.me/asbaypc'),
                    ),
                  ],
                ),
              ),
              _buildSettingTile(
                _t('social_media'),
                _t('follow_us'),
                Icons.share,
                PopupMenuButton<String>(
                  onSelected: _launchURL,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'https://youtube.com/@41softwarecom',
                      child: Text('Youtube'),
                    ),
                    const PopupMenuItem(
                      value: 'https://instagram.com/41software',
                      child: Text('Instagram'),
                    ),
                    const PopupMenuItem(
                      value: 'https://twitter.com/41software',
                      child: Text('Twitter'),
                    ),
                    const PopupMenuItem(
                      value: 'https://tiktok.com/@41software',
                      child: Text('Tiktok'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(_t('privacy')),
              _buildSettingTile(
                _t('privacy_policy'),
                _t('learn_about_data'),
                Icons.privacy_tip,
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => _launchURL(
                    'https://www.41software.com/privacy/privacy_ebookreader.php',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(_t('about')),
              _buildSettingTile(
                _t('user_manual'),
                _t('user_manual_desc'),
                Icons.help_outline,
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: _showUserManual,
                ),
              ),
              _buildSettingTile(
                _t('share_app'),
                _t('share_app_desc'),
                Icons.share_outlined,
                Builder(
                  builder: (btnCtx) => IconButton(
                    icon: const Icon(Icons.ios_share),
                    onPressed: () {
                      PlatformUtils.shareText(
                        'Check out this amazing eBook Reader app! ${PlatformUtils.storeUrl}',
                        context: btnCtx,
                      );
                    },
                  ),
                ),
              ),
              _buildSettingTile(
                _t('rate_app'),
                _t('rate_app_desc'),
                Icons.star_outline,
                IconButton(
                  icon: const Icon(Icons.rate_review_outlined),
                  onPressed: () => PlatformUtils.openStoreRating(),
                ),
              ),
              _buildInfoTile(_t('version'), '1.6.0'),
              _buildSupportedFormatsTile(),
            ],
          ),
        ],
      ),
    );
  }

  void _showUserManual() {
    String manualText = '';
    if (_language == 'tr') {
      manualText = '''
1. Kitap Ekleme: Ana ekrandaki "+" butonuna basarak veya "Tümünü Tara" diyerek cihazınızdaki kitapları bulabilirsiniz.
2. Okuma: Kitap kartına tıklayarak okumaya başlayabilirsiniz.
3. Favoriler: Kitap detayındaki kalp ikonuna basarak favorilerinize ekleyebilirsiniz.
4. Ayarlar: Görünüm, dil ve yazı boyutu gibi ayarları buradan değiştirebilirsiniz.
5. Notlar: Kitap okurken veya detay sayfasından notlar alabilirsiniz.
''';
    } else if (_language == 'de') {
      manualText = '''
1. Bücher hinzufügen: Sie können Bücher auf Ihrem Gerät finden, indem Sie auf dem Hauptbildschirm auf die Schaltfläche "+" klicken oder "Alles scannen" wählen.
2. Lesen: Klicken Sie auf eine Buchkarte, um mit dem Lesen zu beginnen.
3. Favoriten: Sie können Bücher zu Ihren Favoriten hinzufügen, indem Sie auf das Herz-Symbol in den Buchdetails klicken.
4. Einstellungen: Hier können Sie Einstellungen wie Erscheinungsbild, Sprache und Schriftgröße ändern.
5. Notizen: Sie können sich Notizen machen, während Sie ein Buch lesen veya auf der Detailseite.
''';
    } else {
      manualText = '''
1. Adding Books: You can find books on your device by clicking the "+" button on the main screen or by selecting "Scan All".
2. Reading: Click on a book card to start reading.
3. Favorites: You can add books to your favorites by clicking the heart icon in the book details.
4. Settings: You can change settings such as appearance, language, and font size here.
5. Notes: You can take notes while reading a book or from the details page.
''';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('user_manual')),
        content: SingleChildScrollView(child: Text(manualText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel')),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportedFormatsTile() {
    final formats = [
      'PDF',
      'EPUB',
      'FB2',
      'MOBI',
      'AZW3',
      'CBZ',
      'TXT',
      'HTML',
      'HTM',
      'PRC',
      'XML',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(12),
        blur: 10,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.file_present, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _t('supported_formats'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: formats
                    .map(
                      (format) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Color(_themeColor).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Color(_themeColor).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          format,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _darkMode ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeColorTile() {
    final colors = [
      Colors.deepPurple,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.pink,
      Colors.teal,
      Colors.brown,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(12),
        blur: 10,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.color_lens),
                  const SizedBox(width: 12),
                  Text(
                    _t('appearance'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: colors.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final color = colors[index];
                    final isSelected = _themeColor == color.toARGB32();
                    return GestureDetector(
                      onTap: () async {
                        setState(() => _themeColor = color.toARGB32());
                        await _settingsService.setThemeColor(color.toARGB32());
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSettingTile(
    String title,
    String subtitle,
    IconData icon,
    Widget trailing,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(12),
        blur: 10,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        child: ListTile(
          leading: Icon(icon),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: trailing,
        ),
      ),
    );
  }

  Widget _buildFontSizeTile() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(12),
        blur: 10,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.format_size),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _t('font_size'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text('${_fontSize.toInt()}'),
                ],
              ),
              Slider(
                value: _fontSize,
                min: 12,
                max: 24,
                divisions: 12,
                label: _fontSize.toInt().toString(),
                onChanged: (value) {
                  setState(() => _fontSize = value);
                },
                onChangeEnd: (value) async {
                  await _settingsService.setFontSize(value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(12),
        blur: 10,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        child: ListTile(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: Text(value),
        ),
      ),
    );
  }
}
