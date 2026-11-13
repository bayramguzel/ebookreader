class Book {
  final String path;
  final String name;
  String? coverPath;
  final String? ext;
  bool isFavorite;
  bool isHidden;
  String? note;
  int lastPage;

  Book(
    this.path,
    this.name, {
    this.coverPath,
    this.ext,
    this.isFavorite = false,
    this.isHidden = false,
    this.note,
    this.lastPage = 0,
  });

  // Uzantıyı başındaki nokta olmadan döndürür
  String get normalizedExt {
    final e = ext ?? path.split('.').last.toLowerCase();
    return e.startsWith('.') ? e.substring(1) : e;
  }

  // JSON'a dönüştür
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'coverPath': coverPath,
      'ext': ext,
      'isFavorite': isFavorite,
      'isHidden': isHidden,
      'note': note,
      'lastPage': lastPage,
    };
  }

  // JSON'dan oluştur
  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      json['path'] as String,
      json['name'] as String,
      coverPath: json['coverPath'] as String?,
      ext: json['ext'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isHidden: json['isHidden'] as bool? ?? false,
      note: json['note'] as String?,
      lastPage: json['lastPage'] as int? ?? 0,
    );
  }
}
