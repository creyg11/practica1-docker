BEGIN;

CREATE TABLE IF NOT EXISTS jugadores (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    posicion VARCHAR(30) NOT NULL,
    imagen TEXT
);

-- Datos de ejemplo para la práctica, no una convocatoria actualizada.
-- La imagen queda vacía hasta que añadamos las fotos al proyecto.
INSERT INTO jugadores (nombre, posicion)
VALUES
    ('Unai Simón', 'Portero'),
    ('Dani Carvajal', 'Defensa'),
    ('Rodri', 'Centrocampista'),
    ('Lamine Yamal', 'Delantero')
ON CONFLICT (nombre) DO NOTHING;

COMMIT;
