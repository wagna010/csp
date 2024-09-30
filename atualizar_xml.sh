#!/bin/bash
#################################################################################
# Script para atualizar o XML do CSP                                             #
#################################################################################

# Definição do nome base do arquivo
FILE_BASE="xml"

# URL completa padrão, incluindo domínio, porta e caminho
URL_DEFAULT="http://adm.painelip.com:26000/tools/xml.php"

# Diretório de destino
DESTINO_DIR="/home/csps/xml"

# Verifica se a URL foi passada como argumento, caso contrário usa a padrão
URL="${1:-$URL_DEFAULT}"

# Redireciona para o diretório de destino
if ! cd "$DESTINO_DIR"; then
    echo "Erro ao acessar o diretório $DESTINO_DIR"
    exit 1
fi

# Função para baixar o arquivo XML
baixar_xml() {
    local url="$1"
    local file="$2"
    
    # Faz o download do arquivo e verifica sucesso
    if ! wget "$url" -O "${file}.xml"; then
        echo "Erro ao fazer o download do arquivo: $url"
        exit 1
    fi
}

# Função para verificar o arquivo baixado
verificar_arquivo() {
    local file="$1"

    # Verifica o tamanho do arquivo
    local tamanho=$(du -b "${file}.xml" | cut -f1)

    # Define o tamanho mínimo aceitável (20 bytes)
    local tamanho_minimo=20
    if (( tamanho <= tamanho_minimo )); then
        echo "Arquivo ${file}.xml muito pequeno (tamanho: ${tamanho} bytes). Download falhou."
        exit 1
    fi

    # Verifica a presença da tag final do XML
    if grep -q '</xml-user-manager>' "${file}.xml"; then
        echo "Download do arquivo ${file}.xml concluído com sucesso."
        # Sobrescreve o arquivo como xmlOK.xml
        cp "${file}.xml" "${file}OK.xml"
    else
        echo "O arquivo ${file}.xml está incompleto. Mantendo o arquivo anterior."
    fi

    # Remove o arquivo original ultrapainel.xml
    rm -f "${file}.xml"
}

# Função principal para atualizar o XML
atualizar_xml() {
    local file="$1"

    # Baixa o XML
    baixar_xml "$URL" "$file"

    # Verifica o arquivo baixado e remove o original
    verificar_arquivo "$file"
}

# Nome fixo do arquivo XML, sem incluir a porta
FILE="${FILE_BASE}"

# Chama a função para atualizar o XML
atualizar_xml "$FILE"

exit 0
