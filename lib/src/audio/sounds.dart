enum SfxType {
  buttonTap,
  transition,
  winChime,
  notify,
  magic,
}

List<String> soundTypeToFilename(SfxType type) {
  switch (type) {
    case SfxType.buttonTap:
      return const ['screen-tap.mp3'];
    case SfxType.transition:
      return const ['whoosh-end.mp3', 'swoosh.mp3'];
    case SfxType.winChime:
      return const ['christmas-chimes-whoosh.mp3'];
    case SfxType.notify:
      return const ['bell-notification.mp3'];
    case SfxType.magic:
      return const ['christmas-chimes-whoosh.mp3'];
  }
}

double soundTypeToVolume(SfxType type) {
  switch (type) {
    case SfxType.buttonTap:
      return 4.0;
    case SfxType.transition:
      return 1.0;
    case SfxType.winChime:
    case SfxType.magic:
      return 0.6;
    case SfxType.notify:
      return 0.7;
  }
}
