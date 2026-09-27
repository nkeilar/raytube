# Raytube wishlist

Ideas parked for after the current build (TV desktop, scenes, rotation,
family board, native YouTube toggle).

## Pull in what's playing on the TV (added 26 Sep)

While the kids watch YouTube in the Chromecast's own app, see what's playing
and pull it into the TV desktop as a picture-in-picture or split, so the
laptop can add something alongside it.

- The Chromecast reports its current media over Cast (`RECEIVER_STATUS` /
  `MEDIA_STATUS`): for YouTube, the video id and playback position.
- "Pull in" opens that video on the TV desktop at the same timestamp (browser
  window, muted or with audio), then applies the PiP or split preset, and the
  cast takes over the TV. The reverse direction is the native-YouTube toggle.
- Show the current clip in the Display menu ("On Chromecast HD: <title>").

**Status (27 Sep):** the full-screen version exists as `raytube-tv pull` (asks the
Chromecast what its YouTube app plays, quits it, restarts the TV-desktop cast and opens the
video at the same spot in the Watch scene), built but **untested on the device** (T-2). The
picture-in-picture version described above is tracked as T-25
(`.agent/Tasks/T-25-pull-into-pip.md`).
