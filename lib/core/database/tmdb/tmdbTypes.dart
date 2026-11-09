class TMDBItem {
  final int id;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final double rating;
  final String overview;
  final String releaseDate;
  final bool isMovie;
  final List<String> genres;

  TMDBItem({
    required this.id,
    required this.title,
    this.posterPath,
    this.backdropPath,
    required this.rating,
    required this.overview,
    required this.releaseDate,
    required this.isMovie,
    this.genres = const [],
  });

  String get posterUrl =>
      posterPath != null && posterPath!.isNotEmpty ? 'https://image.tmdb.org/t/p/w500$posterPath' : '';
  String get backdropUrl =>
      backdropPath != null && backdropPath!.isNotEmpty ? 'https://image.tmdb.org/t/p/original$backdropPath' : '';

  factory TMDBItem.fromJson(Map<String, dynamic> json, {bool? forceMovie}) {
    final mediaType = json['media_type'] as String?;
    final isMovie = forceMovie ?? (mediaType != null ? mediaType == 'movie' : json.containsKey('title'));
    final title = isMovie
        ? (json['title'] ?? json['original_title'] ?? '')
        : (json['name'] ?? json['original_name'] ?? '');
    final rating = (json['vote_average'] as num?)?.toDouble() ?? 0.0;
    final releaseDate = isMovie ? (json['release_date'] ?? '') : (json['first_air_date'] ?? '');

    return TMDBItem(
      id: json['id'] as int? ?? 0,
      title: title.toString(),
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      rating: ((rating * 10).round()) / 10,
      overview: (json['overview'] ?? '').toString(),
      releaseDate: releaseDate.toString(),
      isMovie: isMovie,
      genres: (json['genres'] as List<dynamic>?)?.map((g) => g['name'].toString()).toList() ?? [],
    );
  }
}

class TMDBEpisode {
  final int id;
  final int episodeNumber;
  final int seasonNumber;
  final String name;
  final String overview;
  final String? stillPath;
  final double rating;

  TMDBEpisode({
    required this.id,
    required this.episodeNumber,
    required this.seasonNumber,
    required this.name,
    required this.overview,
    this.stillPath,
    required this.rating,
  });

  String get stillUrl =>
      stillPath != null && stillPath!.isNotEmpty ? 'https://image.tmdb.org/t/p/w500$stillPath' : '';

  factory TMDBEpisode.fromJson(Map<String, dynamic> json) {
    final rating = (json['vote_average'] as num?)?.toDouble() ?? 0.0;
    return TMDBEpisode(
      id: json['id'] as int? ?? 0,
      episodeNumber: json['episode_number'] as int? ?? 1,
      seasonNumber: json['season_number'] as int? ?? 1,
      name: (json['name'] ?? 'Episode ${json['episode_number']}').toString(),
      overview: (json['overview'] ?? '').toString(),
      stillPath: json['still_path'] as String?,
      rating: ((rating * 10).round()) / 10,
    );
  }
}
