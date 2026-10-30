const express = require('express');
const os = require('os');
const app = express();
const PORT = 3000;
const VERSION = 'v1';

// トップページ：バージョンと、応答したPod名を表示
app.get('/', (req, res) => {
  res.send(`
    <h1>Hello from Cloud Native Demo ${VERSION}!</h1>
    <p>このレスポンスを返したPod名: ${os.hostname()}</p>
  `);
});

// デモ用の1行表示（スクリプトから見やすくするため）
app.get('/version', (req, res) => {
  res.type('text/plain').send(`${VERSION} @ ${os.hostname()}`);
});

// 負荷デモ用：わざとCPUを使う
app.get('/heavy', (req, res) => {
  let sum = 0;
  for (let i = 0; i < 1e8; i++) sum += i;
  res.send(`計算完了 (Pod: ${os.hostname()})`);
});

// Kubernetesが「このアプリは元気か」を確認するためのURL
app.get('/healthz', (req, res) => {
  res.send('OK');
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
