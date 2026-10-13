**Asignatura:** Computación Cliente-servidor y Administración de Sistemas
**Estudiante:** _Danny Alexander Morales Olaya_

Este proyecto contiene una aplicación web mínima con **Spring Boot**, un script de **Bash** (`gestor.sh`) que automatiza su ciclo de vida y un **Dockerfile** que la empaqueta para ejecutarla en cualquier máquina con Docker.

---

## Índice

1. [Qué hace el proyecto](#1-qué-hace-el-proyecto)
2. [Estructura del repositorio](#2-estructura-del-repositorio)
3. [Código Fuente](#3-código-fuente)
4. [Dockerfile](#4-dockerfile)
5. [Script gestor.sh](#5-script-gestor.sh)
6. [Evidencias](#6-evidencias)
---

## 1. Qué hace el proyecto

| Componente | Función |
|---|---|
| `ServerController.java` | Expone el endpoint `GET /api/status`, que expone un json `{
  "application": "demo-api",
  "status": "UP",
  "environment": "AWS EC2"
}`. |
| `gestor.sh` | Menú interactivo que verifica requisitos, compila, construye la imagen Docker, arranca el contenedor y muestra el estado. |
| `Dockerfile` | Crea una imagen ligera con Java 21 y la aplicación con un rename. |

---

## 2. Estructura del repositorio

```
demo-api/
├── pom.xml                     
├── mvnw / mvnw.cmd             
├── .mvn/                        
├── gestor.sh                    
├── Dockerfile                  
├── README.md                   
└── src/
    └── main/
        ├── java/com/example/demo/
        │   ├── DemoApiApplication.java   
        │   └── ServerController.java          # Controlador REST (creado en la práctica)
        |   └── Serverinfo.java                # Retorna el status del server
        └── resources/
            └── application.properties          # Se expone la aplicacion por el puerto 8090
```

Tras compilar aparece además `target/` con el JAR (`target/demo-api-0.0.1-SNAPSHOT.jar`).

---
## 3. Código fuente
### 3.1 Código del controlador (`ServerController.java`)

```java
package com.example.demo;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class ServerController {

    @GetMapping("/status")
    public ServerInfo status() {
        return new ServerInfo(
            "demo-api",
            "UP",
            "AWS EC2"
        );
    }
}
```
### 3.2 Código del controlador (`Serverinfo.java`)

```java
package com.example.demo;

public record ServerInfo(
    String application,
    String status,
    String environment
) {}
```
### 3.3 Ajuste application.properties 
```java
spring.application.name=demo-api
server.port=8090
```
---

## 3.4 Ejecución local de prueba

```bash
./mvnw clean package
```
Tras compilar aparece además `target/` con el JAR (`target/demo-api-0.0.1-SNAPSHOT.jar`).
Una vez verificado que se ha generado el componente, ejecutar el comando
```bash
java -jar target/demo-api-0.0.1-SNAPSHOT.jar
```
- Comprobación: curl http://localhost:8090/api/status → `"application":"demo-api","status":"UP","environment":"AWS EC2"`
- Parar con `Ctrl+C`.

---
## 4. Dockerfile
```yaml
FROM eclipse-temurin:21-jre-alpine

WORKDIR /opt/app

COPY target/demo-api-0.0.1-SNAPSHOT.jar app.jar

EXPOSE 8090

CMD ["java", "-jar", "app.jar"]
```
---

| Instrucción | Qué hace | Por qué |
|---|---|---|
| `FROM eclipse-temurin:21-jre-alpine` | Imagen base con Java 21 sobre Alpine Linux.
| `WORKDIR /opt/app` | Fija (y crea si no existe) el directorio de trabajo. | Las instrucciones siguientes se ejecutan desde ahí. |
| `COPY target/...jar app.jar` | Copia el JAR del host al contenedor, renombrado. | Nombre corto y estable (`app.jar`).
| `EXPOSE 8090` | Documenta el puerto de la app.
| `CMD ["java","-jar","app.jar"]` | Comando de arranque del contenedor.

**Construcción manual (lo que hace la opción 3):**

```bash
docker build -t demo-api:1.0 .
```

**Ejecución manual (lo que hace la opción 4):**

```bash
docker run -d --name demo-api -p 8090:8090 demo-api:latest
```

**Comprobación:**

```bash
docker ps                          # el contenedor aparece en la lista
curl http://localhost:8090/api/status   # responde: "application":"demo-api","status":"UP","environment":"AWS EC2"
docker logs demo-api       # registros de la aplicación
```


## 5. Script `gestor.sh`

Menú interactivo en Bash con seis opciones. Se ejecuta desde la raíz del proyecto.

### 5.1 Variables

```bash
PROYECTO="demo-api"
IMAGEN="demo-api:1.0"
CONTENEDOR="demo-api"
JAR_RUTA="target/demo-api-0.0.1-SNAPSHOT.jar"

PUERTO_HOST=8090
PUERTO_CONTENEDOR=8090
ENDPOINT="/api/status"
URL_LOCAL="http://127.0.0.1:${PUERTO_HOST}${ENDPOINT}"
```

| Variable | Contenido | Uso |
|---|---|---|
| `PROYECTO` | Nombre del proyecto |
| `IMAGEN` | `nombre:etiqueta` de la imagen |
| `CONTENEDOR` | Nombre del contenedor | 
| `JAR_RUTA` | Ruta del JAR generado |
| `PUERTO_HOST` | Puerto publicado en el host |
| `PUERTO_CONTENEDOR` | Puerto publicado en el container |
| `ENDPOINT` | Endpoint de la app |
| `URL_LOCAL` | URL Para verificar el funcionamiento del endpoint |
**Por qué variables:** el requisito pide no repetir valores literales. Cambiar un nombre se hace en un solo sitio (mantenimiento y reutilización).

### 5.2 Funciones auxiliares

```bash
pausa() {
    echo ""
    read -r -p "Pulsa ENTER para volver al menú..." _
}

imagen_existe() {
    "${DOCKER[@]}" image inspect "$IMAGEN" >/dev/null 2>&1
}

contenedor_existe() {
    [ -n "$("${DOCKER[@]}" ps -aq \
        -f "name=^${CONTENEDOR}$" 2>/dev/null)" ]
}

contenedor_activo() {
    [ -n "$("${DOCKER[@]}" ps -q \
        -f "name=^${CONTENEDOR}$" 2>/dev/null)" ]
}
```

- `pausa`: evita que `clear` del menú borre el resultado antes de leerlo. `read -r` impide que las barras invertidas se interpreten.
- `imagen_existe`: devuelve **éxito (0)** si la imagen existe y fallo si no. `> /dev/null 2>&1` descarta toda la salida; solo interesa el **código de salida**. Se usa dentro de `if`.
- `contenedor_existe`: devuelve **éxito (0)** si la imagen existe y fallo si no.
- `contenedor_activo`: devuelve **éxito (0)** si la imagen existe y fallo si no.


### 5.3 Opción 1: Verificar prerrequisitos

```bash
for cmd in java mvn docker; do
    if command -v "$cmd" > /dev/null 2>&1; then
        echo "[OK]    $cmd está disponible"
    elif [ "$cmd" = "mvn" ] && [ -f "./mvnw" ]; then
        echo "[OK]    mvn no está instalado, pero se usará el wrapper ./mvnw"
    else
        echo "[ERROR] $cmd NO está instalado o no está en el PATH"
    fi
done

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
```

| Elemento | Explicación |
|---|---|
| `for cmd in java curl` | **Bucle `for`** sobre una lista; añadir otra herramienta es añadir una palabra. |
| `command -v "$cmd"` | Comprueba si el comando existe en el `PATH` |
| `elif ... -f "./mvnw"` | El enunciado permite "mvn o usar el wrapper": si no hay Maven global pero existe `mvnw`, se considera válido. |
| `else` | Mensaje de error si no está disponible. |
| `java -version 2>&1 | head -n 1` | Version Java. |

Adicionalmente verifica que el **servicio Docker esté en marcha** con `docker info`: es un error común tener Docker instalado pero sin arrancar.

### 5.4 Opción 2: Compilar y empaquetar

```bash
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
```

| Elemento | Explicación |
|---|---|
| `[ ! -f "./mvnw" ]` (previo) | Si no existe el wrapper, se informa y se sale de la función (`return`). |
| `chmod +x ./mvnw` | Asegura permiso de ejecución (a veces se pierde al descomprimir/copiar). |
| `clean` | Borra compilaciones anteriores (`target/`). |
| `package` | Compila y empaqueta en un JAR ejecutable. |
| `-DskipTests` | Omite los tests para acelerar. |
| `[ -f "$JAR_RUTA" ]` | **Verifica el resultado real**: que el JAR exista, en vez de fiarse de que Maven "terminó". |

### 5.5 Opción 3: Construir la imagen Docker

```bash
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
```

- `"${DOCKER[@]}" build -t "$IMAGEN" .`: construye con el `Dockerfile` del directorio actual (`.` es el **contexto de construcción**) y le pone el nombre/etiqueta (`-t`).

### 5.6 Opción 4: Ejecutar el contenedor
```bash
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
```
Secuencia de comprobaciones:

1. Valida privilegios de docker.
2. **¿Existe la imagen?** Si no, sugiere la opción 3.
3. **¿Ya existe un contenedor con ese nombre?**
   - Si existe, se **pregunta al usuario** si desea detenerlo y eliminarlo.
4. **Arranque:**
   ```bash
   docker run -d --name "$CONTENEDOR" --restart unless-stopped -p "${PUERTO_HOST}:${PUERTO_CONTENEDOR}" "$IMAGEN"
   ```

| Opción | Significado |
|---|---|
| `-d` | *Detached*: en segundo plano (no bloquea el menú). |
| `--name` | Nombre fijo del contenedor (permite gestionarlo y detectarlo). |
| `--restart unless-stopped` | Define una política de reinicio automático del contenedor |
| `-p "${PUERTO_HOST}:${PUERTO_CONTENEDOR}"` | Publica el puerto: `PUERTO_HOST:PUERTO_CONTENEDOR`. Sin esto la app no sería accesible desde el navegador. |

### 5.7 Opción 5: Mostrar el estado
```bash
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
```
| Dato | Cómo se obtiene |
|---|---|
| ¿Existe el JAR? ¿Tamaño? | `[ -f "$JAR_RUTA" ]` y `du -h "$JAR_RUTA" \| cut -f1` (tamaño legible: K/M). |
| ¿Existe la imagen? ¿Cuándo se creó? | `docker image inspect -f '{{.Created}}' "$IMAGEN"`. |
| ¿Contenedor en ejecución? | `docker ps -q -f "name=^${CONTENEDOR}$"` (sin `-a`: solo los **en marcha**) y `docker ps --format ...` para ID, estado y puertos. |

### 5.8 Probar Endpoint

```bash
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
```

| Elemento | Explicación |
|---|---|
| `command -v curl` | Comprueba si el comando curl está disponible en el sistema.. |
| `contenedor_activo` | Verifica si el contenedor definido en la variable CONTENEDOR está en ejecución. |
| `for intento in $(seq 1 12)` | Repite la prueba hasta 12 veces. |
| `docker logs --tail 50` | Muestra los últimos 50 registros del contenedor para diagnosticar el problema. |
| `exit 0` | Termina el script con éxito. |

### 5.9 Opción 7  bucle principal

```bash
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
```

| Elemento | Explicación |
|---|---|
| `while true` | **Bucle infinito**: el menú se repite hasta que el usuario elige salir. |
| `read -r -p` | Lee la opción mostrando un mensaje. |
| `case "$opcion" in` | Evalúa el valor introducido y selecciona la rama que corresponde. |

## 6. Evidencias

Esta sección presenta las evidencias de compilación, construcción y ejecución de la aplicación Docker, así como las funcionalidades del script de automatización desarrollado en Bash.

### 6.1. Construcción de la imagen Docker

<p align="center">
  <img src="https://github.com/user-attachments/assets/34f9f0bd-5381-445b-94e3-81ecf11f7aec" alt="Proceso de construcción de la imagen Docker" width="100%">
</p>

<p align="center">
  <em>Figura 1. Construcción de la imagen Docker de la aplicación.</em>
</p>

### 6.2. Ejecución del contenedor Docker

<p align="center">
  <img src="https://github.com/user-attachments/assets/ce40943b-d4d9-4cb0-a49a-8358034ebacc" alt="Ejecución del contenedor Docker" width="100%">
</p>

<p align="center">
  <em>Figura 2. Ejecución del contenedor Docker mediante el comando correspondiente.</em>
</p>

### 6.3. Verificación de los logs del contenedor

<p align="center">
  <img src="https://github.com/user-attachments/assets/449e6c35-ac45-47de-b844-bff17e65bef9" alt="Verificación de los logs del contenedor Docker" width="100%">
</p>

<p align="center">
  <em>Figura 3. Validación de los registros de ejecución del contenedor.</em>
</p>

### 6.4. Validación de la respuesta del endpoint

<p align="center">
  <img src="https://github.com/user-attachments/assets/c5981fe0-b569-480f-ad8a-e20d1f20a474" alt="Respuesta del endpoint de la aplicación" width="100%">
</p>

<p align="center">
  <em>Figura 4. Verificación de la respuesta del endpoint de la aplicación.</em>
</p>

### 6.5. Gestor de automatización mediante script Bash

Esta sección documenta las funcionalidades del script de gestión, diseñado para automatizar las tareas de validación de prerrequisitos, compilación, construcción de imágenes, ejecución de contenedores y pruebas del endpoint.

#### 6.5.1. Menú principal

<p align="center">
  <img src="https://github.com/user-attachments/assets/67e52e9e-7059-43b4-8e22-0ac1b6368848" alt="Menú principal del gestor Bash" width="600">
</p>

<p align="center">
  <em>Figura 5. Menú principal del script de automatización.</em>
</p>

#### 6.5.2. Verificación de prerrequisitos

<p align="center">
  <img src="https://github.com/user-attachments/assets/d0da1fe0-0fe3-4ced-9e40-d72823d3a706" alt="Verificación de prerrequisitos del entorno" width="600">
</p>

<p align="center">
  <em>Figura 6. Validación de las herramientas y dependencias necesarias para la ejecución.</em>
</p>

#### 6.5.3. Compilación de la aplicación

<p align="center">
  <img src="https://github.com/user-attachments/assets/461976fb-bf06-4341-9afa-a292458c6a13" alt="Proceso de compilación de la aplicación" width="100%">
</p>

<p align="center">
  <em>Figura 7. Ejecución del proceso de compilación de la aplicación.</em>
</p>

#### 6.5.4. Construcción de la imagen Docker

<p align="center">
  <img src="https://github.com/user-attachments/assets/403e613f-a5b3-4993-b664-5d151e90ede7" alt="Construcción de la imagen Docker desde el gestor Bash" width="100%">
</p>

<p align="center">
  <em>Figura 8. Construcción de la imagen Docker desde el menú de automatización.</em>
</p>

#### 6.5.5. Verificación de la imagen Docker

<p align="center">
  <img src="https://github.com/user-attachments/assets/a2294ec0-2ed4-48fd-b8b2-9dcedb539c2f" alt="Verificación del resultado de la construcción de la imagen Docker" width="100%">
</p>

<p align="center">
  <em>Figura 9. Verificación del resultado del proceso de construcción de la imagen.</em>
</p>

#### 6.5.6. Ejecución del contenedor Docker

<p align="center">
  <img src="https://github.com/user-attachments/assets/10e21f9b-1566-4d1d-ad91-52bd95f91f77" alt="Ejecución del contenedor Docker desde el gestor Bash" width="100%">
</p>

<p align="center">
  <em>Figura 10. Ejecución del contenedor mediante el script de automatización.</em>
</p>

#### 6.5.7. Consulta del estado del contenedor

<p align="center">
  <img src="https://github.com/user-attachments/assets/3b827b0e-cd04-4f1c-af03-9dcd730bedc3" alt="Consulta del estado del contenedor Docker" width="800">
</p>

<p align="center">
  <em>Figura 11. Consulta del estado del contenedor desde el gestor Bash.</em>
</p>

#### 6.5.8. Prueba del endpoint

<p align="center">
  <img src="https://github.com/user-attachments/assets/97677bb5-fa36-48e0-8f30-8e70a0dc206f" alt="Prueba del endpoint desde el gestor Bash" width="100%">
</p>

<p align="center">
  <em>Figura 12. Validación de la respuesta del endpoint mediante el script de automatización.</em>
</p>
