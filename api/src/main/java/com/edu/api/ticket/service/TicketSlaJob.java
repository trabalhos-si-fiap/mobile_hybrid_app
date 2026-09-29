package com.edu.api.ticket.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.function.IntSupplier;

/** Escalona, reroteia e fecha tickets periodicamente. Desligado no perfil de teste. */
@Component
@ConditionalOnProperty(prefix = "app.tickets", name = "jobs-enabled", havingValue = "true", matchIfMissing = true)
public class TicketSlaJob {

    private static final Logger log = LoggerFactory.getLogger(TicketSlaJob.class);

    private final TicketMaintenanceService maintenance;

    public TicketSlaJob(TicketMaintenanceService maintenance) {
        this.maintenance = maintenance;
    }

    @Scheduled(fixedDelayString = "${app.tickets.sla-job-interval:60s}",
               initialDelayString = "${app.tickets.sla-job-interval:60s}")
    public void run() {
        step("escalonamento", maintenance::escalateOverdue);
        step("roteamento", maintenance::routeUnassigned);
        step("fechamento", maintenance::closeStaleResolved);
    }

    /** Uma etapa que falha não impede as outras. */
    private static void step(String name, IntSupplier action) {
        try {
            int affected = action.getAsInt();
            if (affected > 0) {
                log.info("Job de SLA: {} afetou {} ticket(s)", name, affected);
            }
        } catch (RuntimeException e) {
            log.error("Job de SLA: falha no {}", name, e);
        }
    }
}
