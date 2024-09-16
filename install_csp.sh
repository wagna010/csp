#!/bin/bash

# Atualiza os pacotes do sistema
echo "Atualizando os pacotes do sistema..."
sudo apt update -y

# Instala o unrar se não estiver instalado
echo "Instalando o Unrar..."
sudo apt install unrar -y

# Parte 1: Instalação do Java a partir dos arquivos RAR

# Verifica se o arquivo jdk1.8.0_212.part01.rar existe
if [ -f "jdk1.8.0_212.part01.rar" ]; then
    echo "Descompactando os arquivos JDK..."
    unrar x jdk1.8.0_212.part01.rar /usr/
else
    echo "Os arquivos JDK não foram encontrados!"
    exit 1
fi

# Verifica se o JDK foi descompactado corretamente
if [ -d "/usr/jdk1.8.0_212" ]; then
    echo "JDK descompactado com sucesso!"
else
    echo "Erro ao descompactar o JDK. Verifique se os arquivos estão corretos."
    exit 1
fi

# Ajusta permissões para garantir que os binários tenham permissão de execução
echo "Ajustando permissões de execução para os binários do JDK..."
sudo chmod -R 755 /usr/jdk1.8.0_212

# Adiciona o Java e o Javac às alternativas do sistema
echo "Configurando as alternativas para Java e Javac..."
sudo update-alternatives --install /usr/bin/java java /usr/jdk1.8.0_212/bin/java 100
sudo update-alternatives --install /usr/bin/javac javac /usr/jdk1.8.0_212/bin/javac 100

# Verifica a instalação do Java
java -version

# Parte 2: Configurações do CSP

# Cria a pasta /home/csps se não existir
mkdir -p /home/csps

# Move o monitor_service.sh para /home/csps
if [ -f "monitor_service.sh" ]; then
    echo "Movendo monitor_service.sh para /home/csps..."
    mv monitor_service.sh /home/csps/
else
    echo "O arquivo monitor_service.sh não foi encontrado!"
fi

# Descompacta o arquivo csp.rar na pasta /home/csps
if [ -f "csp.rar" ]; then
    echo "Descompactando csp.rar na pasta /home/csps..."
    unrar x csp.rar /home/csps
else
    echo "O arquivo csp.rar não foi encontrado!"
fi

# Define permissões 755 para a pasta /home/csps e subpastas
echo "Definindo permissões 755 para /home/csps e suas subpastas..."
chmod -R 755 /home/csps

# Adiciona ao cron para rodar a cada 5 minutos
(crontab -l 2>/dev/null; echo "*/2 * * * * /home/csps/monitor_service.sh") | crontab -

# Inicia o serviço cardproxy
echo "Iniciando o serviço cardproxy..."
cd /home/csps/csp && ./cardproxy.sh start

# Finaliza o script
echo "Instalação do CSP e do Java concluída com sucesso."
