List<String> normalizeTags(String input) {
  final tags = <String>[];
  final seen = <String>{};

  for (final value in input.split(',')) {
    final tag = value.trim().toLowerCase();
    if (tag.isEmpty || tag.length > 30 || !seen.add(tag)) {
      continue;
    }

    tags.add(tag);
    if (tags.length == 5) {
      break;
    }
  }

  return tags;
}

String formatTags(List<String> tags) => tags.join(', ');
