import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/localization_service.dart';
import '../services/platform_utils.dart';

class FreeEbooksDialog extends StatelessWidget {
  final String language;

  const FreeEbooksDialog({super.key, required this.language});

  String _t(String key) {
    return LocalizationService.translate(key, language);
  }

  static const List<Map<String, String>> _ebookSources = [
    {
      'name': 'Project Gutenberg',
      'url': 'https://www.gutenberg.org',
      'desc_en':
          'Over 75,000 free eBooks, specializing in older works with expired copyright.',
      'desc_tr':
          'Telif hakkı dolmuş 75.000\'den fazla ücretsiz e-kitap. Klasik eserler için en iyi kaynak.',
      'desc_de':
          'Über 75.000 kostenlose E-Books, spezialisiert auf ältere Werke mit abgelaufenem Urheberrecht.',
    },
    {
      'name': 'ManyBooks',
      'url': 'https://manybooks.net',
      'desc_en':
          'More than 50,000 free eBooks in various genres, many available in PDF.',
      'desc_tr':
          'Çeşitli türlerde 50.000\'den fazla ücretsiz e-kitap. Birçoğu PDF formatında mevcuttur.',
      'desc_de':
          'Mehr als 50.000 kostenlose E-Books in verschiedenen Genres, viele davon als PDF verfügbar.',
    },
    {
      'name': 'Open Library',
      'url': 'https://openlibrary.org',
      'desc_en':
          'A project of Internet Archive with millions of books. Filter by "Only show ebooks".',
      'desc_tr':
          'Milyonlarca kitabın bulunduğu Internet Archive projesi. "Sadece e-kitapları göster" filtresini kullanın.',
      'desc_de':
          'Ein Projekt von Internet Archive mit Millionen von Büchern. Filtern Sie nach „Nur E-Books anzeigen“.',
    },
    {
      'name': 'Standard Ebooks',
      'url': 'https://standardebooks.org',
      'desc_en':
          'High-quality, free editions of public domain literature, optimized for modern e-readers.',
      'desc_tr':
          'Modern okuyucular için optimize edilmiş, kamu malı literatürün yüksek kaliteli ve ücretsiz sürümleri.',
      'desc_de':
          'Hochwertige, kostenlose Ausgaben gemeinfreier Literatur, optimiert für moderne E-Reader.',
    },
    {
      'name': 'PDF Drive',
      'url': 'https://www.pdfdrive.com',
      'desc_en':
          'A search engine specifically for PDF files with millions of titles.',
      'desc_tr':
          'Milyonlarca başlığa sahip, özellikle PDF dosyaları için bir arama motoru.',
      'desc_de':
          'Eine Suchmaschine speziell für PDF-Dateien mit Millionen von Titeln.',
    },
    {
      'name': 'Obooko',
      'url': 'https://www.obooko.com',
      'desc_en':
          'Large selection of free novels and non-fiction books provided legally by authors.',
      'desc_tr':
          'Yazarlar tarafından yasal olarak sağlanan geniş ücretsiz roman ve kurgu dışı kitap seçeneği.',
      'desc_de':
          'Große Auswahl an kostenlosen Romanen und Sachbüchern, die legal von Autoren bereitgestellt werden.',
    },
    {
      'name': 'Openlibra',
      'url': 'https://openlibra.com',
      'desc_en':
          'Focuses on free technical and scientific books in PDF format.',
      'desc_tr':
          'PDF formatındaki ücretsiz teknik ve bilimsel kitaplara odaklanır.',
      'desc_de':
          'Konzentriert sich auf kostenlose technische und wissenschaftliche Bücher im PDF-Format.',
    },
    {
      'name': 'Feedbooks',
      'url': 'https://www.feedbooks.com/publicdomain',
      'desc_en': 'A wide collection of public domain books neatly formatted.',
      'desc_tr': 'Düzenli formatlanmış geniş bir kamu malı kitap koleksiyonu.',
      'desc_de':
          'Eine große Sammlung gemeinfreier Bücher in ordentlichem Format.',
    },
  ];

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // Could show a snackbar here if launch fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.book, color: Colors.blue),
          const SizedBox(width: 10),
          Text(_t('free_ebooks')),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _ebookSources.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final source = _ebookSources[index];
            final desc = source['desc_$language'] ?? source['desc_en']!;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source['name']!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Builder(
                        builder: (btnCtx) => IconButton(
                          icon: const Icon(Icons.share, size: 20),
                          onPressed: () {
                            PlatformUtils.shareText(
                              '${source['name']}: ${source['url']}\n$desc',
                              context: btnCtx,
                            );
                          },
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(_t('visit_site')),
                        onPressed: () => _launchUrl(source['url']!),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_t('cancel')),
        ),
      ],
    );
  }
}
