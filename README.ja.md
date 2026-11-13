[English](README.md) | **日本語** | [한국어](README.ko.md) | [Bahasa Indonesia](README.id.md) | [Français](README.fr.md) | [繁體中文](README.zh-TW.md)

# Font Bridge for OBS

OBS で反映できなかったフォントを、自然の力で正しく読み込めるようにするスクリプトです。

<img src="docs/images/ja/font_dock.png" alt="Font Bridge ドック" width="272">


## インストール
1. `Font_Bridge_for_OBS` フォルダを丸ごと `%APPDATA%\obs-studio\plugin_config\` に置きます (このパスをエクスプローラーのアドレス欄に貼り付けると開けます)。
2. OBS → **ツール → スクリプト → +** で `obs_font_bridge.lua` を選びます。
3. **ソース → + → テキスト (Bridge)** を追加します。

## デバッグモード
スクリプトの設定で **デバッグモード** にチェックを入れてみてください。ちょっとしたおまけが入っています。

## アンインストール
**ツール → スクリプト** でスクリプトを外し (選択して **−**)、OBS を閉じてから `Safe_Uninstaller.bat` を実行します。各ファイルの内容を表示し、削除するものを選べます。設定のバックアップ、別の PC への引っ越し手順の表示にも対応し、削除したものはごみ箱へ移動します。

Windows の OBS 28 以降 (obs-websocket v5 内蔵) が必要です。

製作者: ChromeBread feat. BlackDream ・ ライセンス: GPL-2.0

これは非公式のサードパーティ製スクリプトです。OBS Project とは関係がなく、承認も受けていません。

## アップデートについて

本ソフトにはアップデートの確認機能や自動更新機能はなく、今後も通信を伴う自動アップデート機能を実装する予定はありません。アップデートの際は、開発者のリンクを辿ってご自身で配布サイトからダウンロードしてください: [Releases](../../releases)
