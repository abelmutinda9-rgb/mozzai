import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:animestream/core/database/tmdb/tmdbTypes.dart';

class TMDBService {
  static const String apiKey = 'a0f3ec7ad97db59c00931e7a88a827da';
  static const String baseUrl = 'https://api.themoviedb.org/3';

  static Future<List<TMDBItem>> getTrendingMovies() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/trending/movie/week?api_key=$apiKey'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final list = (data['results'] as List).map((i) => TMDBItem.fromJson(i, forceMovie: true)).toList();
        return list;
      }
    } catch (_) {}
    return [];
  }

  static Future<List<TMDBItem>> getTrendingTV() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/trending/tv/week?api_key=$apiKey'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final list = (data['results'] as List).map((i) => TMDBItem.fromJson(i, forceMovie: false)).toList();
        return list;
      }
    } catch (_) {}
    return [];
  }

  static Future<List<TMDBItem>> getPopularMovies() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/movie/popular?api_key=$apiKey'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return (data['results'] as List).map((i) => TMDBItem.fromJson(i, forceMovie: true)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<TMDBItem>> getPopularTV() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/tv/popular?api_key=$apiKey'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return (data['results'] as List).map((i) => TMDBItem.fromJson(i, forceMovie: false)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<TMDBItem>> searchMulti(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final res = await http.get(
          Uri.parse('$baseUrl/search/multi?api_key=$apiKey&query=${Uri.encodeComponent(query)}'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final items = (data['results'] as List)
            .where((i) => i['media_type'] == 'movie' || i['media_type'] == 'tv')
            .map((i) => TMDBItem.fromJson(i))
            .toList();
        return items;
      }
    } catch (_) {}
    return [];
  }

  static Future<TMDBItem?> getDetails(int id, bool isMovie) async {
    try {
      final endpoint = isMovie ? 'movie/$id' : 'tv/$id';
      final res = await http.get(Uri.parse('$baseUrl/$endpoint?api_key=$apiKey'));
      if (res.statusCode == 200) {
        return TMDBItem.fromJson(json.decode(res.body), forceMovie: isMovie);
      }
    } catch (_) {}
    return null;
  }

  static Future<int> getTVSeasonCount(int tvId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/tv/$tvId?api_key=$apiKey'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return (data['number_of_seasons'] as int?) ?? 1;
      }
    } catch (_) {}
    return 1;
  }

  static Future<List<TMDBEpisode>> getTVSeasonEpisodes(int tvId, int seasonNumber) async {
    try {
      final res =
          await http.get(Uri.parse('$baseUrl/tv/$tvId/season/$seasonNumber?api_key=$apiKey'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final eps = (data['episodes'] as List? ?? []).map((e) => TMDBEpisode.fromJson(e)).toList();
        return eps;
      }
    } catch (_) {}
    return [];
  }
}
