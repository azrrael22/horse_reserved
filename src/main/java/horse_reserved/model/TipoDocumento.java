package horse_reserved.model;

import lombok.Getter;

/**
 * Enum que representa los tipos de documento de identidad aceptados
 */
@Getter
public enum TipoDocumento {
    CEDULA("Cédula de Ciudadanía"),
    PASAPORTE("Pasaporte"),
    TARJETA_IDENTIDAD("Tarjeta de Identidad");

    private final String descripcion;

    TipoDocumento(String descripcion) {
        this.descripcion = descripcion;
    }

    /**
     * Convierte un string a TipoDocumento
     * Acepta tanto el nombre del enum como la descripción
     */
    public static TipoDocumento fromString(String valor) {
        if (valor == null) {
            return null;
        }

        String valorNormalizado = valor.toUpperCase().trim();

        for (TipoDocumento tipo : TipoDocumento.values()) {
            if (tipo.name().equals(valorNormalizado) ||
                    tipo.descripcion.equalsIgnoreCase(valor)) {
                return tipo;
            }
        }

        throw new IllegalArgumentException("Tipo de documento no válido: " + valor);
    }
}