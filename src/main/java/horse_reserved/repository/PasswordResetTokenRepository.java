package horse_reserved.repository;

import horse_reserved.model.PasswordResetToken;
import horse_reserved.model.Usuario;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface PasswordResetTokenRepository extends JpaRepository<PasswordResetToken, Long> {

    /**
     * Busca un token de restablecimiento por su valor UUID
     *
     * @param token El UUID del token
     * @return Optional con el token si existe
     */
    Optional<PasswordResetToken> findByToken(String token);

    /**
     * Invalida todos los tokens no utilizados de un usuario.
     * Se llama antes de crear un nuevo token para evitar tokens huérfanos.
     *
     * @param usuario El usuario dueño de los tokens
     */
    @Modifying
    @Query("UPDATE PasswordResetToken t SET t.used = true WHERE t.usuario = :usuario AND t.used = false")
    void invalidatePreviousTokens(Usuario usuario);
}
