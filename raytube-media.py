#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["pychromecast==14.0.10", "websockets==17.1"]
# ///
"""raytube-media.py -- talk to the TV browser and to a Chromecast's own apps.
Run through uv so its libraries stay out of the system, at the versions pinned
above and locked (with everything they pull in) in raytube-media.py.lock:

  uv run --quiet --locked --script raytube-media.py <command>

TV browser (a Firefox instance started with --remote-debugging-port, spoken to
over WebDriver BiDi):
  tv-video                     JSON {url, video_id, time, paused} of the first
                               YouTube tab, or {} if none
  tv-pause                     pause every playing video in the TV browser
  tv-open <url>                navigate the TV browser's first tab to <url>
  tv-fullscreen                put the YouTube player itself full screen (as if
                               its full-screen button were clicked); no-op if it
                               already is

Chromecast:
  cc-status <host>             JSON {app, video_id, time, state, title}
  cc-youtube <host> <id> <t>   play a YouTube video in the TV's own app from t s
  cc-quit <host>               quit whatever app is running
"""
import asyncio
import json
import re
import sys

BIDI_URL = "ws://127.0.0.1:9337/session"
YOUTUBE_ID = re.compile(r"(?:v=|youtu\.be/|/shorts/)([A-Za-z0-9_-]{11})")


# ---------- WebDriver BiDi (TV browser) ----------

class Bidi:
    def __init__(self, ws):
        self.ws, self.next_id = ws, 0

    async def call(self, method, params):
        self.next_id += 1
        mid = self.next_id
        await self.ws.send(json.dumps({"id": mid, "method": method, "params": params}))
        while True:
            msg = json.loads(await self.ws.recv())
            if msg.get("id") == mid:
                if msg.get("type") == "error":
                    raise RuntimeError(f"{method}: {msg.get('message')}")
                return msg["result"]

    async def evaluate(self, context, expression):
        r = await self.call("script.evaluate", {
            "expression": expression, "target": {"context": context}, "awaitPromise": True})
        return r.get("result", {}).get("value")


async def with_browser(fn):
    import websockets
    async with websockets.connect(BIDI_URL, max_size=None) as ws:
        b = Bidi(ws)
        await b.call("session.new", {"capabilities": {}})
        try:
            tree = await b.call("browsingContext.getTree", {})
            return await fn(b, tree["contexts"])
        finally:
            await b.call("session.end", {})


VIDEO_JS = ("(() => { const v = document.querySelector('video'); "
            "return v ? JSON.stringify({time: v.currentTime, paused: v.paused}) : null })()")


async def tv_video(b, contexts):
    for c in contexts:
        m = YOUTUBE_ID.search(c.get("url", ""))
        if m:
            raw = await b.evaluate(c["context"], VIDEO_JS)
            v = json.loads(raw) if raw else {}
            return {"url": c["url"], "video_id": m.group(1), "time": int(v.get("time", 0)),
                    "paused": v.get("paused", True), "context": c["context"]}
    return {}


async def tv_pause(b, contexts):
    for c in contexts:
        await b.evaluate(c["context"], "document.querySelectorAll('video').forEach(v => v.pause())")
    return {"paused": len(contexts)}


# Click YouTube's own full-screen button so its player UI switches properly.
# userActivation lets the page call requestFullscreen without a real click.
FULLSCREEN_JS = ("(() => { if (document.fullscreenElement) return 'already'; "
                 "const b = document.querySelector('.ytp-fullscreen-button'); "
                 "if (b) { b.click(); return 'clicked'; } "
                 "const p = document.querySelector('#movie_player') || document.querySelector('video'); "
                 "if (!p) return 'no-player'; p.requestFullscreen(); return 'requested'; })()")


async def tv_fullscreen(b, contexts):
    for c in contexts:
        if YOUTUBE_ID.search(c.get("url", "")):
            r = await b.call("script.evaluate", {
                "expression": FULLSCREEN_JS, "target": {"context": c["context"]},
                "awaitPromise": False, "userActivation": True})
            return {"fullscreen": r.get("result", {}).get("value")}
    return {"fullscreen": "no-youtube-tab"}


def tv_open(url):
    async def go(b, contexts):
        await b.call("browsingContext.navigate", {"context": contexts[0]["context"], "url": url, "wait": "none"})
        return {"opened": url}
    return go


# ---------- Chromecast ----------

def cast(host):
    import pychromecast
    cc = pychromecast.get_chromecast_from_host((host, 8009, None, host, host))
    cc.wait(timeout=10)
    return cc


def cc_status(host):
    import time
    cc = cast(host)
    mc = cc.media_controller
    time.sleep(1.5)
    m = mc.status
    out = {"app": cc.status.display_name, "video_id": m.content_id if cc.status.display_name == "YouTube" else None,
           "time": int(m.adjusted_current_time or 0), "state": m.player_state, "title": m.title}
    cc.disconnect()
    return out


def cc_youtube(host, video_id, start):
    import time
    from pychromecast.controllers.youtube import YouTubeController
    cc = cast(host)
    yt = YouTubeController()
    cc.register_handler(yt)
    yt.play_video(video_id)
    # Seek once the app reports the video playing.
    mc = cc.media_controller
    for _ in range(40):
        time.sleep(0.5)
        if mc.status.player_state in ("PLAYING", "BUFFERING") and mc.status.content_id == video_id:
            break
    if start > 5:
        mc.seek(start)
    cc.disconnect()
    return {"playing": video_id, "from": start}


def cc_quit(host):
    cc = cast(host)
    cc.quit_app()
    cc.disconnect()
    return {"quit": True}


def main(argv):
    cmd, args = (argv[1] if len(argv) > 1 else ""), argv[2:]
    if cmd == "tv-video":
        out = asyncio.run(with_browser(tv_video))
    elif cmd == "tv-pause":
        out = asyncio.run(with_browser(tv_pause))
    elif cmd == "tv-fullscreen":
        out = asyncio.run(with_browser(tv_fullscreen))
    elif cmd == "tv-open" and args:
        out = asyncio.run(with_browser(tv_open(args[0])))
    elif cmd == "cc-status" and args:
        out = cc_status(args[0])
    elif cmd == "cc-youtube" and len(args) == 3:
        out = cc_youtube(args[0], args[1], int(args[2]))
    elif cmd == "cc-quit" and args:
        out = cc_quit(args[0])
    else:
        print(__doc__.strip())
        sys.exit(2)
    print(json.dumps(out))


if __name__ == "__main__":
    main(sys.argv)
