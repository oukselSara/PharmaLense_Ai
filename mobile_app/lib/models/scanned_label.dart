/// Model class representing a scanned medicine label
class ScannedLabel {
  final String text;
  final DateTime timestamp;
  final String? imagePath;

  ScannedLabel({
    required this.text,
    required this.timestamp,
    this.imagePath,
  });

  /// Check if the label contains meaningful text
  bool get hasValidText => text.trim().length > 5;

  /// Get formatted timestamp
  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'ScannedLabel(text: ${text.substring(0, text.length > 50 ? 50 : text.length)}..., '
        'timestamp: $formattedTime)';
  }
}
