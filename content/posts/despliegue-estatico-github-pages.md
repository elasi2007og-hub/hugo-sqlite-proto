---
title: "Despliegue en GitHub Pages y VPS: cero procesos propios en producción"
date: 2026-11-09
description: "Por qué desplegar public/ con GitHub Pages o rsync reduce la superficie de ataque y el consumo a cero."
tags: [sql, static, unix]
---
Cuando ejecutamos `make build`, ocurre toda la magia en nuestra máquina local (o en el entorno de integración continua):

1. `tools/index.py` procesa `content/**/*.md` y construye `build/site.db`.
2. Las consultas **SQL** generan `static/search.json`, `data/tags.json` y `data/words.json`.
3. `hugo --gc --minify` ensambla las plantillas y copia los recursos estáticos dentro de `public/`.

Al desplegar `public/` mediante **GitHub Pages** o con `rsync -avz --delete public/ usuario@vps:/var/www/html/`, ¿qué proceso de los nuestros queda corriendo en el servidor de producción?

**Ninguno.** No hay intérprete de Python, ni motor SQLite abierto, ni binario de Hugo en ejecución. El servidor web únicamente envía bytes estáticos (`HTML`, `CSS`, `JS` y `JSON`) directamente desde el sistema de ficheros.
