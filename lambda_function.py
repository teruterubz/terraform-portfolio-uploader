import json
import boto3
import os
import uuid # ユニークなファイル名を生成するため（任意）

# S3クライアントを初期化
s3_client = boto3.client('s3')

# Lambdaの環境変数からバケット名を取得（Terraformで設定する想定）
S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME', 'your-default-bucket-name') # デフォルト値は適当

print('Lambda関数をロード中... (署名付きURL生成)')

def lambda_handler(event, context):
    print("受け取ったイベント:")
    print(json.dumps(event, indent=2, ensure_ascii=False))

    try:
        # API Gatewayからのリクエストボディは通常event['body']に文字列として入っている
        # それをJSONとしてパースする
        body = json.loads(event.get('body', '{}'))

        file_name = body.get('fileName')
        content_type = body.get('contentType')

        if not file_name:
            raise ValueError("fileNameがリクエストに含まれていません。")

        # S3に保存する際のオブジェクトキーを生成 (例: uploads/ランダムなID-元のファイル名)
        # object_key = f"uploads/{str(uuid.uuid4())}-{file_name}"
        # もしくは、シンプルに元のファイル名をキーにする場合（同名ファイルは上書きされる）
        object_key = file_name # ここではシンプルにファイル名をキーにします

        # 署名付きURLを生成 (PUTリクエスト用 = アップロード用)
        presigned_url = s3_client.generate_presigned_url(
            ClientMethod='put_object',
            Params={
                'Bucket': S3_BUCKET_NAME,
                'Key': object_key,
                'ContentType': content_type # ContentTypeも指定すると、S3側で検証できる
            },
            ExpiresIn=300  # URLの有効期限（秒単位、ここでは5分）
        )

        print(f"生成された署名付きURL: {presigned_url}")
        print(f"S3オブジェクトキー: {object_key}")

        # フロントエンドに返すレスポンス
        response_body = {
            'uploadUrl': presigned_url,
            'key': object_key # フロントエンドがS3にアップロード後、このキーをメタデータ保存に使う
        }
        return {
            'statusCode': 200,
            'headers': {
                # ↓↓↓ CORS設定はAPI Gateway側で行うのが一般的ですが、Lambdaから返すことも一応可能 ↓↓↓
                'Access-Control-Allow-Origin': '*', # どのオリジンからのアクセスを許可するか (本番ではちゃんと指定)
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, GET, OPTIONS' #許可するメソッド
            },
            'body': json.dumps(response_body)
        }

    except Exception as e:
        print(f"エラー発生: {e}")
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, GET, OPTIONS'
            },
            'body': json.dumps({'error': str(e)})
        }