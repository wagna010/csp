#!/bin/bash

# ============================================================
# Instalacao do CSP + Java 8 - Ubuntu 24.04 LTS Server
# Java 8 instalado automaticamente via Adoptium (sem RAR)
# ============================================================

set -e

# Verifica se esta rodando como root
if [ "$EUID" -ne 0 ]; then
    echo "Execute este script como root: sudo bash $0"
    exit 1
fi

echo "=========================================="
echo " Instalacao CSP + Java 8 - Ubuntu 24"
echo "=========================================="

# ---- PASSO 1: Atualizar sistema e instalar dependencias ----
echo ""
echo "[1/6] Atualizando sistema e instalando dependencias..."
apt update -y
apt install -y unrar cron wget apt-transport-https gpg

systemctl enable cron
systemctl start cron

# ---- PASSO 2: Instalar Java 8 (Adoptium Temurin) ----
echo ""
echo "[2/6] Instalando Java 8..."

if java -version 2>&1 | grep -q '1.8'; then
    echo "Java 8 ja esta instalado."
    java -version 2>&1
else
    echo "Adicionando repositorio Adoptium (Eclipse Temurin)..."
    wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /usr/share/keyrings/adoptium.gpg
    echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(. /etc/os-release && echo $UBUNTU_CODENAME) main" > /etc/apt/sources.list.d/adoptium.list
    apt update -y

    if apt install -y temurin-8-jdk; then
        echo "Temurin JDK 8 instalado com sucesso."
    else
        echo "Repositorio falhou. Baixando manualmente..."
        ARCH=$(dpkg --print-architecture)
        if [ "$ARCH" = "amd64" ]; then
            JDK_URL="https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u412-b08/OpenJDK8U-jdk_x64_linux_hotspot_8u412b08.tar.gz"
        elif [ "$ARCH" = "arm64" ]; then
            JDK_URL="https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u412-b08/OpenJDK8U-jdk_aarch64_linux_hotspot_8u412b08.tar.gz"
        else
            echo "ERRO: Arquitetura $ARCH nao suportada."
            exit 1
        fi
        wget -q --show-progress -O /tmp/openjdk8.tar.gz "$JDK_URL"
        mkdir -p /usr/lib/jvm
        tar -xzf /tmp/openjdk8.tar.gz -C /usr/lib/jvm/
        rm -f /tmp/openjdk8.tar.gz
        JDK_DIR=$(ls -d /usr/lib/jvm/jdk8u* 2>/dev/null | head -1)
        if [ -z "$JDK_DIR" ]; then
            echo "ERRO: Falha ao extrair o JDK."
            exit 1
        fi
        update-alternatives --install /usr/bin/java java "$JDK_DIR/bin/java" 100
        update-alternatives --install /usr/bin/javac javac "$JDK_DIR/bin/javac" 100
        update-alternatives --set java "$JDK_DIR/bin/java"
        update-alternatives --set javac "$JDK_DIR/bin/javac"
    fi

    JAVA_BIN=$(readlink -f "$(which java)")
    JAVA_HOME_DIR=$(dirname "$(dirname "$JAVA_BIN")")
    cat > /etc/profile.d/java.sh << JAVAEOF
export JAVA_HOME=$JAVA_HOME_DIR
export PATH=\$JAVA_HOME/bin:\$PATH
JAVAEOF
    chmod +x /etc/profile.d/java.sh
    export JAVA_HOME="$JAVA_HOME_DIR"
    export PATH="$JAVA_HOME/bin:$PATH"

    echo "Java instalado:"
    java -version 2>&1
fi

# ---- PASSO 3: Criar estrutura de pastas ----
echo ""
echo "[3/6] Criando estrutura de pastas..."
mkdir -p /home/csps/xml

# ---- PASSO 4: Instalar arquivos do CSP ----
echo ""
echo "[4/6] Instalando arquivos do CSP..."

# Copia a pasta script do repo clonado
if [ -d "/tmp/csp/script" ]; then
    cp -rf /tmp/csp/script /home/csps/
else
    echo "AVISO: Pasta /tmp/csp/script nao encontrada."
fi

# Descompacta o csp.rar
if [ -f "/tmp/csp/csp.rar" ]; then
    echo "Descompactando csp.rar..."
    unrar x -o+ /tmp/csp/csp.rar /home/csps/
else
    echo "AVISO: Arquivo csp.rar nao encontrado."
fi

# ---- PASSO 5: Ajustar permissoes ----
echo ""
echo "[5/6] Ajustando permissoes..."
chmod -R 755 /home/csps

# ---- PASSO 6: Configurar cron e iniciar servico ----
echo ""
echo "[6/6] Configurando cron e iniciando servico..."

CRON_TEMP=$(mktemp)
crontab -l 2>/dev/null > "$CRON_TEMP" || true

grep -q "monitor_service.sh" "$CRON_TEMP" || echo "*/2 * * * * /home/csps/script/monitor_service.sh" >> "$CRON_TEMP"
grep -q "atualizar_xml.sh" "$CRON_TEMP" || echo "*/2 * * * * /home/csps/script/atualizar_xml.sh" >> "$CRON_TEMP"

crontab "$CRON_TEMP"
rm -f "$CRON_TEMP"

# Inicia o cardproxy
if [ -f "/home/csps/csp/cardproxy.sh" ]; then
    cd /home/csps/csp && ./cardproxy.sh start
    echo ""
    echo "=========================================="
    echo " Instalacao concluida com sucesso!"
    echo " Servico CSP rodando na porta 8082"
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo " Instalacao concluida!"
    echo " AVISO: cardproxy.sh nao encontrado."
    echo " Inicie manualmente depois."
    echo "=========================================="
fi

echo ""
echo "Crons configurados:"
crontab -l 2>/dev/null
echo ""
echo "Para verificar o Java: java -version"
echo "Para verificar o CSP:  cd /home/csps/csp && ./cardproxy.sh status"
