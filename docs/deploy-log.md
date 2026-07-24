# Bitácora de despliegues — ExamenFinalDistribuidos

Registro de cada despliegue real realizado durante el trabajo (commit → pipeline de CI/CD →
promoción al clúster de Minikube). Base para el cálculo de las 3 métricas DORA del informe
(Parte II). Todas las horas en `-05:00` (hora local), tomadas de `git log --format=%aI`,
`gh run list --json createdAt,updatedAt` y `kubectl get replicaset
--sort-by=.metadata.creationTimestamp` (cada `ReplicaSet` nuevo = una promoción real al
clúster).

| # | Commit | Fecha commit | Resultado pipeline | Pipeline termina | Aplicado al clúster | ¿Requirió corrección? |
|---|---|---|---|---|---|---|
| 1 | `701456e` — agregar Dockerfile y pipeline de CI/CD | 2026-07-22 19:00 | success | 19:01 | *(sin despliegue a k8s todavía)* | No |
| 2 | `2eb8585` — agregar Deployment y Service base con rolling update | 2026-07-22 20:29 | success | 20:30 | 2026-07-22 19:39 (`inventario-app-6f89d4994`) | No |
| 3 | `12618ab` — agregar estrategia de despliegue Blue-Green | 2026-07-22 21:54 | success | 21:55 | 2026-07-22 21:36 / 21:41 (`inventario-app-blue-944f64b66`, `inventario-app-green-557f8db955`) | No |
| 4 | `512a5ab` — agregar manejo de secretos via secretKeyRef | 2026-07-23 13:02 | success | 13:03 | 2026-07-23 12:50 (`inventario-app-56cfdd6d98`) | No |
| 5 | `097816f` — agregar readiness con arranque lento (STARTUP_DELAY_SECONDS) | 2026-07-23 17:23 | success | 17:23 | 2026-07-23 17:25 (`inventario-app-6c5b4bc8f`) | **Sí** — 2 intentos previos sin commitear: faltaba la env var, y después el `server.js` no estaba pusheado |
| 6 | `01eb4fc` — agregar escaneo de seguridad con Trivy al pipeline | 2026-07-23 17:34 | **failure** | 17:34 | — | **Sí** — tag `aquasecurity/trivy-action@0.24.0` sin el prefijo `v` |
| 7 | `defeb9b` — bajar version de express a proposito (demo de Trivy fallando) | 2026-07-23 17:41 | **failure** | 17:41 | — | **Sí** — mismo bug de tag arrastrado del commit anterior |
| 8 | `93c065b` — corregir version de la accion de Trivy | 2026-07-23 17:46 | **failure** | 17:47 | — | **Sí** — esta vez Trivy corrió de verdad y encontró `CVE-2026-59873` (CRITICAL) en `tar`, vía `express@4.17.1` |
| 9 | `ec9d09c` — corregir version de express, pipeline en verde de nuevo | 2026-07-23 18:07 | **failure** | 18:07 | — | **Sí** — el mismo CVE seguía apareciendo; venía del `npm` interno de la imagen base `node:20-alpine`, no de `express` |
| 10 | `6c27256` — eliminar npm de la imagen final para evitar vulnerabilidad CRITICAL en su tar interno | 2026-07-23 18:11 | success | 18:12 | 2026-07-23 18:25 (`kubectl rollout restart`, confirmado con `rollout status`) | No |

## Cálculo de las 3 métricas DORA

### Lead time for changes

Tiempo entre el commit de un cambio y el momento en que quedó corriendo realmente en el clúster
(`kubectl apply`/`rollout restart` confirmado, no solo publicado en `ghcr.io`).

- **Ejemplo 1** (fila 5): commit `097816f` a las **17:23:00** → nuevo `ReplicaSet` en el clúster
  a las **17:25:14** → **lead time = 2 min 14 s**.
- **Ejemplo 2** (fila 10): commit `6c27256` a las **18:11:23** → `rollout status` confirma
  éxito a las **18:25:17** → **lead time = 13 min 54 s**.

> Nota: en la mayoría de los demás despliegues (filas 2, 3, 4) se aplicó primero al clúster
> local para probar, y se commiteó después — por eso esas filas no sirven como ejemplo de lead
> time en sentido estricto (el despliegue ocurrió *antes* que el commit). Los dos ejemplos de
> arriba se eligieron porque el despliegue dependía de que el pipeline construyera una imagen
> nueva primero, así que el commit sí precede al despliegue.

### Frecuencia de despliegue

10 promociones reales al clúster (8 del Deployment base + 2 de Blue-Green, contando cada
`ReplicaSet` nuevo), en un lapso de **2 días** de trabajo (2026-07-22 a 2026-07-23).

**Frecuencia ≈ 5 despliegues/día.**

### Change failure rate

De los 10 runs de pipeline desde que existe CI/CD (filas 1 y 5 a 10 de esta tabla, 6 runs;
sumando también los 2 intentos sin commitear de la fila 5, hay más intentos "reales" de los que
refleja solo el conteo de commits — para esta métrica se cuentan los **runs de pipeline**, que
son el evento verificable con timestamp):

- Runs totales: **10**
- Runs que fallaron y requirieron un commit de corrección posterior: **4** (filas 6, 7, 8, 9)

**Change failure rate = 4 / 10 = 40%**

Cae en la banda más baja de la tabla de niveles DORA — explicable porque son 10 eventos en
apenas 2 días, generados por una sola persona aprendiendo la herramienta por primera vez, con
3 causas de fallo distintas y reales (no el mismo error repetido). Ampliado con la reflexión de
por qué en el informe de la Parte II.
