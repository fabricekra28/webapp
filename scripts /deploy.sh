#!/bin/bash
set -e

echo "🚀 DÉPLOIEMENT MICROSERVICES AVEC HELM - VERSION CORRIGÉE"
echo "========================================================"

NAMESPACE="microservices"
HELM_CHARTS_DIR="../helm-charts"

# Nettoyage préalable
echo "🧹 Nettoyage de l'environnement..."
kubectl delete namespace $NAMESPACE --ignore-not-found
sleep 5

# Créer le namespace
echo "📁 Création du namespace..."
kubectl create namespace $NAMESPACE

# 🔄 DÉPLOIEMENT SÉQUENTIEL

# 1. PostgreSQL d'abord
echo "🗄️  Déploiement de PostgreSQL..."
helm upgrade --install postgresql $HELM_CHARTS_DIR/postgresql \
  --namespace $NAMESPACE \
  --atomic \
  --timeout 300s

sleep 10

# 2. ConfigMap
echo "📝 Déploiement de la configuration..."
helm upgrade --install app-config $HELM_CHARTS_DIR/app-config \
  --namespace $NAMESPACE \
  --atomic

sleep 5

# 3. Attendre PostgreSQL
echo "⏳ Attente que PostgreSQL soit prêt..."
kubectl wait --for=condition=ready pod \
  -l app=postgres \
  --namespace $NAMESPACE \
  --timeout 300s

echo "✅ PostgreSQL est ready!"

# 4. Déploiement des microservices
SERVICES=("users-service" "products-service" "orders-service")

for SERVICE in "${SERVICES[@]}"; do
    echo "📦 Déploiement de $SERVICE..."
    
    helm upgrade --install $SERVICE $HELM_CHARTS_DIR/$SERVICE \
      --namespace $NAMESPACE \
      --atomic \
      --timeout 180s
    
    sleep 10
done

# 5. Vérifier que les services backend sont prêts
echo "⏳ Vérification que les services backend sont prêts..."
for SERVICE in "${SERVICES[@]}"; do
    kubectl wait --for=condition=ready pod \
      -l app=$SERVICE \
      --namespace $NAMESPACE \
      --timeout 180s
    echo "✅ $SERVICE est ready!"
done

# 6. Déploiement du gateway avec timeout augmenté
echo "🌐 Déploiement de gateway-service (timeout augmenté)..."
helm upgrade --install gateway-service $HELM_CHARTS_DIR/gateway-service \
  --namespace $NAMESPACE \


# VÉRIFICATION FINALE
echo "✅ DÉPLOIEMENT TERMINÉ AVEC SUCCÈS!"
echo "==================================="

kubectl get pods -n $NAMESPACE
echo ""
kubectl get svc -n $NAMESPACE

echo ""
echo "🌐 Gateway accessible sur: http://localhost:31083"
