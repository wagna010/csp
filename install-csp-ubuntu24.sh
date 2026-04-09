#!/bin/bash

# ============================================================
# Instalacao do CSP + Oracle Java 8 - Ubuntu 24.04 LTS Server
# CSP exige Oracle/Sun JVM (OpenJDK nao e suportado)
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
apt install -y unrar cron

systemctl enable cron
systemctl start cron

# ---- PASSO 2: Instalar Oracle JDK 8 (dos arquivos RAR do repositorio) ----
echo ""
echo "[2/6] Instalando Oracle JDK 1.8.0_212..."

if java -version 2>&1 | grep -q 'HotSpot'; then
    echo "Oracle Java 8 ja esta instalado."
    java -version 2>&1
else
    # Remove OpenJDK se estiver instalado (CSP nao aceita)
    if java -version 2>&1 | grep -q 'OpenJDK'; then
        echo "Removendo OpenJDK (incompativel com CSP)..."
        apt remove -y openjdk-* 2>/dev/null || true
        apt autoremove -y 2>/dev/null || true
    fi

    if [ -f "/tmp/csp/jdk1.8.0_212.part01.rar" ]; then
        # Remove instalacao anterior se existir
        rm -rf /usr/jdk1.8.0_212

        echo "Descompactando Oracle JDK dos arquivos RAR..."
        unrar x -o+ /tmp/csp/jdk1.8.0_212.part01.rar /usr/

        if [ ! -d "/usr/jdk1.8.0_212" ]; then
            echo "ERRO: Falha ao descompactar o JDK."
            exit 1
        fi

        chmod -R 755 /usr/jdk1.8.0_212

        update-alternatives --install /usr/bin/java java /usr/jdk1.8.0_212/bin/java 100
        update-alternatives --install /usr/bin/javac javac /usr/jdk1.8.0_212/bin/javac 100
        update-alternatives --set java /usr/jdk1.8.0_212/bin/java
        update-alternatives --set javac /usr/jdk1.8.0_212/bin/javac

        cat > /etc/profile.d/java.sh << 'JAVAEOF'
export JAVA_HOME=/usr/jdk1.8.0_212
export PATH=$JAVA_HOME/bin:$PATH
JAVAEOF
        chmod +x /etc/profile.d/java.sh
        export JAVA_HOME=/usr/jdk1.8.0_212
        export PATH=$JAVA_HOME/bin:$PATH

        echo "Oracle JDK instalado:"
        java -version 2>&1
    else
        echo "ERRO: Arquivo jdk1.8.0_212.part01.rar nao encontrado em /tmp/csp/"
        echo "Certifique-se de ter clonado o repositorio completo."
        exit 1
    fi
fi

# ---- PASSO 3: Criar estrutura de pastas ----
echo ""
echo "[3/6] Criando estrutura de pastas..."
mkdir -p /home/csps/xml

# ---- PASSO 4: Instalar arquivos do CSP ----
echo ""
echo "[4/6] Instalando arquivos do CSP..."

if [ -d "/tmp/csp/script" ]; then
    cp -rf /tmp/csp/script /home/csps/
else
    echo "AVISO: Pasta /tmp/csp/script nao encontrada."
fi

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
