-- Dato manual para demostrar persistencia; no forma parte de db/init.
-- Nombre y foto: https://www.fifa.com/es/tournaments/mens/worldcup/canadamexicousa2026/teams/spain/squad
INSERT INTO jugadores (nombre, posicion, imagen)
VALUES ('Luis de la Fuente Castillo', 'Entrenador', 'images/jugadores/luis-de-la-fuente.png')
ON CONFLICT (nombre) DO NOTHING;

SELECT id, nombre, posicion, imagen
FROM jugadores
WHERE nombre = 'Luis de la Fuente Castillo';
