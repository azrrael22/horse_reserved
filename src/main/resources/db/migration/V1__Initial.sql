CREATE TABLE `documento_identidad` (
                                       `id_documento_identidad` SERIAL NOT NULL,
                                       `documento` VARCHAR(255) NOT NULL,
                                       PRIMARY KEY (`id_documento_identidad`)
);

CREATE TABLE `tipo_documento` (
                                  `id_tipo_doc` SERIAL NOT NULL,
                                  `tipo` VARCHAR(255) NOT NULL,
                                  `documento_identidad` INTEGER NOT NULL,
                                  PRIMARY KEY (`id_tipo_doc`)
);

CREATE TABLE `usuario` (
                           `id_usuario` SERIAL NOT NULL,
                           `primer_nombre` VARCHAR(255) NOT NULL,
                           `segundo_nombre` VARCHAR(255),
                           `primer_apellido` VARCHAR(255) NOT NULL,
                           `segundo_apellido` VARCHAR(255),
                           `genero` CHARACTER(1) NOT NULL,
                           `contrasena` VARCHAR(255) NOT NULL,
                           `correo` VARCHAR(255) NOT NULL,
                           `fecha_nacimiento` DATE NOT NULL,
                           `tipo_documento` INTEGER NOT NULL,
                           PRIMARY KEY (`id_usuario`)
);


ALTER TABLE `tipo_documento` ADD CONSTRAINT `FK_40dd92f9-332e-4a0d-a873-f598f39e0d3c` FOREIGN KEY (`documento_identidad`) REFERENCES `documento_identidad`(`id_documento_identidad`)  ;

ALTER TABLE `usuario` ADD CONSTRAINT `FK_d9a4a780-d7c9-4703-a0fe-be481da286c4` FOREIGN KEY (`tipo_documento`) REFERENCES `tipo_documento`(`id_tipo_doc`)  ;
