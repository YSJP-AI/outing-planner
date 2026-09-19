# Remote event catalog (free)

OutingPlanner は GitHub 上のこの JSON を無料で取得してイベント一覧を更新します。

## URL

`https://raw.githubusercontent.com/YSJP-AI/outing-planner/main/remote/events.json`

## 更新手順

1. `remote/events.json` の `events` 配列を編集する
2. `updatedAt` を更新する
3. `main` に push する
4. アプリの「更新」をタップする

料金はかかりません（公開 HTTPS + 端末への保存のみ）。

## 公開設定（重要）

アプリは認証なしで JSON を取るため、次のいずれかが必要です（いずれも無料）:

1. **このリポジトリを Public にする**（いちばん簡単）
2. `remote/events.json` の内容を **公開 Gist** や別の公開リポジトリに置き、アプリの「上級: カタログURL」にその raw URL を入れる

Private のままだと `raw.githubusercontent.com` は 404 になります。
