package horse_reserved.repository;

import horse_reserved.model.Guia;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

@Repository
public interface GuiaRepository extends JpaRepository<Guia, Long> {

    @Query("""
            SELECT g FROM Guia g
            WHERE g.activo = true
              AND g NOT IN (
                  SELECT gui FROM Salida s JOIN s.guias gui
                  WHERE s.fechaProgramada = :fecha
                    AND s.tiempoInicio    < :horaFin
                    AND s.tiempoFin       > :horaInicio
                    AND s.estado NOT IN ('cancelado', 'completado')
              )
            """)
    List<Guia> findDisponibles(@Param("fecha") LocalDate fecha,
                               @Param("horaInicio") LocalTime horaInicio,
                               @Param("horaFin") LocalTime horaFin);
}
