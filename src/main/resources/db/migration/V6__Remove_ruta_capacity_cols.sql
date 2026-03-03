-- Eliminamos max_caballos y min_guias de rutas.
-- El cupo de una salida lo determinan los caballos disponibles asignados a ella.
-- El número de guías requeridos se calcula en tiempo real: ≤8 personas → 1 guía, >8 → 2 guías.

ALTER TABLE rutas DROP COLUMN max_caballos;
ALTER TABLE rutas DROP COLUMN min_guias;
