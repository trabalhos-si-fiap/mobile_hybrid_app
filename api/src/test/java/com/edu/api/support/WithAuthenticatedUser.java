package com.edu.api.support;

import org.springframework.security.test.context.support.WithSecurityContext;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Coloca um {@code AuthenticatedUser} no SecurityContext do teste. Os slices
 * rodam sem filtros, então é assim que o {@code @AuthenticationPrincipal}
 * dos controllers recebe o usuário.
 */
@Target({ElementType.TYPE, ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
@WithSecurityContext(factory = WithAuthenticatedUserFactory.class)
public @interface WithAuthenticatedUser {

    long id() default 1L;

    String email() default "usuario@edu.com";

    String role() default "USER";
}
