#!/bin/bash

# Atualiza os pacotes do sistema
sudo apt update -y

# 1. Instala o Java (OpenJDK 8)
echo "Instalando Java..."
sudo apt install openjdk-8-jdk -y

# Verifica a instalação do Java
java -version

# 2. Instala o unrar
echo "Instalando o Unrar..."
sudo apt install unrar -y

# Descompacta o arquivo csp.rar, caso o arquivo exista
if [ -f "csp.rar" ]; then
    echo "Descompactando csp.rar..."
    unrar x csp.rar
else
    echo "O arquivo csp.rar não foi encontrado!"
fi

# Define permissões 755 para a pasta /home/csps e subpastas
echo "Definindo permissões 755 para /home/csps e suas subpastas..."
sudo chmod -R 755 /home/csps

# Adiciona ao cron para rodar a cada 5 minutos
(crontab -l 2>/dev/null; echo "*/5 * * * * /home/csps/csp/monitor_service.sh") | crontab -

# Executa o comando para iniciar o cardproxy.sh
echo "Iniciando o serviço cardproxy..."
/home/csps/csp ./cardproxy.sh start

# Finaliza o script
echo "CSP rodando na porta 8082."
