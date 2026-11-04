-- mz_jobs Wave 1 baseline.
-- Manual staging application only. The resource never executes this file.

CREATE TABLE IF NOT EXISTS mz_jobs_offers (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  schema_version SMALLINT UNSIGNED NOT NULL,
  template_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  category VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  kind VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  legality VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  status VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  definition_json JSON NOT NULL,
  compensation_mode VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'none',
  budget_hold_ref VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NULL,
  reserved_by_citizenid VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
  reservation_operation_key VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NULL,
  reserved_until DATETIME(3) NULL,
  accept_until DATETIME(3) NOT NULL,
  expires_at DATETIME(3) NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_mz_jobs_offer_public (public_id),
  UNIQUE KEY uq_mz_jobs_offer_reservation (reservation_operation_key),
  KEY ix_mz_jobs_offer_market (status, category, accept_until),
  KEY ix_mz_jobs_offer_reservation_expiry (status, reserved_until),
  KEY ix_mz_jobs_offer_expiry (status, expires_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS mz_jobs_executions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  offer_id BIGINT UNSIGNED NOT NULL,
  citizenid VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  accepted_session_id VARCHAR(96) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  status VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  stage_code VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  requires_custody TINYINT(1) NOT NULL DEFAULT 0,
  requires_settlement TINYINT(1) NOT NULL DEFAULT 0,
  snapshot_json JSON NOT NULL,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  accepted_at DATETIME(3) NOT NULL,
  expires_at DATETIME(3) NOT NULL,
  completed_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_mz_jobs_execution_public (public_id),
  UNIQUE KEY uq_mz_jobs_execution_offer (offer_id),
  KEY ix_mz_jobs_execution_actor (citizenid, status, updated_at),
  KEY ix_mz_jobs_execution_reconcile (status, updated_at),
  CONSTRAINT fk_mz_jobs_execution_offer FOREIGN KEY (offer_id)
    REFERENCES mz_jobs_offers (id) ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS mz_jobs_operations (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  source_resource VARCHAR(100) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  actor_citizenid VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  operation_key VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  operation_type VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  request_fingerprint VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  aggregate_type VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  aggregate_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  status VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  result_json JSON NULL,
  error_code VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_mz_jobs_operation_scope (source_resource, actor_citizenid, operation_key),
  KEY ix_mz_jobs_operation_recovery (status, operation_type, updated_at),
  KEY ix_mz_jobs_operation_aggregate (aggregate_type, aggregate_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS mz_jobs_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  aggregate_type VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  aggregate_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  sequence_no INT UNSIGNED NOT NULL,
  event_type VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  actor_citizenid VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
  operation_key VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NULL,
  payload_json JSON NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_mz_jobs_event_sequence (aggregate_type, aggregate_id, sequence_no),
  UNIQUE KEY uq_mz_jobs_event_operation (operation_key),
  KEY ix_mz_jobs_event_created (created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS mz_jobs_outbox (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  topic VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  dedupe_key VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  aggregate_type VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  aggregate_id VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  payload_json JSON NOT NULL,
  status VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'pending',
  attempts INT UNSIGNED NOT NULL DEFAULT 0,
  next_attempt_at DATETIME(3) NULL,
  lease_until DATETIME(3) NULL,
  processed_at DATETIME(3) NULL,
  last_error VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_mz_jobs_outbox_dedupe (topic, dedupe_key),
  KEY ix_mz_jobs_outbox_retry (status, next_attempt_at, lease_until)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS mz_jobs_reputation (
  citizenid VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  track_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  xp BIGINT UNSIGNED NOT NULL DEFAULT 0,
  level INT UNSIGNED NOT NULL DEFAULT 0,
  version INT UNSIGNED NOT NULL DEFAULT 1,
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (citizenid, track_id)
) ENGINE=InnoDB;
