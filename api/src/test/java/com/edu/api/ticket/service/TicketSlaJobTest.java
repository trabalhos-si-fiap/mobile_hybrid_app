package com.edu.api.ticket.service;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TicketSlaJobTest {

    @Mock
    private TicketMaintenanceService maintenance;

    @InjectMocks
    private TicketSlaJob job;

    @Test
    void escalatesThenRoutesThenCloses() {
        job.run();

        InOrder order = inOrder(maintenance);
        order.verify(maintenance).escalateOverdue();
        order.verify(maintenance).routeUnassigned();
        order.verify(maintenance).closeStaleResolved();
    }

    @Test
    void keepsGoingWhenAStepFails() {
        when(maintenance.escalateOverdue()).thenThrow(new IllegalStateException("banco fora do ar"));

        job.run();

        verify(maintenance).routeUnassigned();
        verify(maintenance).closeStaleResolved();
    }
}
