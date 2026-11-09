class MediaStreamSource {
  final String serverName;
  final String streamUrl;
  final bool isHls;
  final Map<String, String>? headers;

  MediaStreamSource({
    required this.serverName,
    required this.streamUrl,
    this.isHls = true,
    this.headers,
  });
}

class MediaStreamResolver {
  static List<MediaStreamSource> getMovieStreams(int tmdbId) {
    return [
      MediaStreamSource(
        serverName: 'VidLink (Primary HD)',
        streamUrl: 'https://vidlink.pro/movie/$tmdbId',
        isHls: true,
      ),
      MediaStreamSource(
        serverName: 'VidSrc (Server 2)',
        streamUrl: 'https://vidsrc.to/embed/movie/$tmdbId',
        isHls: true,
      ),
      MediaStreamSource(
        serverName: 'AutoEmbed (Server 3)',
        streamUrl: 'https://player.autoembed.cc/embed/movie/$tmdbId',
        isHls: true,
      ),
      MediaStreamSource(
        serverName: 'SuperEmbed (Server 4)',
        streamUrl: 'https://multiembed.mov/?video_id=$tmdbId&tmdb=1',
        isHls: true,
      ),
    ];
  }

  static List<MediaStreamSource> getTVStreams(int tmdbId, int season, int episode) {
    return [
      MediaStreamSource(
        serverName: 'VidLink (Primary HD)',
        streamUrl: 'https://vidlink.pro/tv/$tmdbId/$season/$episode',
        isHls: true,
      ),
      MediaStreamSource(
        serverName: 'VidSrc (Server 2)',
        streamUrl: 'https://vidsrc.to/embed/tv/$tmdbId/$season/$episode',
        isHls: true,
      ),
      MediaStreamSource(
        serverName: 'AutoEmbed (Server 3)',
        streamUrl: 'https://player.autoembed.cc/embed/tv/$tmdbId/$season/$episode',
        isHls: true,
      ),
      MediaStreamSource(
        serverName: 'SuperEmbed (Server 4)',
        streamUrl: 'https://multiembed.mov/?video_id=$tmdbId&tmdb=1&s=$season&e=$episode',
        isHls: true,
      ),
    ];
  }
}
