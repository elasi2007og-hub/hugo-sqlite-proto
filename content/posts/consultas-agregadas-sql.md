---
title: "Consultas SQL para generar JSON estático"
date: 2026-11-09
description: "Cómo usar json_group_array, json_object y GROUP BY en SQLite durante el build."
tags: [sql, sqlite, build]
---
La extensión **JSON1** viene integrada por defecto en `sqlite3` y permite que
una consulta `SELECT` devuelva directamente el documento JSON que consumirá
Hugo o el navegador.

Por ejemplo, para contar cuántos artículos usan cada etiqueta y exportarlos a
`data/tags.json`:

```sql
SELECT json_group_array(json_object('tag', tag, 'total', total))
FROM (
  SELECT tag, COUNT(*) AS total
  FROM tags
  GROUP BY tag
  ORDER BY total DESC, tag
);
```

De este modo:

1. `tools/index.py` mantiene el código Python mínimo y declarativo.
2. Toda la lógica de agregación (`GROUP BY`, `COUNT`, `SUM`, `ORDER BY`) recae en el motor relacional de **SQLite**.
3. Al añadir este post con la etiqueta `sql`, `data/tags.json` se actualiza automáticamente en `make build` o `make serve` y la portada refleja el nuevo conteo.
