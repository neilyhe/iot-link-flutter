extension StringExt on String? {
  bool get isNotNullOrEmpty => this != null && this!.isNotEmpty;
}
