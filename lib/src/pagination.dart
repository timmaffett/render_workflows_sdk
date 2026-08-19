/// Render's list endpoints are cursor-paginated, and return arrays whose
/// entries wrap the resource alongside its cursor:
///
/// ```json
/// [ { "taskRun": { ... }, "cursor": "abc" } ]
/// ```
///
/// [Page] hides that shape, and [PaginatedFetch] turns it into a [Stream] so
/// callers don't hand-roll cursor loops.
library;

/// One page of results, plus the cursor needed to request the next.
class Page<T> {
  const Page({required this.items, this.nextCursor});

  final List<T> items;

  /// Cursor for the following page, or null when this is the last one.
  final String? nextCursor;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  bool get hasMore => nextCursor != null;

  /// Decodes a Render list response, unwrapping each entry's [key] field.
  static Page<T> fromJson<T>(
    List<Object?> json,
    String key,
    T Function(Map<String, Object?>) parse,
  ) {
    final items = <T>[];
    String? cursor;

    for (final entry in json) {
      if (entry is! Map<String, Object?>) continue;
      final resource = entry[key];
      if (resource is Map<String, Object?>) items.add(parse(resource));
      cursor = entry['cursor'] as String? ?? cursor;
    }

    // Render signals the end of a listing with a short page rather than a null
    // cursor, so the caller decides whether to continue; see [paginate].
    return Page(items: items, nextCursor: items.isEmpty ? null : cursor);
  }
}

/// Fetches a single page starting at [cursor].
typedef PaginatedFetch<T> = Future<Page<T>> Function(String? cursor, int limit);

/// Walks every page of a listing, yielding items as they arrive.
///
/// Stops when a page comes back empty or short, which is how Render indicates
/// the end of a listing. [limit] is the page size, not a total; pass [max] to
/// cap how many items are produced.
Stream<T> paginate<T>(
  PaginatedFetch<T> fetch, {
  int limit = 20,
  int? max,
}) async* {
  String? cursor;
  var produced = 0;

  while (true) {
    final page = await fetch(cursor, limit);
    if (page.isEmpty) return;

    for (final item in page.items) {
      yield item;
      produced++;
      if (max != null && produced >= max) return;
    }

    // A short page means there is nothing after it.
    if (page.items.length < limit || page.nextCursor == null) return;
    cursor = page.nextCursor;
  }
}
