# Fetcher（試作）

東京エリアのイベントを Walkerplus 一覧ページから取得し、アプリ用 JSON に正規化するプロトタイプです。

## 実行

```bash
cd fetcher
python3 fetch_walkerplus.py --fixture
```

ライブ取得（失敗時は fixture にフォールバック）:

```bash
python3 fetch_walkerplus.py \
  --out ../OutingPlanner/OutingPlanner/Data/Mock/tokyo_events_live.json
```

## アプリ側

- `tokyo_events_live.json` がバンドルにあればそれを優先
- なければ既存の `tokyo_events.json`（キュレーション済みモック）を使用

## 注意

サイト利用規約・robots・著作権を確認してください。HTML構造依存のため壊れる前提です。
