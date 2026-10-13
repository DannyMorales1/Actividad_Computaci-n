#!/bin/bash
# =============================================================================
# gestor.sh - Gestor de demo-api
# =============================================================================

set -o pipefail
cd "$(dirname "$0")" || exit 1

# ------------------------------- VARIABLES -----------------------------------

PROYECTO="demo-api"
IMAGEN="demo-api:1.0"
CONTENEDOR="demo-api"
JAR_RUTA="target/demo-api-0.0.1-SNAPSHOT.jar"

PUERTO_HOST=8090
PUERTO_CONTENEDOR=8090
ENDPOINT="/api/status"
URL_LOCAL="http://127.0.0.1:${PUERTO_HOST}${ENDPOINT}"

DOCKER=(docker)

if ! docker info >/dev/null 2>&1; then
    if sudo -n docker info >/dev/null 2>&1; then
        DOCKER=(sudo docker)
    fi
fi

# ------------------------------- Functions -----------------------------------

pausa() {
    echo ""
    read -r -p "Pulsa ENTER para volver al menú..." _
}
# Validación:  ¿la imagen existe?
imagen_existe() {
    "${DOCKER[@]}" image inspect "$IMAGEN" >/dev/null 2>&1
}
# Validación:  ¿contenedor existe?
contenedor_existe() {
    [ -n "$("${DOCKER[@]}" ps -aq \
        -f "name=^${CONTENEDOR}$" 2>/dev/null)" ]
}
# Validación:  ¿contenedor corriendo?
contenedor_activo() {
    [ -n "$("${DOCKER[@]}" ps -q \
        -f "name=^${CONTENEDOR}$" 2>/dev/null)" ]
}

# Opción 1: verificar prerrequisitos
verificar_prerequisitos() {
    echo "=== Verificando prerrequisitos ==="

    for cmd in java curl; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "[OK] $cmd está disponible"
        else
            echo "[ERROR] No se encuentra $cmd"
        fi
    done

    if command -v mvn >/dev/null 2>&1; then
        echo "[OK] Maven está disponible"
    elif [ -f "./mvnw" ]; then
        echo "[OK] Se utilizará el wrapper ./mvnw"
    else
        echo "[ERROR] No se encuentra Maven ni ./mvnw"
    fi

    if command -v docker >/dev/null 2>&1; then
        if "${DOCKER[@]}" info >/dev/null 2>&1; then
            echo "[OK] Docker está instalado y operativo"
        else
            echo "[ERROR] No se puede acceder al servicio Docker"
            echo "        Comprueba sudo docker info"
        fi
    else
        echo "[ERROR] Docker no está instalado"
    fi

    if [ -f "./Dockerfile" ]; then
        echo "[OK] Dockerfile encontrado"
    else
        echo "[ERROR] No se encuentra el Dockerfile"
    fi

    echo ""
    java -version 2>&1 | head -n 1
}

# Opción 2: compilar el proyecto
compilar() {
    echo "=== Compilando $PROYECTO ==="

    if [ ! -f "./mvnw" ] && ! command -v mvn >/dev/null 2>&1; then
        echo "[ERROR] No se encuentra Maven ni ./mvnw"
        return 1
    fi

    if [ -f "./mvnw" ]; then
        chmod +x ./mvnw || return 1
        ./mvnw clean package -DskipTests
    else
        mvn clean package -DskipTests
    fi

    if [ $? -eq 0 ] && [ -f "$JAR_RUTA" ]; then
        echo "[OK] JAR generado: $JAR_RUTA"
    else
        echo "[ERROR] Falló la compilación o no se generó el JAR"
        echo "        Revisa la versión del JAR y los errores de Maven"
        return 1
    fi
}

# Opción 3: construir imagen Docker
construir_imagen() {
    echo "=== Construyendo imagen Docker ==="

    if [ ! -f "$JAR_RUTA" ]; then
        echo "[ERROR] No existe $JAR_RUTA"
        echo "        Ejecuta primero la opción 2"
        return 1
    fi

    if [ ! -f "./Dockerfile" ]; then
        echo "[ERROR] No se encuentra el Dockerfile"
        return 1
    fi

    if "${DOCKER[@]}" build -t "$IMAGEN" .; then
        echo "[OK] Imagen construida: $IMAGEN"
    else
        echo "[ERROR] Falló la construcción de la imagen"
        return 1
    fi
}

# Opción 4: ejecutar el contenedor
ejecutar_contenedor() {
    echo "=== Ejecutando contenedor ==="

    if ! "${DOCKER[@]}" info >/dev/null 2>&1; then
        echo "[ERROR] No se puede acceder a Docker"
        return 1
    fi

    if ! imagen_existe; then
        echo "[ERROR] No existe la imagen $IMAGEN"
        echo "        Ejecuta primero la opción 3"
        return 1
    fi

    if contenedor_existe; then
        echo "[AVISO] Ya existe un contenedor llamado $CONTENEDOR"
        read -r -p "¿Deseas reemplazarlo? (s/n): " respuesta

        case "$respuesta" in
            s|S)
                "${DOCKER[@]}" rm -f "$CONTENEDOR" || return 1
                ;;
            *)
                echo "Operación cancelada"
                return 0
                ;;
        esac
    fi

    if "${DOCKER[@]}" run -d \
        --name "$CONTENEDOR" \
        --restart unless-stopped \
        -p "${PUERTO_HOST}:${PUERTO_CONTENEDOR}" \
        "$IMAGEN"; then

        echo "[OK] Contenedor creado"
        echo "     URL local: $URL_LOCAL"
        echo "     Espera unos segundos y ejecuta la opción 6"
    else
        echo "[ERROR] No se pudo iniciar el contenedor"
        echo "        Revisa si el puerto $PUERTO_HOST está ocupado"
        return 1
    fi
}

# Opción 5: mostrar estado
mostrar_estado() {
    echo "=== Estado actual de $PROYECTO ==="

    if [ -f "$JAR_RUTA" ]; then
        echo "JAR:        existe ($JAR_RUTA)"
        du -h "$JAR_RUTA"
    else
        echo "JAR:        no existe"
    fi

    if imagen_existe; then
        echo "Imagen:     existe ($IMAGEN)"
    else
        echo "Imagen:     no existe"
    fi

    if contenedor_activo; then
        echo "Contenedor: EN EJECUCIÓN ($CONTENEDOR)"
        "${DOCKER[@]}" ps \
            --filter "name=^${CONTENEDOR}$" \
            --format "ID: {{.ID}} | Estado: {{.Status}} | Puertos: {{.Ports}}"
    elif contenedor_existe; then
        echo "Contenedor: existe, pero está detenido"
        "${DOCKER[@]}" ps -a \
            --filter "name=^${CONTENEDOR}$" \
            --format "ID: {{.ID}} | Estado: {{.Status}}"
    else
        echo "Contenedor: no existe"
    fi
}

# Opción 6: probar endpoint con curl
probar_endpoint() {
    echo "=== Verificando endpoint de Spring Boot ==="
    echo "URL: $URL_LOCAL"
    echo ""

    if ! command -v curl >/dev/null 2>&1; then
        echo "[ERROR] curl no está instalado"
        return 1
    fi

    if ! contenedor_activo; then
        echo "[ERROR] El contenedor no está en ejecución"
        echo "        Ejecuta primero la opción 4"
        return 1
    fi

    # Dar tiempo a Spring Boot para iniciar y aceptar solicitudes.
    for intento in $(seq 1 12); do
        respuesta=$(curl --silent --show-error \
            --connect-timeout 2 \
            --max-time 5 \
            --output /tmp/demo-api-response.json \
            --write-out "%{http_code}" \
            "$URL_LOCAL" 2>/dev/null)
        codigo_curl=$?

        if [ "$codigo_curl" -eq 0 ] && [ "$respuesta" = "200" ]; then
            echo "[OK] El endpoint respondió correctamente"
            echo "Código HTTP: $respuesta"
            echo "Respuesta del servidor:"
            cat /tmp/demo-api-response.json
            echo ""
            return 0
        fi

        echo "Intento $intento/12: todavía no responde correctamente..."
        sleep 2
    done

    echo ""
    echo "[ERROR] El endpoint no respondió con HTTP 200"
    echo "Último código HTTP: ${respuesta:-sin respuesta}"
    echo ""
    echo "=== Últimos logs del contenedor ==="
    "${DOCKER[@]}" logs --tail 50 "$CONTENEDOR"
    return 1
}

# ------------------------------- MENÚ -----------------------------------------

mostrar_menu() {
    clear
    echo "=========================================="
    echo "       GESTOR DE $PROYECTO"
    echo "=========================================="
    echo " 1) Verificar prerrequisitos"
    echo " 2) Compilar y empaquetar (Maven)"
    echo " 3) Construir imagen Docker"
    echo " 4) Ejecutar contenedor Docker"
    echo " 5) Mostrar estado actual"
    echo " 6) Probar endpoint con curl"
    echo " 7) Salir"
    echo "=========================================="
}

while true; do
    mostrar_menu
    read -r -p "Elige una opción [1-7]: " opcion

    case "$opcion" in
        1) verificar_prerequisitos; pausa ;;
        2) compilar; pausa ;;
        3) construir_imagen; pausa ;;
        4) ejecutar_contenedor; pausa ;;
        5) mostrar_estado; pausa ;;
        6) probar_endpoint; pausa ;;
        7) echo "¡Hasta pronto!"; exit 0 ;;
        *) echo "[ERROR] Opción no válida"; pausa ;;
    esac
done
