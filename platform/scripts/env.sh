#!/usr/bin/env bash
# env.sh - imposta l'ambiente della challenge nella shell corrente.
# Uso: source platform/scripts/env.sh   (va caricato con source, non eseguito)
export PROJECT_KUBECONFIG="${HOME}/.kube/kind-boutique"
export KUBECONFIG="${PROJECT_KUBECONFIG}"
unset VAULT_ADDR
command -v kubeon >/dev/null 2>&1 && kubeon

echo "KUBECONFIG=${KUBECONFIG}"
echo "Context attivo: $(kubectl config current-context 2>/dev/null || echo 'nessuno')"