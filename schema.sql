-- =====================================================================
-- schema.sql — Sistema híbrido relacional-vectorial para RAG (e-commerce)
-- PostgreSQL 16 + pgvector. Se ejecuta sin errores sobre una base vacía
-- y puede ejecutarse varias veces (IF NOT EXISTS).
-- Parte 1: tablas relacionales  |  Parte 2: tablas vectoriales y RAG
-- =====================================================================

CREATE TABLE IF NOT EXISTS proveedores (
    id_proveedor INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(120) NOT NULL,
    email        VARCHAR(150),
    telefono     VARCHAR(30)
);

CREATE TABLE IF NOT EXISTS marcas (
    id_marca       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre         VARCHAR(80) NOT NULL UNIQUE,
    pais_origen    VARCHAR(60),
    fundacion      SMALLINT CHECK (fundacion BETWEEN 1800 AND 2100)  -- año de fundación
);

CREATE TABLE IF NOT EXISTS almacenes (
    id_almacen INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre     VARCHAR(100) NOT NULL,
    ciudad     VARCHAR(80)  NOT NULL,
    direccion  VARCHAR(200)
);

-- Catálogo de especificaciones: la unidad pertenece a la especificación
-- (NULL para las que no se miden, como Color o Conectividad)
CREATE TABLE IF NOT EXISTS especificaciones (
    id_especificacion INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre            VARCHAR(80) NOT NULL UNIQUE,
    unidad            VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS categorias (
    id_categoria INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS usuarios (
    id_usuario     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre         VARCHAR(100) NOT NULL,
    email          VARCHAR(150) NOT NULL UNIQUE,
    fecha_registro TIMESTAMP    NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS direcciones (
    id_direccion  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    direccion     VARCHAR(200) NOT NULL,
    ciudad        VARCHAR(80)  NOT NULL,
    departamento  VARCHAR(80),
    pais          VARCHAR(60)  NOT NULL,
    codigo_postal VARCHAR(15)
);

-- Relación N:M usuario-dirección (reside_en). PK sustituta porque
-- ordenes la referencia como un todo (agregación en el ERD).
CREATE TABLE IF NOT EXISTS direccion_usuario (
    id_direccion_usuario INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_direccion         INT NOT NULL REFERENCES direcciones(id_direccion),
    id_usuario           INT NOT NULL REFERENCES usuarios(id_usuario),
    UNIQUE (id_direccion, id_usuario)
);

CREATE TABLE IF NOT EXISTS productos (
    id_producto    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre         VARCHAR(150) NOT NULL,
    descripcion    TEXT NOT NULL,
    idioma         CHAR(2) NOT NULL DEFAULT 'es',
    precio_venta   NUMERIC(12,2) NOT NULL CHECK (precio_venta >= 0),
    activo         BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion DATE NOT NULL DEFAULT CURRENT_DATE,
    id_marca       INT NOT NULL REFERENCES marcas(id_marca)
);

CREATE TABLE IF NOT EXISTS producto_categoria (
    id_producto  INT NOT NULL REFERENCES productos(id_producto) ON DELETE CASCADE,
    id_categoria INT NOT NULL REFERENCES categorias(id_categoria),
    PRIMARY KEY (id_producto, id_categoria)
);

CREATE TABLE IF NOT EXISTS producto_especificacion (
    id_producto       INT NOT NULL REFERENCES productos(id_producto) ON DELETE CASCADE,
    id_especificacion INT NOT NULL REFERENCES especificaciones(id_especificacion),
    valor             VARCHAR(200) NOT NULL,
    PRIMARY KEY (id_producto, id_especificacion)
);

CREATE TABLE IF NOT EXISTS imagenes (
    id_imagen   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_producto INT NOT NULL REFERENCES productos(id_producto) ON DELETE CASCADE,
    url_imagen  VARCHAR(300) NOT NULL,
    descripcion TEXT
);

-- Relación N:M usuario-producto (reseña). PK sustituta porque
-- embeddings_texto la referencia. Regla de negocio (trigger o
-- aplicación): solo reseña quien compró el producto.
CREATE TABLE IF NOT EXISTS resenas (
    id_resena    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario   INT NOT NULL REFERENCES usuarios(id_usuario),
    id_producto  INT NOT NULL REFERENCES productos(id_producto),
    calificacion SMALLINT NOT NULL CHECK (calificacion BETWEEN 1 AND 5),
    comentario   TEXT,
    fecha        TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (id_usuario, id_producto)
);

CREATE TABLE IF NOT EXISTS inventario (
    id_almacen  INT NOT NULL REFERENCES almacenes(id_almacen),
    id_producto INT NOT NULL REFERENCES productos(id_producto),
    stock       INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    PRIMARY KEY (id_almacen, id_producto)
);

CREATE TABLE IF NOT EXISTS proveedor_producto (
    id_proveedor      INT NOT NULL REFERENCES proveedores(id_proveedor),
    id_producto       INT NOT NULL REFERENCES productos(id_producto),
    costo_adquisicion NUMERIC(12,2) NOT NULL CHECK (costo_adquisicion >= 0),
    PRIMARY KEY (id_proveedor, id_producto)
);

-- La orden referencia el par usuario-dirección; ON DELETE RESTRICT
-- conserva el historial de pedidos. total_orden es un valor histórico:
-- Σ(cantidad × precio_unitario) + costo_envio, fijado al crear la orden.
CREATE TABLE IF NOT EXISTS ordenes (
    id_orden             INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_direccion_usuario INT NOT NULL
                         REFERENCES direccion_usuario(id_direccion_usuario) ON DELETE RESTRICT,
    fecha                TIMESTAMP NOT NULL DEFAULT now(),
    estado               VARCHAR(20) NOT NULL DEFAULT 'pendiente'
                         CHECK (estado IN ('pendiente','pagada','enviada','entregada','cancelada')),
    costo_envio          NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (costo_envio >= 0),
    total_orden          NUMERIC(12,2) NOT NULL CHECK (total_orden >= 0)
);

CREATE TABLE IF NOT EXISTS items_orden (
    id_orden        INT NOT NULL REFERENCES ordenes(id_orden) ON DELETE CASCADE,
    id_producto     INT NOT NULL REFERENCES productos(id_producto),
    cantidad        INT NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12,2) NOT NULL CHECK (precio_unitario >= 0), -- precio histórico
    PRIMARY KEY (id_orden, id_producto)
);

CREATE TABLE IF NOT EXISTS pagos (
    id_pago  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_orden INT NOT NULL REFERENCES ordenes(id_orden),
    metodo   VARCHAR(30) NOT NULL
             CHECK (metodo IN ('tarjeta','pse','transferencia','contraentrega')),
    estado   VARCHAR(20) NOT NULL
             CHECK (estado IN ('pendiente','aprobado','rechazado','reembolsado')),
    monto    NUMERIC(12,2) NOT NULL CHECK (monto >= 0),
    fecha    TIMESTAMP NOT NULL DEFAULT now()
);

-- Cada pregunta se ejecuta una vez por estrategia de chunking (tabla consultas)
CREATE TABLE IF NOT EXISTS preguntas (
    id_pregunta    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    texto_pregunta TEXT NOT NULL UNIQUE,
    ground_truth   TEXT                      -- respuesta esperada (dataset RAGAS)
);

CREATE TABLE IF NOT EXISTS consultas (
    id_consulta         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pregunta         INT NOT NULL REFERENCES preguntas(id_pregunta),
    id_usuario          INT NOT NULL REFERENCES usuarios(id_usuario),
    fecha               TIMESTAMP NOT NULL DEFAULT now(),
    estrategia_chunking VARCHAR(20) NOT NULL
                        CHECK (estrategia_chunking IN ('fixed-size','sentence-aware','semantic')),
    respuesta_generada  TEXT,
    modelo_llm          VARCHAR(80)
);

-- Índices sobre claves foráneas y filtros de las consultas híbridas
CREATE INDEX IF NOT EXISTS idx_productos_marca        ON productos (id_marca);
CREATE INDEX IF NOT EXISTS idx_productos_fecha_idioma ON productos (fecha_creacion, idioma);
CREATE INDEX IF NOT EXISTS idx_prod_categoria_cat     ON producto_categoria (id_categoria);
CREATE INDEX IF NOT EXISTS idx_prod_espec_espec       ON producto_especificacion (id_especificacion);
CREATE INDEX IF NOT EXISTS idx_inventario_producto    ON inventario (id_producto);
CREATE INDEX IF NOT EXISTS idx_prov_prod_producto     ON proveedor_producto (id_producto);
CREATE INDEX IF NOT EXISTS idx_dir_usuario_usuario    ON direccion_usuario (id_usuario);
CREATE INDEX IF NOT EXISTS idx_ordenes_dir_usuario    ON ordenes (id_direccion_usuario);
CREATE INDEX IF NOT EXISTS idx_items_orden_producto   ON items_orden (id_producto);
CREATE INDEX IF NOT EXISTS idx_pagos_orden            ON pagos (id_orden);
CREATE INDEX IF NOT EXISTS idx_resenas_producto       ON resenas (id_producto);
CREATE INDEX IF NOT EXISTS idx_imagenes_producto      ON imagenes (id_producto);
CREATE INDEX IF NOT EXISTS idx_consultas_pregunta     ON consultas (id_pregunta);

-- Usuario y dirección de cada orden, obtenidos a través de direccion_usuario
CREATE OR REPLACE VIEW v_ordenes_usuario AS
SELECT o.id_orden, du.id_usuario, du.id_direccion, o.fecha, o.estado, o.total_orden
FROM ordenes o JOIN direccion_usuario du ON du.id_direccion_usuario = o.id_direccion_usuario;

CREATE EXTENSION IF NOT EXISTS vector;

-- Chunks de texto: descripción de producto o reseña (exactamente una fuente)
CREATE TABLE IF NOT EXISTS embeddings_texto (
    id_embedding        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_producto         INT REFERENCES productos(id_producto) ON DELETE CASCADE,
    id_resena           INT REFERENCES resenas(id_resena) ON DELETE CASCADE,
    chunk_id            INT NOT NULL,
    estrategia_chunking VARCHAR(20) NOT NULL
                        CHECK (estrategia_chunking IN ('fixed-size','sentence-aware','semantic')),
    texto_chunk         TEXT NOT NULL,
    vector_embedding    VECTOR(384) NOT NULL,
    modelo              VARCHAR(80) NOT NULL DEFAULT 'all-MiniLM-L6-v2',
    CHECK (num_nonnulls(id_producto, id_resena) = 1)
);

CREATE TABLE IF NOT EXISTS embeddings_imagen (
    id_embedding     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_imagen        INT NOT NULL UNIQUE REFERENCES imagenes(id_imagen) ON DELETE CASCADE,
    vector_embedding VECTOR(512) NOT NULL,
    modelo           VARCHAR(80) NOT NULL DEFAULT 'clip-ViT-B-32'
);

-- Embedding de la pregunta (una vez por pregunta, no por ejecución)
CREATE TABLE IF NOT EXISTS query_embeddings (
    id_qemb          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pregunta      INT NOT NULL UNIQUE REFERENCES preguntas(id_pregunta) ON DELETE CASCADE,
    vector_embedding VECTOR(384) NOT NULL,   -- MiniLM: búsqueda texto-texto
    vector_clip      VECTOR(512),            -- CLIP texto: búsqueda texto->imagen
    modelo           VARCHAR(80) NOT NULL DEFAULT 'all-MiniLM-L6-v2'
);

-- Cada resultado es un chunk de texto o una imagen (exactamente uno)
CREATE TABLE IF NOT EXISTS resultados (
    id_resultado        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_consulta         INT NOT NULL REFERENCES consultas(id_consulta) ON DELETE CASCADE,
    id_embedding_texto  INT REFERENCES embeddings_texto(id_embedding),
    id_embedding_imagen INT REFERENCES embeddings_imagen(id_embedding),
    score_similitud     DOUBLE PRECISION NOT NULL,
    CHECK (num_nonnulls(id_embedding_texto, id_embedding_imagen) = 1)
);

-- Una evaluación RAGAS por consulta (ejecución)
CREATE TABLE IF NOT EXISTS evaluaciones (
    id_eval            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_consulta        INT NOT NULL UNIQUE REFERENCES consultas(id_consulta) ON DELETE CASCADE,
    faithfulness       FLOAT CHECK (faithfulness       BETWEEN 0 AND 1),
    answer_relevancy   FLOAT CHECK (answer_relevancy   BETWEEN 0 AND 1),
    context_recall     FLOAT CHECK (context_recall     BETWEEN 0 AND 1),
    context_precision  FLOAT CHECK (context_precision  BETWEEN 0 AND 1),  -- opcional
    answer_correctness FLOAT CHECK (answer_correctness BETWEEN 0 AND 1),  -- opcional
    modelo_eval        VARCHAR(80) NOT NULL,
    fecha              TIMESTAMP NOT NULL DEFAULT now()
);

-- Índices vectoriales (distancia coseno) y de apoyo
CREATE INDEX IF NOT EXISTS idx_emb_texto_hnsw  ON embeddings_texto
    USING hnsw (vector_embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS idx_emb_imagen_hnsw ON embeddings_imagen
    USING hnsw (vector_embedding vector_cosine_ops);
-- Un chunk por (fuente, estrategia, chunk_id): equivale al UNIQUE de la plantilla
CREATE UNIQUE INDEX IF NOT EXISTS uq_emb_texto_producto
    ON embeddings_texto (id_producto, estrategia_chunking, chunk_id) WHERE id_producto IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_emb_texto_resena
    ON embeddings_texto (id_resena, estrategia_chunking, chunk_id) WHERE id_resena IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_emb_texto_estrategia ON embeddings_texto (estrategia_chunking);
CREATE INDEX IF NOT EXISTS idx_emb_texto_producto   ON embeddings_texto (id_producto);
CREATE INDEX IF NOT EXISTS idx_emb_texto_resena     ON embeddings_texto (id_resena);
CREATE INDEX IF NOT EXISTS idx_resultados_consulta  ON resultados (id_consulta);
