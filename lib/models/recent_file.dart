class RecentFile {
  final String path;
  final String name;
  final DateTime openedAt;

  const RecentFile({
    required this.path,
    required this.name,
    required this.openedAt,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'openedAt': openedAt.toIso8601String(),
      };

  factory RecentFile.fromJson(Map<String, dynamic> json) => RecentFile(
        path: json['path'] as String,
        name: json['name'] as String,
        openedAt: DateTime.parse(json['openedAt'] as String),
      );
}
