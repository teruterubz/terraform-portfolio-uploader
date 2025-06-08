import json
import boto3
import os
from decimal import Decimal # DynamoDBの数値型を扱うために必要

# DynamoDBリソースを初期化
dynamodb = boto3.resource('dynamodb')
# Lambdaの環境変数からDynamoDBテーブル名を取得
DYNAMODB_TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'your-default-dynamodb-table-name')
table = dynamodb.Table(DYNAMODB_TABLE_NAME)

print('Lambda関数をロード中... (ファイル一覧取得用)')

# JSONに変換する際にDecimal型を通常の数値に変換するためのヘルパークラス
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            # 整数か小数かを判断して変換
            if obj % 1 == 0:
                return int(obj)
            else:
                return float(obj)
        # 親クラスのデフォルトの振る舞いに任せる
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    print("受け取ったイベント:")
    print(json.dumps(event, indent=2, ensure_ascii=False))

    try:
        # --- DynamoDBから全アイテムを取得 ---
        # scanはテーブル全体をスキャンするため、大規模なテーブルには非効率ですが、
        # 今回のような小規模なポートフォリオでは最も簡単な方法です。
        response = table.scan()

        # 取得したアイテムのリスト
        items = response.get('Items', [])
        
        # もしデータが多い場合、scanは複数回実行する必要があるが、今回は省略
        # while 'LastEvaluatedKey' in response:
        #     response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
        #     items.extend(response.get('Items', []))

        print(f"{len(items)} 件のアイテムを取得しました。")

        # フロントエンドに返すレスポンス
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*', # CORS設定
                'Content-Type': 'application/json'
            },
            # ★ DecimalEncoderを使ってJSON文字列に変換
            'body': json.dumps(items, cls=DecimalEncoder, ensure_ascii=False)
        }

    except Exception as e:
        print(f"エラー発生: {e}")
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*', # CORS設定
                'Content-Type': 'application/json'
            },
            'body': json.dumps({'error': str(e)})
        }