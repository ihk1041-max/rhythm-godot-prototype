# Sky Golf Rhythm Prototype (Godot 4.7.2)

「リズムゲームの数を増やす」のではなく、1本を完成作品として作り込むための Godot プロトタイプです。
既存のリズムゲーム作品の画像・楽曲・ボイスは使用していません。キャラクター、背景、BGM、SE はこのプロジェクト用のオリジナル素材です。

## 内容

- 720x1280 縦画面 / Android スマホ向け
- 約46秒、124 BPM の専用楽曲 WAV
- 白い通常球: 2音の予告の次でタップ
- 金の特殊球: 4音の上昇フレーズの次でタップ
- 小鳥のフェイク: 鳥の声では打たない
- 後半は霧と遠景で視覚情報を減らし、音を頼る構成
- 練習 -> 本番 -> 専用リザルト
- 成功、ぎりぎり、空振り、池ポチャを別アニメーションで表現
- PERFECT/MISS のノーツレーンは本番中に表示しない
- タイミング補正 -150ms ～ +150ms
- タップ / マウス / Space に対応
- Web (GitHub Pages) / Android export preset 同梱

## 推奨 Godot

Godot 4.7.2 stable / Standard (GDScript)

## ローカル起動

1. Godot 4.7.2 stable をインストール
2. `project.godot` を Godot で開く
3. F6/F5 または右上の Run Project

Godot CLI が使える環境なら:

```bash
godot --editor --path .
```

## 静的検証

```bash
python3 tools/validate_project.py
```

## GitHub Pages

`.github/workflows/deploy-web.yml` を同梱しています。
GitHub の `Settings -> Pages -> Source` を `GitHub Actions` にして `main` へ push すると、GitHub Actions が Godot 4.7.2 と matching export templates を取得し、Web版をビルドして Pages へデプロイします。

Web preset は `variant/thread_support=false` の単一スレッドです。GitHub Pages で COOP/COEP ヘッダーを追加しなくても動かしやすい構成を優先しています。

## Android APK

Godot 4.7.2 の Export Templates と Android SDK / OpenJDK 17 を設定後、Godot Editor の:

`Project -> Export -> Android`

から APK を生成できます。`export_presets.cfg` に Android preset を入れています。

CLI 例:

```bash
mkdir -p build/android
godot --headless --path . --export-debug "Android" build/android/sky-golf-debug.apk
```

## リズム同期

本番中の時刻は、Godot のリズムゲーム向け同期方法に合わせて概ね次の値を基準にしています。

```gdscript
music.get_playback_position() \
  + AudioServer.get_time_since_last_mix() \
  - AudioServer.get_output_latency()
```

`get_output_latency()` は毎フレーム呼ばず、開始時にキャッシュします。

## ディレクトリ

```text
assets/
  audio/          完成BGM / SE
  backgrounds/    専用背景
  characters/     ソラ & ピップ
scenes/
  main.tscn
scripts/
  main.gd
tools/
  generate_audio.py
  validate_project.py
.github/workflows/
  deploy-web.yml
```

## 次の制作段階

このプロトタイプで「1本の完成度」を実機評価した後、次はキャラクターを1枚絵の変形ではなく、idle / anticipation / swing / success / fail / recovery の SpriteSheet に置き換えるのが最優先です。その品質が固まってから2本目のミニゲームを追加します。
