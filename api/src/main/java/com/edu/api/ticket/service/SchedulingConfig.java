package com.edu.api.ticket.service;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

@Configuration
@EnableScheduling
@ConditionalOnProperty(prefix = "app.tickets", name = "jobs-enabled", havingValue = "true", matchIfMissing = true)
public class SchedulingConfig {
}
