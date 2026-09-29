package com.edu.api.support;

import com.edu.api.security.JwtAuthenticationFilter;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.FilterType;
import org.springframework.core.annotation.AliasFor;
import org.springframework.test.context.ActiveProfiles;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Slice de teste de um controller: só a camada web (controller, advice,
 * conversores), sem JPA nem banco. Os services devem ser {@code @MockitoBean}.
 *
 * <p>O {@link JwtAuthenticationFilter} é excluído porque o {@code @WebMvcTest}
 * carrega todo bean do tipo {@code Filter}, e esse filtro puxaria o
 * {@code JwtService}. A segurança fica desligada no MockMvc; o wiring real
 * de segurança é coberto por {@code ApplicationContextIT}.
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@WebMvcTest(excludeFilters = @ComponentScan.Filter(
        type = FilterType.ASSIGNABLE_TYPE,
        classes = JwtAuthenticationFilter.class))
@AutoConfigureMockMvc(addFilters = false)
@ActiveProfiles("test")
public @interface ControllerSliceTest {

    /** Controllers a carregar no slice. */
    @AliasFor(annotation = WebMvcTest.class, attribute = "controllers")
    Class<?>[] value() default {};
}
