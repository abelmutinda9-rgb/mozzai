import 'package:animestream/core/anime/providers/types.dart';

class MediaStreamSource {
  final String serverName;
  final String streamUrl;
  final String embedUrl;
  final bool isDirect;
  final Map<String, String>? headers;

  MediaStreamSource({
    required this.serverName,
    required this.streamUrl,
    required this.embedUrl,
    this.isDirect = false,
    this.headers,
  });
}

class MediaStreamResolver {
  static List<MediaStreamSource> getMovieStreams(int tmdbId) {
    return [
      MediaStreamSource(
        serverName: 'VidLink HD (Primary)',
        streamUrl: 'https://vidlink.pro/movie/$tmdbId',
        embedUrl: 'https://vidlink.pro/movie/$tmdbId',
        headers: {'Referer': 'https://vidlink.pro/'},
      ),
      MediaStreamSource(
        serverName: 'VidSrc Pro (Server 2)',
        streamUrl: 'https://vidsrc.to/embed/movie/$tmdbId',
        embedUrl: 'https://vidsrc.to/embed/movie/$tmdbId',
        headers: {'Referer': 'https://vidsrc.to/'},
      ),
      MediaStreamSource(
        serverName: 'VidSrc Me (Server 3)',
        streamUrl: 'https://vidsrc.me/embed/movie?tmdb=$tmdbId',
        embedUrl: 'https://vidsrc.me/embed/movie?tmdb=$tmdbId',
        headers: {'Referer': 'https://vidsrc.me/'},
      ),
      MediaStreamSource(
        serverName: 'AutoEmbed (Server 4)',
        streamUrl: 'https://autoembed.co/movie/tmdb/$tmdbId',
        embedUrl: 'https://autoembed.co/movie/tmdb/$tmdbId',
        headers: {'Referer': 'https://autoembed.co/'},
      ),
      MediaStreamSource(
        serverName: '2Embed (Server 5)',
        streamUrl: 'https://2embed.cc/embed/$tmdbId',
        embedUrl: 'https://2embed.cc/embed/$tmdbId',
        headers: {'Referer': 'https://2embed.cc/'},
      ),
    ];
  }

  static List<MediaStreamSource> getTVStreams(int tmdbId, int season, int episode) {
    return [
      MediaStreamSource(
        serverName: 'VidLink HD (Primary)',
        streamUrl: 'https://vidlink.pro/tv/$tmdbId/$season/$episode',
        embedUrl: 'https://vidlink.pro/tv/$tmdbId/$season/$episode',
        headers: {'Referer': 'https://vidlink.pro/'},
      ),
      MediaStreamSource(
        serverName: 'VidSrc Pro (Server 2)',
        streamUrl: 'https://vidsrc.to/embed/tv/$tmdbId/$season/$episode',
        embedUrl: 'https://vidsrc.to/embed/tv/$tmdbId/$season/$episode',
        headers: {'Referer': 'https://vidsrc.to/'},
      ),
      MediaStreamSource(
        serverName: 'VidSrc Me (Server 3)',
        streamUrl: 'https://vidsrc.me/embed/tv?tmdb=$tmdbId&season=$season&episode=$episode',
        embedUrl: 'https://vidsrc.me/embed/tv?tmdb=$tmdbId&season=$season&episode=$episode',
        headers: {'Referer': 'https://vidsrc.me/'},
      ),
      MediaStreamSource(
        serverName: 'AutoEmbed (Server 4)',
        streamUrl: 'https://autoembed.co/tv/tmdb/$tmdbId-$season-$episode',
        embedUrl: 'https://autoembed.co/tv/tmdb/$tmdbId-$season-$episode',
        headers: {'Referer': 'https://autoembed.co/'},
      ),
      MediaStreamSource(
        serverName: '2Embed (Server 5)',
        streamUrl: 'https://2embed.cc/embedtv/$tmdbId&s=$season&e=$episode',
        embedUrl: 'https://2embed.cc/embedtv/$tmdbId&s=$season&e=$episode',
        headers: {'Referer': 'https://2embed.cc/'},
      ),
    ];
  }

  static List<VideoStream> convertToVideoStreams(List<MediaStreamSource> sources) {
    return sources
        .map((s) => VideoStream(
              quality: '1080p Auto',
              url: s.streamUrl,
              server: s.serverName,
              backup: false,
              customHeaders: s.headers,
            ))
        .toList();
  }
}
