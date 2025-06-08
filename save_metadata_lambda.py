import json
import boto3
import os
import uuid # ユニークなIDを生成するため
import urllib.parse # S3のオブジェクトキーをデコードするため
from datetime import datetime # タイムスタンプ用

# DynamoDBリソースを初期化
dynamodb = boto3.resource('dynamodb')
# Lambdaの環境変数からDynamoDBテーブル名を取得（Terraformで設定する想定）
DYNAMODB_TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'your-default-dynamodb-table-name')
table = dynamodb.Table(DYNAMODB_TABLE_NAME)

print('Lambda関数をロード中... (メタデータ保存用)')

def lambda_handler(event, context):
    print("受け取ったS3イベント:")
    print(json.dumps(event, indent=2, ensure_ascii=False))

    try:
        # S3イベントは複数のレコードを含むことがあるので、それぞれ処理する
        for record in event.get('Records', []):
            s3_event = record.get('s3', {})
            bucket_name = s3_event.get('bucket', {}).get('name')
            # S3オブジェクトキーはURLエンコードされていることがあるのでデコードする
            # 例: "My Test File.jpg" は "My+Test+File.jpg" や "My%20Test%20File.jpg" になっている
            object_key_encoded = s3_event.get('object', {}).get('key')
            if not object_key_encoded:
                print("警告: オブジェクトキーがイベントに含まれていません。")
                continue # 次のレコードへ

            object_key = urllib.parse.unquote_plus(object_key_encoded)

            file_size = s3_event.get('object', {}).get('size')
            event_time_str = record.get('eventTime') # 例: "2023-05-27T12:34:56.789Z"

            # DynamoDBに保存するアイテムを作成
            file_id = str(uuid.uuid4()) # 新しいユニークIDを生成
            original_filename = os.path.basename(object_key) # オブジェクトキーからファイル名部分を取得
            upload_timestamp = datetime.utcnow().isoformat() + "Z" # 現在時刻をISO8601形式で

            item_to_save = {
                'fileId': file_id,  # パーティションキー
                's3BucketName': bucket_name,
                's3ObjectKey': object_key,
                'originalFilename': original_filename,
                'fileSize': file_size,
                'uploadTimestamp': upload_timestamp,
                's3EventTime': event_time_str # S3イベント自体の発生時刻
            }

            print(f"DynamoDBに保存するアイテム: {json.dumps(item_to_save, ensure_ascii=False)}")

            # DynamoDBにアイテムを書き込む
            table.put_item(Item=item_to_save)

            print(f"メタデータをDynamoDBに保存しました: fileId={file_id}, s3Key={object_key}")

        return {
            'statusCode': 200,
            'body': json.dumps({'message': f"{len(event.get('Records', []))} 件のS3イベントを処理しました。"})
        }

    except Exception as e:
        print(f"エラー発生: {e}")
        # S3イベントトリガーの場合、エラーを返すとLambdaがリトライすることがある
        # 詳細なエラーハンドリングは要件に応じて行う
        raise e # エラーを再送出してLambda実行を失敗させる (リトライやデッドレターキュー設定に繋がる)