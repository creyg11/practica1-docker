-- Eliminar únicamente el entrenador usado en la demostración.
DELETE FROM jugadores
WHERE nombre = 'Luis de la Fuente Castillo' AND posicion = 'Entrenador'
RETURNING id, nombre;
