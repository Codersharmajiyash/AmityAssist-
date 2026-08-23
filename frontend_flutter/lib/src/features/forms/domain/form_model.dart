class FormItem {
  const FormItem({
    required this.id,
    required this.formKey,
    required this.name,
    required this.category,
    required this.department,
    required this.description,
    required this.fileName,
    required this.downloadUrl,
    required this.fileType,
  });

  final int id;
  final String formKey;
  final String name;
  final String category;
  final String department;
  final String description;
  final String fileName;
  final String downloadUrl;
  final String fileType;

  factory FormItem.fromJson(Map<String, dynamic> json) {
    return FormItem(
      id: json['id'] as int? ?? 0,
      formKey: json['form_key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      department: json['department'] as String? ?? '',
      description: json['description'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
      fileType: json['file_type'] as String? ?? 'pdf',
    );
  }

  String get fullDownloadUrl {
    if (downloadUrl.startsWith('http')) {
      return downloadUrl;
    }
    // Localhost backend base URL
    return 'http://127.0.0.1:8000$downloadUrl';
  }
}
