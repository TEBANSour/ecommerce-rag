# Sistema híbrido relacional-vectorial para RAG — E-commerce

Proyecto final de **Bases de datos relacionales** · Universidad de Caldas · Ingeniería de Sistemas y Computación

Base de datos PostgreSQL con pgvector para una plataforma de comercio electrónico. Combina datos estructurados (catálogo, inventario, órdenes, pagos, reseñas) con búsqueda semántica sobre textos e imágenes, un pipeline RAG y evaluación con RAGAS.

**Integrantes:** Julián Santiago Parra Arias · Esteban Ortiz Murillo · Javier Alejandro Mosquera
**Docente:** Andrés Paolo Castaño

## Estado

- [x] Entrega 1: diseño y configuración (modelo conceptual, lógico en 3FN, esquema SQL, plan de chunking)
- [ ] Entrega 2: ingesta de datos, embeddings, consultas, pipeline RAG y evaluación

## Contenido del repositorio

| Archivo | Descripción |
|---|---|
| `schema.sql` | Esquema completo: 25 tablas relacionales y vectoriales, restricciones e índices HNSW. Se puede ejecutar varias veces. |
| `ERD_alta_resolucion.png` | Diagrama entidad-relación (notación Chen). |
| `E1_Relacionales.docx` | Documento de la Entrega 1. |

## Cómo ejecutarlo

Neon (PostgreSQL en línea)**

1. Crear un proyecto en [neon.com](https://neon.com) y copiar la cadena de conexión directa (no la del pooler).
2. Ejecutar `schema.sql` en el editor SQL de Neon.

## Seguridad

No se versionan contraseñas ni cadenas de conexión: se guardan en variables de entorno.
