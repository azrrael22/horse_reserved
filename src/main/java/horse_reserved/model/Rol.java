package horse_reserved.model;

/**
 * enum para los roles de los usuarios
 */
public enum Rol {
    CLIENTE,OPERADOR,ADMINISTRADOR;

    /**
     * metodo que permite usar los roles para verificaciones con Spring security sin
     * conflictos de formato
     * @return el nombre del rol junto con el prefijo esperado por Spring security
     */
    public String getAuthority() {
        return "ROLE_" + name();
    }
}
