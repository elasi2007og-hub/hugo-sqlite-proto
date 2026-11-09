# hugo-sqlite-proto

Prototipo didáctico: **Hugo** genera HTML estático desde Markdown y **SQLite** trabaja
**solo en tiempo de build** (indexar y agregar). En producción: ficheros estáticos, nada más.

Continuación de la práctica
[P1.2 — Tu mini sitio web con Hugo](https://www.librebits.info/2asir/iaw/mini-sitio-web-con-hugo/).

**Demo en vivo (original):** [fp-bits.github.io/hugo-sqlite-proto](https://fp-bits.github.io/hugo-sqlite-proto/)  
**Demo en vivo (este fork):** [elasi2007og-hub.github.io/hugo-sqlite-proto](https://elasi2007og-hub.github.io/hugo-sqlite-proto/)

## Hugo build 
El generador de sitios web estático [Hugo](https://gohugo.io/documentation) construye 'las páginas web html (+ css, +javascript)' cuando ejecutas 'hugo serve' desde la terminal.
Ese comando detecta cambios en `content/` y `layouts/` y reconstruye el sitio automáticamente, sin que tengas que parar y volver a arrancar nada.
 
## Idea ([Unix](https://es.wikipedia.org/wiki/Unix): cada pieza hace una cosa, se unen con ficheros, a modo 'tuberías')

```
content/*.md --> tools/index.py --> build/site.db --+--> static/search.json --> navegador (search.js)
 (Markdown)       (parsea + INSERT)   (SQLite, local) +--> data/tags.json -----> Hugo (layouts/index.html)
                                                      +--> data/words.json ----> Hugo (layouts/partials/footer.html)

                                     hugo --> public/   <- lo único que se despliega
```

`build/`, `static/search.json`, `data/tags.json` y `data/words.json` están en `.gitignore`: se **regeneran** en cada build.

## Requisitos

- [Hugo](https://gohugo.io/installation/) (versión estándar, no hace falta *extended*)
- Python 3.8+ (solo biblioteca estándar: [`sqlite3`](https://docs.python.org/3/library/sqlite3.html), `json`, `re`)
- `make`

## Uso

```bash
make            # == make help
make serve    # índice + servidor local en http://localhost:1313/
make build    # índice + hugo --gc --minify  → public/
make check    # valida que los JSON generados son JSON válido
make clean
make check-invites   # [profesor] invitaciones de colaborador pendientes (gh CLI)
```

## Estructura

```
content/            Markdown con front matter YAML (el borrador no se indexa ni se publica)
layouts/            Plantillas Hugo: baseof, single, list, index + parciales header/footer
static/search.js    Búsqueda en el navegador: vainilla ES6+, estilo funcional
static/style.css    CSS3 con variables y modo oscuro
tools/index.py      Markdown → SQLite → JSON (funciones puras + efectos al final)
Makefile            index · build · serve · check · clean
```

## Dónde mirar

- **SQL como generador de JSON**: `Q_SEARCH` y `Q_TAGS` en `tools/index.py`
  ([JSON1](https://www.sqlite.org/json1.html), `GROUP BY`, `COUNT`).
- **Datos de build en plantillas**: `hugo.Data.tags` en `layouts/index.html`
  ([Hugo data](https://gohugo.io/content-management/data-sources/)).
- **Búsqueda sin servidor**: `static/search.js` ([`fetch`](https://developer.mozilla.org/es/docs/Web/API/Fetch_API),
  [`filter`](https://developer.mozilla.org/es/docs/Web/JavaScript/Reference/Global_Objects/Array/filter),
  [`normalize`](https://developer.mozilla.org/es/docs/Web/JavaScript/Reference/Global_Objects/String/normalize)).

## Ejercicios

1. Añade un post con `tags: [sql]` y comprueba cómo cambia el conteo de etiquetas en la home (`make serve`).
2. `hugo server -D` muestra el borrador, pero la búsqueda no lo encuentra. ¿Por qué? Añade un
   flag `--drafts` a `tools/index.py` para que coincidan.
3. Añade una tabla `words(url, n)` con el número de palabras de cada post y muestra el total en el pie.
4. Cambia la búsqueda para ordenar los resultados por número de coincidencias (sigue siendo una función pura).
5. Despliega `public/` con `rsync` a tu VPS o con GitHub Pages. ¿Qué proceso corre en el servidor? (Ninguno de tuyos.)

## Resolución de la práctica y documentación de cambios

### Comprensión del flujo (`content/*.md` → `tools/index.py` → SQLite → JSON → Hugo / JS)
1. **Extracción y limpieza (funciones puras en Python):** `tools/index.py` recorre `content/**/*.md`, separa el front matter YAML del cuerpo Markdown (`split_front_matter`, `parse_meta`), limpia el Markdown a texto plano (`plain`) y calcula el conteo de palabras (`count_words`).
2. **Almacenamiento e indexación en tiempo de build (SQLite):** `build_db()` crea de cero `build/site.db` e inserta las filas en las tablas relacionales `posts(url, title, date, summary, body)`, `tags(url, tag)` y `words(url, n)`.
3. **Agregación y serialización con SQL (`JSON1`):** Mediante `json_group_array`, `json_object`, `json_group_object`, `GROUP BY`, `COUNT`, `SUM` y `AVG`, el propio motor SQLite genera directamente tres ficheros JSON estáticos:
   - `static/search.json`: índice completo de búsqueda con metadatos, etiquetas y número de palabras por post (`LEFT JOIN words`).
   - `data/tags.json`: conteo de artículos agrupados por etiqueta (`GROUP BY tag`).
   - `data/words.json`: suma total de palabras (`SUM(n)`), total de páginas (`COUNT(*)`), media por página (`ROUND(AVG(n))`) y mapa `by_url` (`json_group_object(url, n)`).
4. **Consumo estático en plantillas y navegador:** Hugo inyecta `hugo.Data.tags` en `layouts/index.html` y `hugo.Data.words` en `layouts/partials/footer.html` y `layouts/_default/single.html` para generar el HTML final en `public/`. En el cliente, `static/search.js` descarga `search.json` y filtra/ordena en memoria sin necesidad de backend.

### Ejercicios resueltos

1. **Ejercicio 1 — Nuevos posts con `tags: [sql]`:**
   - Se han añadido los artículos `content/posts/consultas-agregadas-sql.md` (`tags: [sql, sqlite, build]`) y `content/posts/despliegue-estatico-github-pages.md` (`tags: [sql, static, unix]`).
   - Al ejecutar `make index` / `make serve`, la consulta `Q_TAGS` agrupa en SQLite las etiquetas y `data/tags.json` refleja automáticamente `sql` con su conteo actualizado en la portada.

2. **Ejercicio 2 — Por qué `hugo server -D` no encontraba el borrador y flag `--drafts`:**
   - **¿Por qué ocurría?** `hugo server -D` le indica a Hugo que renderice el HTML de los contenidos con `draft: true` (`content/posts/borrador.md`), pero el buscador en el navegador consulta `static/search.json`, que es generado por `tools/index.py`. Como `read_all()` filtraba siempre `if not page["draft"]`, el borrador nunca entraba en `build/site.db` ni en `static/search.json`.
   - **Solución:** Se parametrizó `read_all(include_drafts=False)` y se añadió soporte para `--drafts` (y `-D`) en `tools/index.py`, además del objetivo `make serve-drafts` en el `Makefile`.

3. **Ejercicio 3 — Tabla `words(url, n)` y total de palabras en el pie:**
   - Se añadió la función pura `count_words(text)` y la tabla `words(url TEXT PRIMARY KEY REFERENCES posts(url), n INTEGER NOT NULL DEFAULT 0)` al esquema SQLite.
   - Se creó la consulta `Q_WORDS` para exportar `data/words.json` y se actualizó `layouts/partials/footer.html` para mostrar el total de palabras, número de páginas y media por página en el pie del sitio. Además se añadió `data/words.json` a `make check`, `make clean` y `.gitignore`.

4. **Ejercicio 4 — Ordenar resultados de búsqueda por número de coincidencias (estilo funcional):**
   - En `static/search.js` se añadieron las funciones puras `countTerm(text, t)` y `hits(ts)(post)` que contabilizan cuántas veces aparecen los términos buscados en el título, etiquetas y cuerpo normalizados.
   - `search(posts, query)` filtra los posts que contienen todos los términos, proyecta nuevos objetos inmutables (`{ ...post, hits: score(post) }`) sin mutar el array original y los ordena de mayor a menor número de coincidencias (`b.hits - a.hits`), mostrando además el contador de coincidencias junto a cada resultado.

5. **Ejercicio 5 — Despliegue de `public/` con GitHub Pages / `rsync`:**
   - Se ha desplegado el contenido estático generado en `public/` en GitHub Pages: [https://elasi2007og-hub.github.io/hugo-sqlite-proto/](https://elasi2007og-hub.github.io/hugo-sqlite-proto/).
   - **¿Qué proceso de los nuestros corre en el servidor?** **Ninguno.** Ni Python, ni SQLite, ni Hugo existen en producción: `tools/index.py`, `build/site.db` y Hugo se ejecutan exclusivamente en tiempo de *build*. El servidor web solo sirve ficheros estáticos (`HTML`, `CSS`, `JS` y `JSON`).

### Aportación propia
- **Métricas por artículo con `LEFT JOIN` en SQL y `json_group_object`:** `Q_WORDS` exporta el mapa `by_url` y media de palabras (`AVG(n)`), permitiendo mostrar en cada artículo (`layouts/_default/single.html`) y en el listado de portada (`layouts/index.html`) el número exacto de palabras calculado en SQLite.
- **Objetivo `make stats`:** Permite consultar directamente `build/site.db` desde la terminal para listar todas las páginas ordenadas por número de palabras.
- **Contador visual de coincidencias en vivo:** `static/search.js` muestra cuántas coincidencias tiene cada resultado devuelto por el buscador.

## Límites a propósito (KISS)

`tools/index.py` entiende front matter YAML simple (`clave: valor` y `tags: [a, b]`); no TOML ni listas
multilínea. Para algo más serio, usa una biblioteca de YAML: aquí lo importante es el *flujo*.

## Entregable

Haz un **fork** (o clona y crea tu propio repo) de este proyecto, resuelve los `Ejercicios` que quieras
de los de arriba (no hace falta hacerlos todos) y haz **varios commits** a medida que avanzas.

La práctica se considera entregada en el momento en que **invitas al profesor** (usuario de GitHub
`fenix011`) **como colaborador** de tu repositorio. Sigue estos pasos de la documentación oficial de
GitHub en español:
[Invitar a colaboradores a un repositorio personal](https://docs.github.com/es/repositories/managing-your-repositorys-settings-and-features/repository-access-and-collaboration/inviting-collaborators-to-a-personal-repository).

No hace falta sFTP ni capturas: con la invitación aceptada, el profesor ya puede clonar tu repo y revisarlo.

---

# RUBRICA DE CALIFICACIÓN
## Criterios de contenido (10 puntos)

### Implementación técnica — 7 puntos

| **Criterio** | **Peso** | **Qué se valora** |
|:---|:---:|:---|
| **Entorno funcionando** | 1p | `make serve`, `make build` y `make check` corren sin errores sobre tu fork/copia |
| **Ejercicios resueltos** | 3p | Al menos 2 de los 5 `Ejercicios` propuestos, funcionando de verdad (no hace falta hacer los 5) |
| **Comprensión del flujo** | 2p | Se entiende cómo encajan `tools/index.py` → SQLite → JSON → Hugo en los cambios hechos (visible en el código o explicado en el README) |
| **Calidad del código añadido** | 1p | Estilo coherente con el proyecto (funciones puras donde aplica, nombres claros) |

### Más allá de lo técnico — 3 puntos

| **Criterio** | **Peso** | **Qué se valora** |
|:---|:---:|:---|
| **Aportación propia** | 1p | Algo más allá del mínimo pedido en los ejercicios elegidos |
| **Documentación del cambio** | 1p | El README (o un commit) explica qué se ha hecho y por qué |
| **Entregable completo y verificable** | 1p | Invitación a `fenix011` aceptada, repo clonable, commits reales |

## Convención en vivo vs. online, con matiz de `git log`

Esta práctica se entrega vía repositorio GitHub: 
- **10/10** — demo en vivo (en el aula) **y** `git log` con trabajo real incremental (varios commits, marcas de
  tiempo realmente separadas, mensajes no genéricos. Es decir, decriptivos de los cambios realizados!).
- **Intermedio (hasta 9/10)** — sin demo en vivo, pero con esa misma evidencia en el `git log`.
- **Tope 7/10** — sin demo en vivo y sin evidencia en el `git log` (un commit, mensajes genéricos o
  timestamps agrupados).

## Escala orientativa

- **Excelente (9-10):** varios ejercicios resueltos y funcionando, código claro, demo en vivo y/o
  `git log` con evidencia real.
- **Notable (7-8.9):** 2+ ejercicios resueltos y funcionando, algún detalle menor.
- **Suficiente (5-6.9):** el entorno corre pero los ejercicios resueltos son mínimos o tienen fallos.
- **Insuficiente (<5):** el entorno no llega a funcionar (`make build` falla) o no hay ningún ejercicio
  resuelto.

## Lista de comprobación rápida (para nosotros, el profesorado :-)

```bash
git clone https://github.com/<alumno>/<repo>.git && cd <repo>
make check && make build
git log --format='%h %ad %s' --date=iso | head -20
```

## Plantilla de feedback

```
## Feedback
- Qué ha ido bien: …
- A mejorar: …
- ¿Has pensado en usar `git` desde la terminal para hacer los cambios... a lo Pro? ;-)
```

"Recuerda ... KISS!" :-)
