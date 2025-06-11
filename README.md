# サーバーレス ファイルアップローダー

## 概要 (Overview)
AWSのサーバーレス技術とTerraform (IaC) を活用して構築した、Webベースのファイルアップローダーです。

このプロジェクトは、「S3を直接利用すれば、Amazon Photosのような既存サービスより低コストでファイルを管理できるのでは？」という技術的な探究心からスタートしました。調査を進める中で、単にファイルを保存するだけでなく、モダンなクラウドアプリケーションに求められるセキュリティとスケーラビリティをいかにして実現するかという課題に直面しました。

その解決策として、フロントエンドから安全にファイルをアップロードさせるためにS3署名付きURL発行のAPIを実装。さらに、アップロード後のメタデータ管理は、S3イベントをトリガーとする非同期処理をLambdaで構築し、フロントエンドの応答性を損なわない構成としました。これにより、API Gateway, Lambda, S3, DynamoDBを連携させた、一連のイベント駆動型アーキテクチャを実践的に構築しています。

この開発を通じて、Terraformによるインフラのコード化やサーバーレス設計のスキルを習得しただけでなく、フルマネージドサービスが提供する利便性と自作システムとのトレードオフを考察する、貴重な経験を得ることができました。
## アーキテクチャ図 (Architecture Diagram)

![サーバーレスファイルアップローダー構成図](images/file_uploader_architecture.png)
## シーケンス (Sequence)

## 処理フロー (Processing Flow)

このアプリケーションの主要な機能は、以下の流れで実現されています。

### ファイルアップロード処理フロー

- **① サイト表示:** ユーザーがブラウザでS3の静的ウェブサイトにアクセスします。
- **② URLリクエスト:** JavaScriptがAPI Gateway (`POST /generate-presigned-url`) に署名付きURLを要求します。
- **③ Lambda実行 (URL生成):** API Gatewayが「署名付きURL生成Lambda」をトリガーします。
- **④ URL応答:** Lambdaが生成した署名付きURLをブラウザに返します。
- **⑤ ファイル送信:** JavaScriptが署名付きURLを使い、ファイル本体をS3バケットに直接アップロード (PUT) します。
- **⑥ イベント通知:** S3へのファイル作成をトリガーに、「メタデータ保存Lambda」が起動します。
- **⑦ メタデータ保存:** Lambdaがファイル情報をDynamoDBに書き込みます。

### ファイル一覧表示処理フロー

- **⑧ 一覧リクエスト:** JavaScriptがAPI Gateway (`GET /files`) にファイル一覧を要求します。
- **⑨ Lambda実行 (一覧取得):** API Gatewayが「ファイル一覧取得Lambda」をトリガーします。
- **⑩ DBスキャン:** LambdaがDynamoDBのテーブルをスキャンして全ファイル情報を取得します。
- **⑪ 一覧応答:** Lambdaが取得したファイルリストをブラウザに返します。

## 使用技術一覧 (Tech Stack)

### IaC (Infrastructure as Code)
- Terraform

### AWS (Backend)
- **API Gateway:** HTTP API
- **Lambda:** Python 3.11 Runtime
- **S3:** ファイルストレージ, (静的ウェブサイトホスティング)
- **DynamoDB:** メタデータストレージ
- **IAM:** 各種権限管理 (ロール, ポリシー)
- **CloudWatch:** ログ監視

### Programming Language
- Python 3
  - Boto3 (AWS SDK)

### Frontend
- HTML
- CSS (Pico.css フレームワーク利用)
- JavaScript (Fetch API)

## 機能一覧 (Features)

- **ファイルアップロード機能:**
  - Webブラウザからファイルを選択し、アップロードできます。
  - バックエンドでS3署名付きURLを動的に生成し、安全かつ効率的にS3へ直接ファイルをアップロードする仕組みを実装しています。
- **メタデータ自動保存機能:**
  - S3へのファイルアップロードをトリガーとして、Lambda関数が自動実行されます。
  - ファイル名、S3の保存先パス、ファイルサイズ、更新日時などのメタデータがDynamoDBに自動的に記録されます。
- **ファイル一覧表示機能:**
  - アップロードされたファイルの一覧をAPI経由でDynamoDBから取得し、Webページ上に動的に表示します。

## 使い方・動かし方 (Usage / How to Deploy)

## 工夫した点・苦労した点 (Highlights / Challenges)
