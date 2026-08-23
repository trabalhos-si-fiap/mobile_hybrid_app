package com.edu.api.auth;

import com.edu.api.auth.controller.AuthController;

/**
 * WebMvcTest
 */
public @interface WebMvcTest {

    Class<AuthController> value();

}
