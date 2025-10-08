class Song {
  final String filename;

  final String name;

  final String? artist;
  final String? license;

  const Song(this.filename, this.name, {this.artist, this.license});

  @override
  String toString() => 'Song<$filename>';
}

const Set<Song> songs = {
  Song('game-music-loop-1.mp3', 'Game Music Loop 1',
      artist: 'Pixabay / author unknown', license: 'Pixabay License'),
  Song('game-music-loop-7.mp3', 'Game Music Loop 7',
      artist: 'Pixabay / author unknown', license: 'Pixabay License'),
  Song('intermissiontoon.mp3', 'Intermission Toon',
      artist: 'Pixabay / author unknown', license: 'Pixabay License'),
  Song('video-game-loop-1.mp3', 'Video Game Loop 1',
      artist: 'Pixabay / author unknown', license: 'Pixabay License'),
  Song('bgm-blues-guitar-loop.mp3', 'Blues Guitar Loop',
      artist: 'Pixabay / author unknown', license: 'Pixabay License'),
  Song('electro-music-intro-new-sub.mp3', 'Electro Intro',
      artist: 'Pixabay / author unknown', license: 'Pixabay License'),
};
