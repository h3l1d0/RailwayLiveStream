# Implementar streaming WebRTC sin OBS

Este documento te guía para construir un flujo “tipo Studio” usando solo el navegador y tu propia infraestructura. El objetivo es capturar audio/video en el browser, transportarlo vía WebRTC hacia tu backend y desde allí redistribuirlo (RTMP/HLS o WebRTC directo) sin depender de OBS.

---

## 1. Arquitectura resumida

1. **Frontend (Browser)**  
   - Captura cámara/micrófono/pantalla con `getUserMedia` o `getDisplayMedia`.  
   - Crea un `RTCPeerConnection`, publica las pistas y maneja señalización (ICE candidates, SDP).  
   - Opcional: renderiza overlays en un `<canvas>` y usa `canvas.captureStream()` como fuente.

2. **Backend de ingest WebRTC**  
   - Expone un endpoint de señalización (REST/WS) para intercambiar SDP/ICE.  
   - Mantiene la sesión WebRTC, recibe los frames y los distribuye.  
   - Puede convertir a otros protocolos (RTMP, HLS) o reenviar WebRTC a espectadores.

3. **Playout / servicios auxiliares**  
   - Redistribuir el stream (RTMP → Twitch/YouTube, HLS para players web, WebRTC low-latency).  
   - Añadir grabaciones, escena compartida, chat, métricas, etc.

---

## 2. Frontend básico

```js
const pc = new RTCPeerConnection({ iceServers: [{ urls: 'stun:stun.l.google.com:19302' }] });
const media = await navigator.mediaDevices.getUserMedia({ audio: true, video: true });

media.getTracks().forEach(track => pc.addTrack(track, media));

// Enviá la SDP al backend (fetch/WS)
const offer = await pc.createOffer();
await pc.setLocalDescription(offer);
await sendOfferToServer(pc.localDescription);

// Recibí answer y candidatos remotos desde el backend
```

Para invitados remotos replicás la lógica (cada invitado es un peer). En una “sala” usás un SFU (Selective Forwarding Unit) para mezclar o reenviar streams.

---

## 3. Backend en Python (aiortc)

Si querés controlar el backend en Python, [`aiortc`](https://github.com/aiortc/aiortc) es la librería más madura:

1. Crear servicio FastAPI/Starlette para manejar `/offer` (recibe SDP) y `/candidate`.  
2. Con `aiortc.RTCPeerConnection` aceptás la oferta, añadís handlers a `pc.on('track')` y devolvés la respuesta SDP.  
3. Para reemitir:
   - **WebRTC**: reenviás las pistas a otros peers (construís tu propio SFU básico).  
   - **RTMP/HLS**: conectá los frames a FFmpeg (`MediaStreamTrack` → `av` → pipe a `ffmpeg` con `-f h264`/`aac`). Ejemplo rápido:

```python
@pc.on("track")
async def on_track(track):
    if track.kind == "video":
        recorder = MediaRecorder(
            "rtmp://switchback.proxy.rlwy.net:37081/live/h3l1d0",
            format="flv"
        )
        await recorder.start()
        await recorder.addTrack(track)
```

Con `MediaRecorder` podés volcar directo a RTMP/HLS (soporta `ffmpeg` por debajo). Ajustá credenciales/puerto a tu infraestructura.

**Ventajas**: full Python, integración con tu lógica (auth, overlays server-side).  
**Desventajas**: `aiortc` no es SFU puro; para múltiples espectadores tendrás que implementar mezcla o forwarding manual, y escalar requiere más trabajo.

---

## 4. Backend contenedorizado (SRS / LiveKit / OvenMediaEngine)

Si preferís algo listo para producción, despliega un servidor WebRTC dedicado:

- **SRS (Simple Realtime Server)**  
  - Soporta WHIP/WHEP (estándares para WebRTC ingest/playback).  
  - Configuración mínima vía Docker: `ossrs/srs:5` con un `conf/rtc.conf` que habilite `rtc_server`.  
  - Puedes usar librerías como [`@livekit/whip-web`](https://github.com/livekit/client-sdk-js) o [`simple-whip`](https://github.com/membrane/simple-whip-client-js) para publicar desde el navegador.  
  - SRS puede sacar a RTMP, HLS, WebRTC simultáneo. Ideal si querés mantener tu contenedor en Railway.

- **LiveKit**  
  - SDK web (React, JS), SDK backend (Go, Node, Python).  
  - Tiene `egress` para exportar WebRTC a RTMP/HLS.  
  - Puedes self-host (Docker/Helm) o usar LiveKit Cloud.

- **OvenMediaEngine / Ant Media**  
  - Integran ingest WebRTC y salida multi-protocolo.  
  - Más orientado a producción con dashboards y escalado horizontal.

Con estas alternativas solo componés tu frontend y te apoyás en el servidor para la lógica compleja (SFU, grabación, TURN).

---

## 5. Consideraciones clave

- **Señalización**: WebRTC no define transporte para intercambiar SDP/ICE. Necesitás un canal (REST, WebSocket).  
- **STUN/TURN**: imprescindible para usuarios detrás de NAT. Usa un STUN público y, para confiabilidad, configura tu propio TURN (ej. `coturn`).  
- **Latencia**: WebRTC puede bajar a ~500 ms; HLS estándar ronda 6‑10 s. Elige según el tipo de audiencia.  
- **Escalado**: un solo servidor puede saturar si mezclas video; considera SFUs (LiveKit, mediasoup) o CDNs especializados.  
- **Seguridad**: autentica las sesiones, controla quién puede publicar/consumir. TLS obligatorio (WebRTC requiere HTTPS/WSS).  
- **Acceso directo vs contenedor**: Python + aiortc funciona si controlás el stack y el tráfico es moderado. Para un servicio robusto usa contenedores con servidores concebidos para WebRTC; puedes combinarlos con tu backend Python para auth/billing/analytics.

---

## 6. Próximos pasos sugeridos

1. Construye un prototipo frontend con `getUserMedia` y un canal simple de señalización (por ejemplo FastAPI + WebSockets).  
2. Decide si integrar `aiortc` o delegar a un servidor dedicado (SRS/LiveKit).  
3. Configura STUN/TURN y prueba una sesión real desde redes diferentes.  
4. Añade redistribución: RTMP hacia tus servicios existentes o HLS para compatibilidad web.  
5. Empaqueta todo en Docker si necesitas desplegarlo en Railway u otro proveedor.

Con este pipeline tendrás un “estudio” propio en navegador, controlando tanto la ingestión como la distribución dentro de tu infraestructura.
