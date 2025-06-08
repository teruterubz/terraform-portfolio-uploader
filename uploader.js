// uploader.js

// --- APIエンドポイント定義 ---
// ★ YOUR_API_ENDPOINT_URL_HERE はあなたのAPI GatewayのベースURLに書き換えてください
const API_BASE_URL = 'https://8eddc58pjb.execute-api.ap-northeast-1.amazonaws.com'; 
const presignedUrlEndpoint = `${API_BASE_URL}/generate-presigned-url`;
const listFilesEndpoint = `${API_BASE_URL}/files`;

// --- HTMLの部品（DOM要素）の取得 ---
const fileInput = document.getElementById('fileInput');
const uploadButton = document.getElementById('uploadButton');
const statusMessages = document.getElementById('statusMessages');
const uploadedFileInfoDiv = document.getElementById('uploadedFileInfo');
const uploadedFileName = document.getElementById('uploadedFileName');
const uploadedS3Key = document.getElementById('uploadedS3Key');
const fileListUl = document.getElementById('fileList'); // ★新しく追加

// 選択されたファイルを保持するための変数
let selectedFile = null;

// --- 関数定義 ---

/**
 * DynamoDBからファイルリストを取得して画面に表示する関数
 */
const fetchAndRenderFiles = async () => {
  try {
    fileListUl.innerHTML = '<li>リストを読み込み中...</li>'; // 読み込み中の表示

    const response = await fetch(listFilesEndpoint); // GETリクエスト
    if (!response.ok) {
      throw new Error('ファイルリストの取得に失敗しました。');
    }
    const files = await response.json(); // 応答をJSONとして解析

    fileListUl.innerHTML = ''; // リストを一旦空にする

    if (files.length === 0) {
      fileListUl.innerHTML = '<li>アップロードされたファイルはありません。</li>';
      return;
    }

    // 取得したファイルごとにリスト項目(li)を作成して追加
    files.forEach(file => {
      const li = document.createElement('li');
      // ファイルサイズをKBやMBに変換する簡単な処理 (任意)
      const sizeInKB = (file.fileSize / 1024).toFixed(2);
      li.textContent = `ファイル名: ${file.originalFilename} (${sizeInKB} KB)`;
      fileListUl.appendChild(li);
    });

  } catch (error) {
    console.error('ファイルリスト取得エラー:', error);
    fileListUl.innerHTML = `<li>リストの読み込みに失敗しました: ${error.message}</li>`;
  }
};

// --- イベントリスナー設定 ---

// ファイルが選択された時の処理
fileInput.addEventListener('change', (event) => {
  selectedFile = event.target.files[0];
  if (selectedFile) {
    statusMessages.textContent = `ファイル選択中: ${selectedFile.name}`;
    uploadedFileInfoDiv.style.display = 'none';
  } else {
    statusMessages.textContent = 'ファイルが選択されていません。';
  }
});

// 「アップロード開始」ボタンが押された時の処理
uploadButton.addEventListener('click', async () => {
  if (!selectedFile) {
    statusMessages.textContent = 'エラー: まずファイルを選択してください。';
    return;
  }
  statusMessages.textContent = 'アップロード準備中...';
  uploadButton.disabled = true;

  try {
    // ステップA: 署名付きURLの取得
    const apiResponse = await fetch(presignedUrlEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        fileName: selectedFile.name,
        contentType: selectedFile.type
      })
    });
    if (!apiResponse.ok) {
      const errorData = await apiResponse.json();
      throw new Error(`APIエラー (${apiResponse.status}): ${errorData.error || '不明なエラー'}`);
    }
    const presignedData = await apiResponse.json();

    // ステップB: S3へファイルアップロード
    statusMessages.textContent = 'S3へファイルをアップロードしています...';
    const s3Response = await fetch(presignedData.uploadUrl, {
      method: 'PUT',
      headers: { 'Content-Type': selectedFile.type },
      body: selectedFile
    });
    if (!s3Response.ok) {
      throw new Error('S3へのアップロードに失敗しました。');
    }
    statusMessages.textContent = 'アップロード成功！';

    // 成功情報を画面に表示
    uploadedFileName.textContent = selectedFile.name;
    uploadedS3Key.textContent = presignedData.key;
    uploadedFileInfoDiv.style.display = 'block';

    // ★★★ アップロード成功後にファイルリストを更新 ★★★
    await fetchAndRenderFiles();

  } catch (error) {
    console.error('アップロード処理エラー:', error);
    statusMessages.textContent = `エラーが発生しました: ${error.message}`;
  } finally {
    uploadButton.disabled = false;
  }
});

// --- 初期化処理 ---

// ページが読み込まれた時に、ファイルリストを一度取得して表示
document.addEventListener('DOMContentLoaded', () => {
  fetchAndRenderFiles();
});