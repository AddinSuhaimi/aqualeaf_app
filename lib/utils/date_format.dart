import 'package:intl/intl.dart';

String formatTimestamp(String? rawTimestamp) {
  if (rawTimestamp == null || rawTimestamp.isEmpty) {
    return 'Never synced';
  }

  try {
    final dateTime = DateTime.parse(rawTimestamp).toLocal();

    return DateFormat('dd MMM yyyy, h:mm a').format(dateTime);
  } catch (_) {
    return rawTimestamp; // fallback if parsing fails
  }
}