CREATE TABLE products (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    sku VARCHAR(60) NOT NULL UNIQUE,
    description VARCHAR(500),
    minimum_stock INTEGER NOT NULL CHECK (minimum_stock >= 0),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE inventories (
    id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL UNIQUE REFERENCES products(id),
    quantity INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE inventory_adjustments (
    id BIGSERIAL PRIMARY KEY,
    inventory_id BIGINT NOT NULL REFERENCES inventories(id),
    previous_quantity INTEGER NOT NULL CHECK (previous_quantity >= 0),
    new_quantity INTEGER NOT NULL CHECK (new_quantity >= 0),
    reason VARCHAR(300) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE carriers (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    location VARCHAR(150) NOT NULL,
    email VARCHAR(254) NOT NULL,
    average_delivery_days INTEGER NOT NULL CHECK (average_delivery_days > 0),
    rating NUMERIC(2,1) NOT NULL CHECK (rating >= 0 AND rating <= 5),
    sla_percentage NUMERIC(5,2) NOT NULL CHECK (sla_percentage >= 0 AND sla_percentage <= 100),
    status VARCHAR(20) NOT NULL CHECK (status IN ('ACTIVE', 'INACTIVE')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE carrier_occurrences (
    id BIGSERIAL PRIMARY KEY,
    carrier_id BIGINT NOT NULL REFERENCES carriers(id),
    type VARCHAR(30) NOT NULL CHECK (type IN ('DELIVERY_DELAY', 'DAMAGE', 'DELIVERY_FAILURE', 'OTHER')),
    description VARCHAR(500) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'RESOLVED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ
);

CREATE TABLE student_metrics (
    id BIGSERIAL PRIMARY KEY,
    registered_at TIMESTAMPTZ NOT NULL,
    last_study_activity_at TIMESTAMPTZ,
    diagnostic_completed BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_inventories_quantity ON inventories(quantity);
CREATE INDEX idx_carriers_status ON carriers(status);
CREATE INDEX idx_carrier_occurrences_status ON carrier_occurrences(status);
CREATE INDEX idx_student_metrics_activity ON student_metrics(last_study_activity_at);
