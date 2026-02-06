/// Model class representing a scanned medicine label
class ScannedLabel {
  final String text;
  final DateTime timestamp;
  final String? imagePath;
  final String? dominantColor; // Color of the label: 'green', 'red', 'white', or 'unknown'

  ScannedLabel({
    required this.text,
    required this.timestamp,
    this.imagePath,
    this.dominantColor,
  });

  /// Check if the label contains meaningful text
  bool get hasValidText => text.trim().length > 5;

  /// Get formatted timestamp
  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// Get color display name
  String get colorDisplayName {
    switch (dominantColor?.toLowerCase()) {
      case 'green':
        return 'Green Label';
      case 'light_green':
        return 'Light Green Label';
      case 'red':
        return 'Red Label';
      case 'light_red':
        return 'Pink/Light Red Label';
      case 'white':
        return 'White Label';
      default:
        return 'Unknown Color';
    }
  }

  /// Get color emoji
  String get colorEmoji {
    switch (dominantColor?.toLowerCase()) {
      case 'green':
      case 'light_green':
        return '🟢';
      case 'red':
      case 'light_red':
        return '🔴';
      case 'white':
        return '⚪';
      default:
        return '⚫';
    }
  }

  @override
  String toString() {
    return 'ScannedLabel(text: ${text.substring(0, text.length > 50 ? 50 : text.length)}..., '
        'timestamp: $formattedTime, color: ${dominantColor ?? 'unknown'})';
  }
}