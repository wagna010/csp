#!/bin/bash

# Definir a lista de diretórios que contêm os serviços
SERVICE_DIRS=(
    "/usr/local/csp1"
    "/usr/local/csp2"
    "/usr/local/csp3"
)

# Nome do script do serviço
SERVICE_SCRIPT="./cardproxy.sh"

# Iterar sobre cada diretório da lista
for SERVICE_DIR in "${SERVICE_DIRS[@]}"; do
    echo "Checking service in directory: $SERVICE_DIR"

    # Entrar no diretório do serviço
    cd $SERVICE_DIR

    # Verificar o status do serviço
    status_output=$($SERVICE_SCRIPT status)

    # Se o status for "Proxy is stopped", iniciar o serviço
    if [[ "$status_output" == *"Proxy is stopped"* ]]; then
        echo "Proxy is stopped in $SERVICE_DIR. Starting the service..."
        $SERVICE_SCRIPT start
    else
        echo "Service is running in $SERVICE_DIR: $status_output"
    fi

    echo "--------------------------------------"
done
