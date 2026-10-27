#!/usr/bin/env bash
# env.sh - imposta l'ambiente della challenge nella shell corrente.
# Uso: source platform/scripts/env.sh   (va caricato con source, non eseguito)
# PROJECT_KUBECONFIG viene esportata così anche le sotto-shell (che rileggono
# ~/.bashrc) restano isolate dalla configurazione di lavoro.
export PROJECT_KUBECONFIG="${HOME}/.kube/kind-boutique"
export KUBECONFIG="${PROJECT_KUBECONFIG}"
unset VAULT_ADDR
command -v kubeon >/dev/null 2>&1 && kubeon

echo "KUBECONFIG=${KUBECONFIG}"
echo "Context attivo: $(kubectl config current-context 2>/dev/null || echo 'nessuno (cluster non ancora creato?)')"
EOF
chmod +x "$HOME/personal/microservices-demo/platform/scripts/env.sh"
