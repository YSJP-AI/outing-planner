"""
Walkerplus（東京エリア）向けイベント取得プロトタイプ。

使い方:
  python3 fetch_walkerplus.py              # ライブ取得を試行、失敗時は fixture
  python3 fetch_walkerplus.py --fixture    # fixture のみ
  python3 fetch_walkerplus.py --out ../OutingPlanner/OutingPlanner/Data/Mock/tokyo_events_live.json

注意:
  - サイトの利用規約・robots.txt を確認したうえで利用してください。
  - HTML構造変更で壊れる前提の試作です。本番は許可取得 or API を推奨。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from typing import Optional

SOURCE_URL = "https://www.walkerplus.com/event_list/today/ar0313/"
USER_AGENT = (
    "OutingPlannerFetcher/0.1 (+local-dev; educational prototype)"
)
DEFAULT_OUT = Path(__file__).resolve().parent / "output" / "tokyo_events_live.json"
FIXTURE_PATH = Path(__file__).resolve().parent / "fixtures" / "walkerplus_tokyo_sample.html"


@dataclass
class RawEvent:
    title: str
    href: str
    area: str = "東京"
    venue: Optional[str] = None
    price_text: Optional[str] = None
    summary: Optional[str] = None


class WalkerplusListParser(HTMLParser):
    """Heuristic parser for event list pages (title + link focused)."""

    def __init__(self) -> None:
        super().__init__()
        self.events: list[RawEvent] = []
        self._in_link = False
        self._href: Optional[str] = None
        self._chunks: list[str] = []
        self._seen: set[str] = set()

    def handle_starttag(self, tag: str, attrs: list[tuple[str, Optional[str]]]) -> None:
        if tag != "a":
            return
        attr_map = dict(attrs)
        href = attr_map.get("href") or ""
        if "/event/" not in href:
            return
        self._in_link = True
        self._href = href
        self._chunks = []

    def handle_endtag(self, tag: str) -> None:
        if tag != "a" or not self._in_link:
            return
        title = re.sub(r"\s+", " ", "".join(self._chunks)).strip()
        href = self._href or ""
        self._in_link = False
        self._href = None
        self._chunks = []

        if len(title) < 4:
            return
        if any(skip in title for skip in ("詳細", "もっと見る", "一覧", "TOP")):
            return

        absolute = href if href.startswith("http") else f"https://www.walkerplus.com{href}"
        key = absolute.split("?")[0]
        if key in self._seen:
            return
        self._seen.add(key)

        area = guess_area(title)
        self.events.append(
            RawEvent(
                title=title,
                href=absolute,
                area=area,
                summary=f"Walkerplus（東京）から取得: {title}",
            )
        )

    def handle_data(self, data: str) -> None:
        if self._in_link:
            self._chunks.append(data)


def guess_area(title: str) -> str:
    # Longer / more specific names first. Never default to bare "東京"
    # (that incorrectly pins distant spots to Tokyo Station).
    for area in (
        "井の頭",
        "吉祥寺",
        "雑司が谷",
        "サンシャイン",
        "池袋",
        "渋谷",
        "新宿",
        "上野",
        "浅草",
        "六本木",
        "銀座",
        "お台場",
        "豊洲",
        "丸の内",
        "原宿",
        "表参道",
        "秋葉原",
        "品川",
        "築地",
        "神楽坂",
        "代々木",
        "押上",
        "麻布台",
    ):
        if area in title:
            if area in ("井の頭", "サンシャイン"):
                return "吉祥寺" if area == "井の頭" else "池袋"
            return area
    return "不明"


AREA_COORDS = {
    "上野": (35.7141, 139.7774),
    "浅草": (35.7110, 139.7967),
    "渋谷": (35.6580, 139.7016),
    "六本木": (35.6627, 139.7310),
    "築地": (35.6654, 139.7707),
    "お台場": (35.6294, 139.7794),
    "吉祥寺": (35.7031, 139.5797),
    "丸の内": (35.6812, 139.7671),
    "豊洲": (35.6545, 139.7968),
    "池袋": (35.7295, 139.7109),
    "新宿": (35.6909, 139.7003),
    "原宿": (35.6702, 139.7027),
    "銀座": (35.6717, 139.7649),
    "神楽坂": (35.7022, 139.7400),
    "代々木": (35.6710, 139.6950),
    "押上": (35.7101, 139.8107),
    "麻布台": (35.6608, 139.7400),
    "秋葉原": (35.6984, 139.7731),
    "品川": (35.6284, 139.7387),
    "表参道": (35.6652, 139.7125),
    "雑司が谷": (35.7200, 139.7145),
}


def guess_genres(title: str) -> list[str]:
    mapping = [
        (("展", "美術館", "アート", "ギャラリー"), "アート"),
        (("グルメ", "食堂", "カフェ", "食べ", "丼"), "グルメ"),
        (("公園", "庭園", "花火", "自然"), "自然"),
        (("ライブ", "映画", "ショー", "演劇"), "エンタメ"),
        (("体験", "ワークショップ", "教室"), "体験"),
        (("セール", "マルシェ", "市場"), "ショッピング"),
        (("祭", "まつり", "フェス"), "祭り"),
    ]
    genres: list[str] = []
    for keys, genre in mapping:
        if any(k in title for k in keys):
            genres.append(genre)
    return genres or ["エンタメ"]


def guess_duration(genres: list[str]) -> int:
    if "祭り" in genres:
        return 180
    if "自然" in genres:
        return 150
    if "アート" in genres:
        return 120
    if "グルメ" in genres:
        return 90
    return 120


def normalize(raw: RawEvent, index: int) -> dict:
    genres = guess_genres(raw.title)
    digest = hashlib.sha1(raw.href.encode("utf-8")).hexdigest()[:10]
    lat = lng = None
    if raw.area in AREA_COORDS:
        lat, lng = AREA_COORDS[raw.area]
    return {
        "id": f"wp-{digest}",
        "title": raw.title,
        "genres": genres,
        "area": raw.area,
        "venue": raw.venue,
        "startAt": None,
        "endAt": None,
        "durationMinutes": guess_duration(genres),
        "priceMin": None,
        "priceMax": None,
        "priceText": raw.price_text or "料金は情報元を確認",
        "source": "walkerplus",
        "sourceURL": raw.href,
        "summary": raw.summary,
        "lat": lat,
        "lng": lng,
    }


def fetch_html(url: str, timeout: int = 20) -> str:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "text/html,application/xhtml+xml",
            "Accept-Language": "ja,en;q=0.8",
        },
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        charset = response.headers.get_content_charset() or "utf-8"
        return response.read().decode(charset, errors="replace")


def parse_events(html: str) -> list[RawEvent]:
    parser = WalkerplusListParser()
    parser.feed(html)
    return parser.events


def load_html(use_fixture: bool) -> tuple[str, str]:
    if use_fixture:
        return FIXTURE_PATH.read_text(encoding="utf-8"), "fixture"

    try:
        html = fetch_html(SOURCE_URL)
        return html, "live"
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        print(f"[warn] live fetch failed ({exc}); falling back to fixture", file=sys.stderr)
        return FIXTURE_PATH.read_text(encoding="utf-8"), "fixture-fallback"


def main() -> int:
    parser = argparse.ArgumentParser(description="Fetch Tokyo events from Walkerplus (prototype)")
    parser.add_argument("--fixture", action="store_true", help="Use local HTML fixture only")
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_OUT,
        help="Output JSON path",
    )
    parser.add_argument("--limit", type=int, default=20, help="Max events to keep")
    args = parser.parse_args()

    if not FIXTURE_PATH.exists():
        print(f"[error] missing fixture: {FIXTURE_PATH}", file=sys.stderr)
        return 1

    html, mode = load_html(use_fixture=args.fixture)
    raw_events = parse_events(html)[: args.limit]
    normalized = [normalize(item, i) for i, item in enumerate(raw_events)]

    args.out.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "meta": {
            "source": "walkerplus",
            "sourceURL": SOURCE_URL,
            "fetchedAt": datetime.now(timezone.utc).isoformat(),
            "mode": mode,
            "count": len(normalized),
        },
        "events": normalized,
    }

    # App decoder expects a bare array; also write companion meta file.
    args.out.write_text(
        json.dumps(normalized, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    meta_path = args.out.with_suffix(".meta.json")
    meta_path.write_text(json.dumps(payload["meta"], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"[ok] mode={mode} events={len(normalized)} -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
