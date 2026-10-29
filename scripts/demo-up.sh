#!/bin/bash
# デモ環境を一括で起動・修復するスクリプト（何度実行しても安全です）
#   - 初回構築のとき、OCIを停止→起動した直後、デモ直前のどれでも使えます
#   - すでに動いている部分は飛ばし、止まっている部分だけを起動します
export PATH="$PATH:/usr/local/bin"
set -u
cd "$(dirname "$0")/.."
CLUSTER=demo
NODE="${CLUSTER}-control-plane"

step() { echo; echo "== $* =="; }
fail() { echo "NG: $*" >&2; exit 1; }

step "1/6 Dockerを起動"
if ! systemctl is-active --quiet docker; then
  sudo systemctl start docker || fail "Dockerを起動できませんでした"
fi
for i in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 2; done
docker info >/dev/null 2>&1 || fail "Dockerに接続できません（dockerグループが未反映の場合は、一度ログインし直してください）"
echo "Docker: OK"

step "2/6 Kubernetesクラスタ(kind)を起動"
docker inspect "$NODE" >/dev/null 2>&1 || fail "クラスタ ${CLUSTER} が見つかりません。ガイドの手順4-3でクラスタを作成してください"
if [ "$(docker inspect -f '{{.State.Running}}' "$NODE")" != "true" ]; then
  docker start "$NODE" >/dev/null || fail "kindのノード ${NODE} を起動できませんでした"
fi
kind export kubeconfig --name "$CLUSTER" || fail "kubeconfigを更新できませんでした"
for i in $(seq 1 60); do kubectl get --raw /readyz >/dev/null 2>&1 && break; sleep 3; done
kubectl get --raw /readyz >/dev/null 2>&1 || fail "Kubernetes APIが応答しません（3分待ちました）"
kubectl wait --for=condition=Ready node --all --timeout=180s || fail "ノードがReadyになりません"

step "3/6 アプリ(Pod)の起動を待つ"
kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s \
  || echo "（metrics-serverの起動待ちがタイムアウトしました。オートスケールの表示が遅れることがあります）"
kubectl rollout status deployment/demo-app --timeout=180s \
  || fail "demo-app が起動しません。kubectl get pods で状態を確認してください"

step "4/6 アプリの応答を確認"
r=""
for i in $(seq 1 60); do
  r=$(curl -s -m 3 http://localhost:30080/version) && [ -n "$r" ] && break
  r=""
  sleep 2
done
[ -n "$r" ] || fail "http://localhost:30080 が応答しません"
echo "アプリ: $r"

step "5/6 Jenkinsを起動"
docker compose up -d || fail "Jenkinsを起動できませんでした"
docker exec jenkins sh -c 'mkdir -p /var/jenkins_home/.kube && kind get kubeconfig --internal --name demo > /var/jenkins_home/.kube/config' \
  || fail "Jenkinsにkubeconfigを設定できませんでした"
docker exec jenkins docker version --format 'Jenkins内のdocker: {{.Client.Version}}' || fail "Jenkinsの中でdockerが使えません"
docker exec jenkins kubectl --kubeconfig /var/jenkins_home/.kube/config get nodes || fail "JenkinsからKubernetesに接続できません"
code="000"
for i in $(seq 1 90); do
  code=$(curl -s -o /dev/null -m 3 -w '%{http_code}' http://localhost:8080/login)
  [ "$code" != "000" ] && break
  sleep 2
done
[ "$code" != "000" ] || fail "Jenkinsの画面が応答しません（3分待ちました）"
echo "Jenkins: OK (HTTP $code)"

step "6/6 Jenkinsの初期パスワード（初回のみ表示されます）"
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null \
  || echo "（初期設定が済んでいるため、表示するパスワードはありません）"

step "完了：デモの準備ができました"
IP=$(curl -s -m 3 https://ifconfig.me 2>/dev/null || true)
echo "アプリ  : http://${IP:-<サーバーのIP>}:30080"
echo "Jenkins : http://${IP:-<サーバーのIP>}:8080"
echo "（IPが違う場合や表示されない場合は、OCIコンソールでパブリックIPを確認してください）"
echo
kubectl get pods
echo
kubectl get hpa
