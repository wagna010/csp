#!/bin/bash

# ============================================================
# Instalacao do CSP + Java 8 - Ubuntu 24 Server
# Instala OpenJDK 8 automaticamente (sem arquivos RAR)
# ============================================================

set -e

# Verifica se esta rodando como root
if [ "$EUID" -ne 0 ]; then
    echo "Execute este script como root: sudo bash $0"
    exit 1
fi

# Diretorio onde o script esta sendo executado
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=========================================="
echo " Instalacao CSP + Java 8 - Ubuntu 24"
echo "=========================================="

# ---- PASSO 1: Atualizar sistema e instalar dependencias ----
echo ""
echo "[1/6] Atualizando sistema e instalando dependencias..."
apt update -y
apt install -y unrar cron wget

# Garante que o cron esta ativo
systemctl enable cron
systemctl start cron

# ---- PASSO 2: Instalar OpenJDK 8 ----
echo ""
echo "[2/6] Instalando OpenJDK 8..."

# Verifica se o Java 8 ja esta instalado
if java -version 2>&1 | grep -q '1.8'; then
    echo "Java 8 ja esta instalado."
    java -version 2>&1
else
    # Metodo 1: Instalar via adoptium (Eclipse Temurin)
    echo "Adicionando repositorio Adoptium (Eclipse Temurin)..."
    apt install -y apt-transport-https gpg

    wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /usr/share/keyrings/adoptium.gpg

    echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(. /etc/os-release && echo $UBUNTU_CODENAME) main" > /etc/apt/sources.list.d/adoptium.list

    apt update -y

    if apt install -y temurin-8-jdk; then
        echo "Temurin JDK 8 instalado com sucesso."
    else
        # Metodo 2: Fallback - baixar manualmente o OpenJDK 8
        echo "Repositorio Adoptium falhou. Baixando OpenJDK 8 manualmente..."

        ARCH=$(dpkg --print-architecture)
        if [ "$ARCH" = "amd64" ]; then
            JDK_URL="https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u412-b08/OpenJDK8U-jdk_x64_linux_hotspot_8u412b08.tar.gz"
        elif [ "$ARCH" = "arm64" ]; then
            JDK_URL="https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u412-b08/OpenJDK8U-jdk_aarch64_linux_hotspot_8u412b08.tar.gz"
        else
            echo "ERRO: Arquitetura $ARCH nao suportada."
            exit 1
        fi

        echo "Baixando JDK 8 de $JDK_URL..."
        wget -q --show-progress -O /tmp/openjdk8.tar.gz "$JDK_URL"

        echo "Extraindo para /usr/lib/jvm/..."
        mkdir -p /usr/lib/jvm
        tar -xzf /tmp/openjdk8.tar.gz -C /usr/lib/jvm/
        rm -f /tmp/openjdk8.tar.gz

        # Encontra o diretorio extraido
        JDK_DIR=$(ls -d /usr/lib/jvm/jdk8u* 2>/dev/null | head -1)
        if [ -z "$JDK_DIR" ]; then
            echo "ERRO: Falha ao extrair o JDK."
            exit 1
        fi

        # Configura alternativas
        update-alternatives --install /usr/bin/java java "$JDK_DIR/bin/java" 100
        update-alternatives --install /usr/bin/javac javac "$JDK_DIR/bin/javac" 100
        update-alternatives --set java "$JDK_DIR/bin/java"
        update-alternatives --set javac "$JDK_DIR/bin/javac"

        echo "OpenJDK 8 instalado manualmente em $JDK_DIR"
    fi

    # Configura JAVA_HOME globalmente
    JAVA_BIN=$(readlink -f "$(which java)")
    JAVA_HOME_DIR=$(dirname "$(dirname "$JAVA_BIN")")

    cat > /etc/profile.d/java.sh << JAVAEOF
export JAVA_HOME=$JAVA_HOME_DIR
export PATH=\$JAVA_HOME/bin:\$PATH
JAVAEOF
    chmod +x /etc/profile.d/java.sh
    export JAVA_HOME="$JAVA_HOME_DIR"
    export PATH="$JAVA_HOME/bin:$PATH"

    echo ""
    echo "Java instalado:"
    java -version 2>&1
fi

# ---- PASSO 3: Criar estrutura de pastas do CSP ----
echo ""
echo "[3/6] Criando estrutura de pastas..."

mkdir -p /home/csps
mkdir -p /home/csps/xml

# ---- PASSO 4: Copiar scripts e descompactar CSP ----
echo ""
echo "[4/6] Instalando arquivos do CSP..."

# Copia a pasta script
if [ -d "/tmp/csp/script" ]; then
    echo "Copiando scripts de /tmp/csp/script..."
    # Usa cp ao inves de mv para nao perder o original
    cp -rf /tmp/csp/script /home/csps/
else
    echo "AVISO: Pasta /tmp/csp/script nao encontrada. Pulando..."
fi

# Descompacta o csp.rar
if [ -f "$SCRIPT_DIR/csp.rar" ]; then
    echo "Descompactando csp.rar..."
    unrar x -o+ "$SCRIPT_DIR/csp.rar" /home/csps/
elif [ -f "/tmp/csp/csp.rar" ]; then
    echo "Descompactando /tmp/csp/csp.rar..."
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

# Adiciona ao cron apenas se ainda nao existir
CRON_TEMP=$(mktemp)
crontab -l 2>/dev/null > "$CRON_TEMP" || true

if ! grep -q "monitor_service.sh" "$CRON_TEMP"; then
    echo "*/2 * * * * /home/csps/script/monitor_service.sh" >> "$CRON_TEMP"
    echo "Cron adicionado: monitor_service.sh (a cada 2 min)"
else
    echo "Cron monitor_service.sh ja existe. Pulando..."
fi

if ! grep -q "atualizar_xml.sh" "$CRON_TEMP"; then
    echo "*/2 * * * * /home/csps/script/atualizar_xml.sh" >> "$CRON_TEMP"
    echo "Cron adicionado: atualizar_xml.sh (a cada 2 min)"
else
    echo "Cron atualizar_xml.sh ja existe. Pulando..."
fi

crontab "$CRON_TEMP"
rm -f "$CRON_TEMP"

# Inicia o servico cardproxy
if [ -f "/home/csps/csp/cardproxy.sh" ]; then
    echo "Iniciando cardproxy..."
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
