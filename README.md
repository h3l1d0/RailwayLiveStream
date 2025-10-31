# Railway Live Stream

Infraestructura mínima para desplegar en Railway un contenedor `nginx-rtmp` que recibe video desde OBS vía RTMP y lo sirve como HLS para reproducirlo en la web.

## Flujo general

1. **OBS (emisión)**: configura OBS con destino custom RTMP apuntando al host/puerto TCP que Railway asigna y usa una `streamkey`.
2. **Servidor nginx-rtmp**: este proyecto contiene el Dockerfile y `nginx.conf` que convierten el RTMP en playlists HLS (`/hls/<streamkey>.m3u8`).
3. **Web**: cualquier cliente compatible con HLS (p. ej. `hls.js`, Safari, reproductores nativos) puede consumir la URL expuesta por Railway.

## Archivos relevantes

- `Dockerfile`: imagen basada en Alpine que instala `nginx`, `nginx-mod-rtmp` y `ffmpeg`, copia la configuración y sitio estático.
- `nginx.conf`: define el bloque RTMP (ingest) y el bloque HTTP que expone `/hls`.
- `public/index.html`: página simple de comprobación servida en `/`.
- `.dockerignore`: evita subir archivos innecesarios a la build.

## Despliegue en Railway

1. Crea un proyecto en Railway y elige **Deploy from Dockerfile** apuntando a este repositorio.
2. Railway detectará el `Dockerfile` y construirá la imagen automáticamente.
3. En la sección **Networking**, asegúrate de tener:
   - Puerto `80` expuesto (HTTP).
   - Puerto `1935` expuesto (TCP para RTMP). Railway te dará un host/puerto público.
4. En OBS:
   - `Settings → Stream → Service`: Custom.
   - URL: `rtmp://<host-railway>:<puerto>/live`
   - Stream Key: define una cadena (ej. `streamkey`).
5. Cuando OBS esté emitiendo, la playlist HLS estará disponible en `https://<tu-servicio>.railway.app/hls/<streamkey>.m3u8`.

## Reproducción de prueba

```html
<video id="live" controls autoplay muted playsinline></video>
<script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
<script>
  const video = document.getElementById('live');
  const source = 'https://<tu-servicio>.railway.app/hls/streamkey.m3u8';

  if (Hls.isSupported()) {
    const hls = new Hls();
    hls.loadSource(source);
    hls.attachMedia(video);
  } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
    video.src = source;
  }
</script>
```

- Sustituye `<tu-servicio>` y `streamkey` según tu despliegue.
- En Safari (macOS/iOS) basta con asignar la URL al `src` del video.

## Notas

- La carpeta `/tmp/hls` sólo existe mientras el contenedor está en ejecución, por lo que esta versión no persiste grabaciones.
- Ajusta bitrate en OBS de acuerdo con los límites de tu plan de Railway.
