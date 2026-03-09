# Step 11: RBAC (Role / RoleBinding)

## 学習目標

- Role と ClusterRole の違いを理解する
- RoleBinding と ClusterRoleBinding を作成できる
- ServiceAccount に適切な権限を付与できる
- `kubectl auth can-i` で権限を確認できる

---

## 1. Namespace 作成

```bash
kubectl create namespace ckad-rbac
```

## 2. ServiceAccount 作成

```bash
kubectl create serviceaccount dev-user -n ckad-rbac
kubectl create serviceaccount readonly-user -n ckad-rbac
kubectl get serviceaccounts -n ckad-rbac
```

## 3. Role — Namespace スコープの権限

```yaml
# dev-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: ckad-rbac
rules:
- apiGroups: [""]            # コア API グループ
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
```

```bash
kubectl apply -f dev-role.yaml
kubectl get roles -n ckad-rbac
kubectl describe role developer -n ckad-rbac
```

## 4. RoleBinding — ServiceAccount に Role を紐付け

```yaml
# dev-rolebinding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-user-binding
  namespace: ckad-rbac
subjects:
- kind: ServiceAccount
  name: dev-user
  namespace: ckad-rbac
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
```

```bash
kubectl apply -f dev-rolebinding.yaml
kubectl get rolebindings -n ckad-rbac
kubectl describe rolebinding dev-user-binding -n ckad-rbac
```

## 5. kubectl auth can-i で権限テスト

```bash
# dev-user として Pod を作成できるか?
kubectl auth can-i create pods -n ckad-rbac --as=system:serviceaccount:ckad-rbac:dev-user
# → yes

# dev-user として Secrets を読めるか?
kubectl auth can-i get secrets -n ckad-rbac --as=system:serviceaccount:ckad-rbac:dev-user
# → no

# dev-user として Deployments を削除できるか?
kubectl auth can-i delete deployments -n ckad-rbac --as=system:serviceaccount:ckad-rbac:dev-user
# → no (update までしか許可していない)

# dev-user として Pod ログを取得できるか?
kubectl auth can-i get pods/log -n ckad-rbac --as=system:serviceaccount:ckad-rbac:dev-user
# → yes

# 全権限を一覧表示
kubectl auth can-i --list --as=system:serviceaccount:ckad-rbac:dev-user -n ckad-rbac
```

## 6. 読み取り専用 Role

```yaml
# readonly-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: readonly
  namespace: ckad-rbac
rules:
- apiGroups: ["", "apps", "batch"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]    # 読み取りのみ
```

```bash
kubectl apply -f readonly-role.yaml

# RoleBinding
kubectl create rolebinding readonly-binding \
  --role=readonly \
  --serviceaccount=ckad-rbac:readonly-user \
  -n ckad-rbac

# テスト
kubectl auth can-i get pods -n ckad-rbac --as=system:serviceaccount:ckad-rbac:readonly-user
# → yes
kubectl auth can-i create pods -n ckad-rbac --as=system:serviceaccount:ckad-rbac:readonly-user
# → no
kubectl auth can-i delete services -n ckad-rbac --as=system:serviceaccount:ckad-rbac:readonly-user
# → no
```

## 7. kubectl create role/rolebinding (試験で速い)

```bash
# Role を CLI で作成
kubectl create role pod-reader \
  --verb=get,list,watch \
  --resource=pods \
  -n ckad-rbac

# RoleBinding を CLI で作成
kubectl create rolebinding pod-reader-binding \
  --role=pod-reader \
  --serviceaccount=ckad-rbac:dev-user \
  -n ckad-rbac

# 確認
kubectl describe role pod-reader -n ckad-rbac
kubectl describe rolebinding pod-reader-binding -n ckad-rbac
```

## 8. ClusterRole と ClusterRoleBinding

```bash
# ClusterRole (クラスター全体で有効)
kubectl create clusterrole node-viewer \
  --verb=get,list,watch \
  --resource=nodes \
  --dry-run=client -o yaml

# ClusterRoleBinding
kubectl create clusterrolebinding node-viewer-binding \
  --clusterrole=node-viewer \
  --serviceaccount=ckad-rbac:dev-user \
  --dry-run=client -o yaml
```

## 9. --dry-run で YAML 生成

```bash
kubectl create role test-role --verb=get,list --resource=pods \
  -n ckad-rbac --dry-run=client -o yaml

kubectl create rolebinding test-rb --role=test-role \
  --serviceaccount=ckad-rbac:dev-user -n ckad-rbac \
  --dry-run=client -o yaml
```

---

## クリーンアップ

```bash
kubectl delete namespace ckad-rbac
# ClusterRole/ClusterRoleBinding は Namespace 外なので個別削除
# kubectl delete clusterrole node-viewer
# kubectl delete clusterrolebinding node-viewer-binding
```
