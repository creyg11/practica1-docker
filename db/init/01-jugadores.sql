BEGIN;

CREATE TABLE IF NOT EXISTS jugadores (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    posicion VARCHAR(30) NOT NULL,
    imagen TEXT
);

-- Plantilla de España para el Mundial 2026.
-- Fuente: FIFA · https://www.fifa.com/es/tournaments/mens/worldcup/canadamexicousa2026/teams/spain/squad
-- Fotografías servidas desde app/static/images/jugadores/.
INSERT INTO jugadores (nombre, posicion, imagen) VALUES
    ('David Raya',        'Portero',         'images/jugadores/david-raya.avif'),
    ('Joan García',       'Portero',         'images/jugadores/joan-garcia.avif'),
    ('Unai Simón',        'Portero',         'images/jugadores/unai-simon.avif'),
    ('Marc Pubill',       'Defensa',         'images/jugadores/marc-pubill.avif'),
    ('Álex Grimaldo',     'Defensa',         'images/jugadores/alex-grimaldo.avif'),
    ('Eric García',       'Defensa',         'images/jugadores/eric-garcia.avif'),
    ('Marcos Llorente',   'Defensa',         'images/jugadores/marcos-llorente.avif'),
    ('Pedro Porro',       'Defensa',         'images/jugadores/pedro-porro.avif'),
    ('Aymeric Laporte',   'Defensa',         'images/jugadores/aymeric-laporte.avif'),
    ('Pau Cubarsí',       'Defensa',         'images/jugadores/pau-cubarsi.avif'),
    ('Marc Cucurella',    'Defensa',         'images/jugadores/marc-cucurella.avif'),
    ('Mikel Merino',      'Centrocampista',  'images/jugadores/mikel-merino.avif'),
    ('Fabián Ruiz',       'Centrocampista',  'images/jugadores/fabian-ruiz.avif'),
    ('Gavi',              'Centrocampista',  'images/jugadores/gavi.avif'),
    ('Álex Baena',        'Centrocampista',  'images/jugadores/alex-baena.avif'),
    ('Rodri',             'Centrocampista',  'images/jugadores/rodri.avif'),
    ('Martín Zubimendi',  'Centrocampista',  'images/jugadores/martin-zubimendi.avif'),
    ('Pedri',             'Centrocampista',  'images/jugadores/pedri.avif'),
    ('Ferran Torres',     'Delantero',       'images/jugadores/ferran-torres.avif'),
    ('Dani Olmo',         'Delantero',       'images/jugadores/dani-olmo.avif'),
    ('Yeremy Pino',       'Delantero',       'images/jugadores/yeremy-pino.avif'),
    ('Nico Williams',     'Delantero',       'images/jugadores/nico-williams.avif'),
    ('Lamine Yamal',      'Delantero',       'images/jugadores/lamine-yamal.avif'),
    ('Mikel Oyarzabal',   'Delantero',       'images/jugadores/mikel-oyarzabal.avif'),
    ('Víctor Muñoz',      'Delantero',       'images/jugadores/victor-munoz.avif'),
    ('Borja Iglesias',    'Delantero',       'images/jugadores/borja-iglesias.avif')
-- Si ya existe el nombre, conservamos la fila y sus posibles cambios manuales.
ON CONFLICT (nombre) DO NOTHING;

COMMIT;
