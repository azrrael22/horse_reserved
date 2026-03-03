package horse_reserved.security;

import horse_reserved.dto.response.AuthResponse;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class OAuth2TokenStore {

    private static final long TTL_MS = 5 * 60 * 1000L; // 5 minutos

    private record Entry(AuthResponse authResponse, Instant expiresAt) {}

    private final Map<String, Entry> store = new ConcurrentHashMap<>();

    /**
     * Almacena un AuthResponse y retorna un código de un solo uso (UUID).
     */
    public String store(AuthResponse authResponse) {
        String code = UUID.randomUUID().toString();
        store.put(code, new Entry(authResponse, Instant.now().plusMillis(TTL_MS)));
        return code;
    }

    /**
     * Intercambia el código por el AuthResponse. El código se elimina al consumirse.
     * Retorna vacío si el código no existe o ya expiró.
     */
    public Optional<AuthResponse> consume(String code) {
        Entry entry = store.remove(code);
        if (entry == null || Instant.now().isAfter(entry.expiresAt())) {
            return Optional.empty();
        }
        return Optional.of(entry.authResponse());
    }

    /**
     * Limpieza periódica de entradas expiradas (cada 60 segundos).
     */
    @Scheduled(fixedRate = 60_000)
    public void evictExpired() {
        Instant now = Instant.now();
        store.entrySet().removeIf(e -> now.isAfter(e.getValue().expiresAt()));
    }
}
