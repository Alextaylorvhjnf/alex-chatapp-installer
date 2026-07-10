--
-- PostgreSQL database dump
--

\restrict 19JJZLIzXbqtx6O47hXZE0Hm5fSH3yrcVZKuI6eTyj9jWvAcm3WAglsBRbggtup

-- Dumped from database version 16.14 (Debian 16.14-1.pgdg13+1)
-- Dumped by pg_dump version 16.14 (Debian 16.14-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: check_event_stream_ordering(); Type: FUNCTION; Schema: public; Owner: synapse
--

CREATE FUNCTION public.check_event_stream_ordering() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                IF EXISTS (
                    SELECT 1 FROM events
                    WHERE events.event_id = NEW.event_id
                       AND events.stream_ordering != NEW.event_stream_ordering
                ) THEN
                    RAISE EXCEPTION 'Incorrect event_stream_ordering';
                END IF;
                RETURN NEW;
            END;
            $$;


ALTER FUNCTION public.check_event_stream_ordering() OWNER TO synapse;

--
-- Name: check_partial_state_events(); Type: FUNCTION; Schema: public; Owner: synapse
--

CREATE FUNCTION public.check_partial_state_events() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                IF EXISTS (
                    SELECT 1 FROM events
                    WHERE events.event_id = NEW.event_id
                       AND events.room_id != NEW.room_id
                ) THEN
                    RAISE EXCEPTION 'Incorrect room_id in partial_state_events';
                END IF;
                RETURN NEW;
            END;
            $$;


ALTER FUNCTION public.check_partial_state_events() OWNER TO synapse;

--
-- Name: delete_read_write_lock_parent(); Type: FUNCTION; Schema: public; Owner: synapse
--

CREATE FUNCTION public.delete_read_write_lock_parent() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_token TEXT;
    mode_row_token TEXT;
BEGIN
    -- Only update the token in `_mode` if its our token. This prevents
    -- deadlocks.
    --
    -- We shove the token into `mode_row_token`, as otherwise postgres complains
    -- we're not using the returned data.
    SELECT token INTO mode_row_token FROM worker_read_write_locks_mode
        WHERE
            lock_name = OLD.lock_name
            AND lock_key = OLD.lock_key
            AND token = OLD.token
        FOR UPDATE;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    SELECT token INTO new_token FROM worker_read_write_locks
        WHERE
            lock_name = OLD.lock_name
            AND lock_key = OLD.lock_key
        LIMIT 1 FOR UPDATE SKIP LOCKED;

    IF NOT FOUND THEN
        DELETE FROM worker_read_write_locks_mode
            WHERE lock_name = OLD.lock_name AND lock_key = OLD.lock_key AND token = OLD.token;
    ELSE
        UPDATE worker_read_write_locks_mode
            SET token = new_token
            WHERE lock_name = OLD.lock_name AND lock_key = OLD.lock_key;
    END IF;

    RETURN NEW;
END
$$;


ALTER FUNCTION public.delete_read_write_lock_parent() OWNER TO synapse;

--
-- Name: upsert_read_write_lock_parent(); Type: FUNCTION; Schema: public; Owner: synapse
--

CREATE FUNCTION public.upsert_read_write_lock_parent() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO worker_read_write_locks_mode (lock_name, lock_key, write_lock, token)
        VALUES (NEW.lock_name, NEW.lock_key, NEW.write_lock, NEW.token)
        ON CONFLICT (lock_name, lock_key)
        DO UPDATE SET write_lock = NEW.write_lock
            WHERE OLD.write_lock != NEW.write_lock;
    RETURN NEW;
END
$$;


ALTER FUNCTION public.upsert_read_write_lock_parent() OWNER TO synapse;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: access_tokens; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.access_tokens (
    id bigint NOT NULL,
    user_id text NOT NULL,
    device_id text,
    token text NOT NULL,
    valid_until_ms bigint,
    puppets_user_id text,
    last_validated bigint,
    refresh_token_id bigint,
    used boolean
);


ALTER TABLE public.access_tokens OWNER TO synapse;

--
-- Name: account_data; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.account_data (
    user_id text NOT NULL,
    account_data_type text NOT NULL,
    stream_id bigint NOT NULL,
    content text NOT NULL,
    instance_name text
);


ALTER TABLE public.account_data OWNER TO synapse;

--
-- Name: account_data_sequence; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.account_data_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.account_data_sequence OWNER TO synapse;

--
-- Name: account_validity; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.account_validity (
    user_id text NOT NULL,
    expiration_ts_ms bigint NOT NULL,
    email_sent boolean NOT NULL,
    renewal_token text,
    token_used_ts_ms bigint
);


ALTER TABLE public.account_validity OWNER TO synapse;

--
-- Name: application_services_state; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.application_services_state (
    as_id text NOT NULL,
    state character varying(5),
    read_receipt_stream_id bigint,
    presence_stream_id bigint,
    to_device_stream_id bigint,
    device_list_stream_id bigint
);


ALTER TABLE public.application_services_state OWNER TO synapse;

--
-- Name: application_services_txn_id_seq; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.application_services_txn_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.application_services_txn_id_seq OWNER TO synapse;

--
-- Name: application_services_txns; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.application_services_txns (
    as_id text NOT NULL,
    txn_id bigint NOT NULL,
    event_ids text NOT NULL
);


ALTER TABLE public.application_services_txns OWNER TO synapse;

--
-- Name: applied_module_schemas; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.applied_module_schemas (
    module_name text NOT NULL,
    file text NOT NULL
);


ALTER TABLE public.applied_module_schemas OWNER TO synapse;

--
-- Name: applied_schema_deltas; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.applied_schema_deltas (
    version integer NOT NULL,
    file text NOT NULL
);


ALTER TABLE public.applied_schema_deltas OWNER TO synapse;

--
-- Name: appservice_room_list; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.appservice_room_list (
    appservice_id text NOT NULL,
    network_id text NOT NULL,
    room_id text NOT NULL
);


ALTER TABLE public.appservice_room_list OWNER TO synapse;

--
-- Name: appservice_stream_position; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.appservice_stream_position (
    lock character(1) DEFAULT 'X'::bpchar NOT NULL,
    stream_ordering bigint,
    CONSTRAINT appservice_stream_position_lock_check CHECK ((lock = 'X'::bpchar))
);


ALTER TABLE public.appservice_stream_position OWNER TO synapse;

--
-- Name: background_updates; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.background_updates (
    update_name text NOT NULL,
    progress_json text NOT NULL,
    depends_on text,
    ordering integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.background_updates OWNER TO synapse;

--
-- Name: blocked_rooms; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.blocked_rooms (
    room_id text NOT NULL,
    user_id text NOT NULL
);


ALTER TABLE public.blocked_rooms OWNER TO synapse;

--
-- Name: cache_invalidation_stream_by_instance; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.cache_invalidation_stream_by_instance (
    stream_id bigint NOT NULL,
    instance_name text NOT NULL,
    cache_func text NOT NULL,
    keys text[],
    invalidation_ts bigint
);


ALTER TABLE public.cache_invalidation_stream_by_instance OWNER TO synapse;

--
-- Name: cache_invalidation_stream_seq; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.cache_invalidation_stream_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cache_invalidation_stream_seq OWNER TO synapse;

--
-- Name: current_state_delta_stream; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.current_state_delta_stream (
    stream_id bigint NOT NULL,
    room_id text NOT NULL,
    type text NOT NULL,
    state_key text NOT NULL,
    event_id text,
    prev_event_id text,
    instance_name text
);


ALTER TABLE public.current_state_delta_stream OWNER TO synapse;

--
-- Name: current_state_events; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.current_state_events (
    event_id text NOT NULL,
    room_id text NOT NULL,
    type text NOT NULL,
    state_key text NOT NULL,
    membership text,
    event_stream_ordering bigint
);


ALTER TABLE public.current_state_events OWNER TO synapse;

--
-- Name: dehydrated_devices; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.dehydrated_devices (
    user_id text NOT NULL,
    device_id text NOT NULL,
    device_data text NOT NULL
);


ALTER TABLE public.dehydrated_devices OWNER TO synapse;

--
-- Name: delayed_events; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.delayed_events (
    delay_id text NOT NULL,
    user_localpart text NOT NULL,
    device_id text,
    delay bigint NOT NULL,
    send_ts bigint NOT NULL,
    room_id text NOT NULL,
    event_type text NOT NULL,
    state_key text,
    origin_server_ts bigint,
    content text NOT NULL,
    is_processed boolean DEFAULT false NOT NULL,
    sticky_duration_ms bigint
);


ALTER TABLE public.delayed_events OWNER TO synapse;

--
-- Name: delayed_events_stream_pos; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.delayed_events_stream_pos (
    lock character(1) DEFAULT 'X'::bpchar NOT NULL,
    stream_id bigint NOT NULL,
    CONSTRAINT delayed_events_stream_pos_lock_check CHECK ((lock = 'X'::bpchar))
);


ALTER TABLE public.delayed_events_stream_pos OWNER TO synapse;

--
-- Name: deleted_pushers; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.deleted_pushers (
    stream_id bigint NOT NULL,
    app_id text NOT NULL,
    pushkey text NOT NULL,
    user_id text NOT NULL,
    instance_name text
);


ALTER TABLE public.deleted_pushers OWNER TO synapse;

--
-- Name: destination_rooms; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.destination_rooms (
    destination text NOT NULL,
    room_id text NOT NULL,
    stream_ordering bigint NOT NULL
);


ALTER TABLE public.destination_rooms OWNER TO synapse;

--
-- Name: TABLE destination_rooms; Type: COMMENT; Schema: public; Owner: synapse
--

COMMENT ON TABLE public.destination_rooms IS 'Information about transmission of PDUs in a given room to a given remote homeserver.';


--
-- Name: COLUMN destination_rooms.destination; Type: COMMENT; Schema: public; Owner: synapse
--

COMMENT ON COLUMN public.destination_rooms.destination IS 'server name of remote homeserver in question';


--
-- Name: COLUMN destination_rooms.room_id; Type: COMMENT; Schema: public; Owner: synapse
--

COMMENT ON COLUMN public.destination_rooms.room_id IS 'room ID in question';


--
-- Name: COLUMN destination_rooms.stream_ordering; Type: COMMENT; Schema: public; Owner: synapse
--

COMMENT ON COLUMN public.destination_rooms.stream_ordering IS '`stream_ordering` of the most recent PDU in this room that needs to be sent (by us) to this homeserver.
This can only be pointing to our own PDU because we are only responsible for sending our own PDUs.';


--
-- Name: destinations; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.destinations (
    destination text NOT NULL,
    retry_last_ts bigint,
    retry_interval bigint,
    failure_ts bigint,
    last_successful_stream_ordering bigint
);


ALTER TABLE public.destinations OWNER TO synapse;

--
-- Name: TABLE destinations; Type: COMMENT; Schema: public; Owner: synapse
--

COMMENT ON TABLE public.destinations IS 'Information about remote homeservers and the health of our connection to them.';


--
-- Name: COLUMN destinations.destination; Type: COMMENT; Schema: public; Owner: synapse
--

COMMENT ON COLUMN public.destinations.destination IS 'server name of remote homeserver in question';


--
-- Name: COLUMN destinations.retry_last_ts; Type: COMMENT; Schema: public; Owner: synapse
--

COMMENT ON COLUMN public.destinations.retry_last_ts IS 'The last time we tried and failed to reach the remote server, in ms.
This field is reset to `0` when we succeed in connecting again.';


--
-- Name: COLUMN destinations.retry_interval; Type: COMMENT; Schema: public; Owner: synapse
--

COMMENT ON COLUMN public.destinations.retry_interval IS 'How long, in milliseconds, to wait since the last time we tried to reach the remote server before trying again.
This field is reset to `0` when we succeed in connecting again.';


--
-- Name: COLUMN destinations.failure_ts; Type: COMMENT; Schema: public; Owner: synapse
--

COMMENT ON COLUMN public.destinations.failure_ts IS 'The first time we tried and failed to reach the remote server, in ms.
This field is reset to `NULL` when we succeed in connecting again.';


--
-- Name: COLUMN destinations.last_successful_stream_ordering; Type: COMMENT; Schema: public; Owner: synapse
--

COMMENT ON COLUMN public.destinations.last_successful_stream_ordering IS 'Stream ordering of the most recently successfully sent PDU to this server, sent through normal send (not e.g. backfill).
In Catch-Up Mode, the original PDU persisted by us is represented here, even if we sent a later forward extremity in its stead.
See `destination_rooms` for more information about catch-up.';


--
-- Name: device_auth_providers; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.device_auth_providers (
    user_id text NOT NULL,
    device_id text NOT NULL,
    auth_provider_id text NOT NULL,
    auth_provider_session_id text NOT NULL
);


ALTER TABLE public.device_auth_providers OWNER TO synapse;

--
-- Name: device_federation_inbox; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.device_federation_inbox (
    origin text NOT NULL,
    message_id text NOT NULL,
    received_ts bigint NOT NULL,
    instance_name text
);


ALTER TABLE public.device_federation_inbox OWNER TO synapse;

--
-- Name: device_federation_outbox; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.device_federation_outbox (
    destination text NOT NULL,
    stream_id bigint NOT NULL,
    queued_ts bigint NOT NULL,
    messages_json text NOT NULL,
    instance_name text
);


ALTER TABLE public.device_federation_outbox OWNER TO synapse;

--
-- Name: device_inbox; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.device_inbox (
    user_id text NOT NULL,
    device_id text NOT NULL,
    stream_id bigint NOT NULL,
    message_json text NOT NULL,
    instance_name text
);


ALTER TABLE public.device_inbox OWNER TO synapse;

--
-- Name: device_inbox_sequence; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.device_inbox_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.device_inbox_sequence OWNER TO synapse;

--
-- Name: device_lists_changes_converted_stream_position; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.device_lists_changes_converted_stream_position (
    lock character(1) DEFAULT 'X'::bpchar NOT NULL,
    stream_id bigint NOT NULL,
    room_id text NOT NULL,
    instance_name text,
    CONSTRAINT device_lists_changes_converted_stream_position_lock_check CHECK ((lock = 'X'::bpchar))
);


ALTER TABLE public.device_lists_changes_converted_stream_position OWNER TO synapse;

--
-- Name: device_lists_changes_in_room; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.device_lists_changes_in_room (
    user_id text NOT NULL,
    device_id text NOT NULL,
    room_id text NOT NULL,
    stream_id bigint NOT NULL,
    converted_to_destinations boolean NOT NULL,
    opentracing_context text,
    instance_name text,
    inserted_ts bigint
);


ALTER TABLE public.device_lists_changes_in_room OWNER TO synapse;

--
-- Name: device_lists_changes_in_room_max_pruned_stream_id; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.device_lists_changes_in_room_max_pruned_stream_id (
    lock character(1) DEFAULT 'X'::bpchar NOT NULL,
    stream_id bigint NOT NULL
);


ALTER TABLE public.device_lists_changes_in_room_max_pruned_stream_id OWNER TO synapse;

--
-- Name: device_lists_outbound_last_success; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.device_lists_outbound_last_success (
    destination text NOT NULL,
    user_id text NOT NULL,
    stream_id bigint NOT NULL
);


ALTER TABLE public.device_lists_outbound_last_success OWNER TO synapse;

--
-- Name: device_lists_outbound_pokes; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.device_lists_outbound_pokes (
    destination text NOT NULL,
    stream_id bigint NOT NULL,
    user_id text NOT NULL,
    device_id text NOT NULL,
    sent boolean NOT NULL,
    ts bigint NOT NULL,
    opentracing_context text,
    instance_name text
);


ALTER TABLE public.device_lists_outbound_pokes OWNER TO synapse;

--
-- Name: device_lists_remote_cache; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.device_lists_remote_cache (
    user_id text NOT NULL,
    device_id text NOT NULL,
    content text NOT NULL
);


ALTER TABLE public.device_lists_remote_cache OWNER TO synapse;

--
-- Name: device_lists_remote_extremeties; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.device_lists_remote_extremeties (
    user_id text NOT NULL,
    stream_id text NOT NULL
);


ALTER TABLE public.device_lists_remote_extremeties OWNER TO synapse;

--
-- Name: device_lists_remote_pending; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.device_lists_remote_pending (
    stream_id bigint NOT NULL,
    user_id text NOT NULL,
    device_id text NOT NULL,
    instance_name text
);


ALTER TABLE public.device_lists_remote_pending OWNER TO synapse;

--
-- Name: device_lists_remote_resync; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.device_lists_remote_resync (
    user_id text NOT NULL,
    added_ts bigint NOT NULL
);


ALTER TABLE public.device_lists_remote_resync OWNER TO synapse;

--
-- Name: device_lists_sequence; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.device_lists_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.device_lists_sequence OWNER TO synapse;

--
-- Name: device_lists_stream; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.device_lists_stream (
    stream_id bigint NOT NULL,
    user_id text NOT NULL,
    device_id text NOT NULL,
    instance_name text
);


ALTER TABLE public.device_lists_stream OWNER TO synapse;

--
-- Name: devices; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.devices (
    user_id text NOT NULL,
    device_id text NOT NULL,
    display_name text,
    last_seen bigint,
    ip text,
    user_agent text,
    hidden boolean DEFAULT false
);


ALTER TABLE public.devices OWNER TO synapse;

--
-- Name: e2e_cross_signing_keys; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.e2e_cross_signing_keys (
    user_id text NOT NULL,
    keytype text NOT NULL,
    keydata text NOT NULL,
    stream_id bigint NOT NULL,
    updatable_without_uia_before_ms bigint,
    instance_name text
);


ALTER TABLE public.e2e_cross_signing_keys OWNER TO synapse;

--
-- Name: e2e_cross_signing_keys_sequence; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.e2e_cross_signing_keys_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.e2e_cross_signing_keys_sequence OWNER TO synapse;

--
-- Name: e2e_cross_signing_signatures; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.e2e_cross_signing_signatures (
    user_id text NOT NULL,
    key_id text NOT NULL,
    target_user_id text NOT NULL,
    target_device_id text NOT NULL,
    signature text NOT NULL
);


ALTER TABLE public.e2e_cross_signing_signatures OWNER TO synapse;

--
-- Name: e2e_device_keys_json; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.e2e_device_keys_json (
    user_id text NOT NULL,
    device_id text NOT NULL,
    ts_added_ms bigint NOT NULL,
    key_json text NOT NULL
);


ALTER TABLE public.e2e_device_keys_json OWNER TO synapse;

--
-- Name: e2e_fallback_keys_json; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.e2e_fallback_keys_json (
    user_id text NOT NULL,
    device_id text NOT NULL,
    algorithm text NOT NULL,
    key_id text NOT NULL,
    key_json text NOT NULL,
    used boolean DEFAULT false NOT NULL
);


ALTER TABLE public.e2e_fallback_keys_json OWNER TO synapse;

--
-- Name: e2e_one_time_keys_json; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.e2e_one_time_keys_json (
    user_id text NOT NULL,
    device_id text NOT NULL,
    algorithm text NOT NULL,
    key_id text NOT NULL,
    ts_added_ms bigint NOT NULL,
    key_json text NOT NULL
);


ALTER TABLE public.e2e_one_time_keys_json OWNER TO synapse;

--
-- Name: e2e_room_keys; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.e2e_room_keys (
    user_id text NOT NULL,
    room_id text NOT NULL,
    session_id text NOT NULL,
    version bigint NOT NULL,
    first_message_index integer,
    forwarded_count integer,
    is_verified boolean,
    session_data text NOT NULL
);


ALTER TABLE public.e2e_room_keys OWNER TO synapse;

--
-- Name: e2e_room_keys_versions; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.e2e_room_keys_versions (
    user_id text NOT NULL,
    version bigint NOT NULL,
    algorithm text NOT NULL,
    auth_data text NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    etag bigint
);


ALTER TABLE public.e2e_room_keys_versions OWNER TO synapse;

--
-- Name: erased_users; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.erased_users (
    user_id text NOT NULL
);


ALTER TABLE public.erased_users OWNER TO synapse;

--
-- Name: event_auth; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_auth (
    event_id text NOT NULL,
    auth_id text NOT NULL,
    room_id text NOT NULL
);


ALTER TABLE public.event_auth OWNER TO synapse;

--
-- Name: event_auth_chain_id; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.event_auth_chain_id
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.event_auth_chain_id OWNER TO synapse;

--
-- Name: event_auth_chain_links; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_auth_chain_links (
    origin_chain_id bigint NOT NULL,
    origin_sequence_number bigint NOT NULL,
    target_chain_id bigint NOT NULL,
    target_sequence_number bigint NOT NULL
);
ALTER TABLE ONLY public.event_auth_chain_links ALTER COLUMN origin_chain_id SET (n_distinct=-0.5);
ALTER TABLE ONLY public.event_auth_chain_links ALTER COLUMN target_chain_id SET (n_distinct=-0.5);


ALTER TABLE public.event_auth_chain_links OWNER TO synapse;

--
-- Name: event_auth_chain_to_calculate; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_auth_chain_to_calculate (
    event_id text NOT NULL,
    room_id text NOT NULL,
    type text NOT NULL,
    state_key text NOT NULL
);


ALTER TABLE public.event_auth_chain_to_calculate OWNER TO synapse;

--
-- Name: event_auth_chains; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_auth_chains (
    event_id text NOT NULL,
    chain_id bigint NOT NULL,
    sequence_number bigint NOT NULL
);


ALTER TABLE public.event_auth_chains OWNER TO synapse;

--
-- Name: event_backward_extremities; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_backward_extremities (
    event_id text NOT NULL,
    room_id text NOT NULL
);


ALTER TABLE public.event_backward_extremities OWNER TO synapse;

--
-- Name: event_edges; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_edges (
    event_id text NOT NULL,
    prev_event_id text NOT NULL,
    room_id text,
    is_state boolean DEFAULT false NOT NULL
);


ALTER TABLE public.event_edges OWNER TO synapse;

--
-- Name: event_expiry; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_expiry (
    event_id text NOT NULL,
    expiry_ts bigint NOT NULL
);


ALTER TABLE public.event_expiry OWNER TO synapse;

--
-- Name: event_failed_pull_attempts; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_failed_pull_attempts (
    room_id text NOT NULL,
    event_id text NOT NULL,
    num_attempts integer NOT NULL,
    last_attempt_ts bigint NOT NULL,
    last_cause text NOT NULL
);


ALTER TABLE public.event_failed_pull_attempts OWNER TO synapse;

--
-- Name: event_forward_extremities; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_forward_extremities (
    event_id text NOT NULL,
    room_id text NOT NULL
);


ALTER TABLE public.event_forward_extremities OWNER TO synapse;

--
-- Name: event_json; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_json (
    event_id text NOT NULL,
    room_id text NOT NULL,
    internal_metadata text NOT NULL,
    json text NOT NULL,
    format_version integer
);


ALTER TABLE public.event_json OWNER TO synapse;

--
-- Name: event_labels; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_labels (
    event_id text NOT NULL,
    label text NOT NULL,
    room_id text NOT NULL,
    topological_ordering bigint NOT NULL
);


ALTER TABLE public.event_labels OWNER TO synapse;

--
-- Name: event_push_actions; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_push_actions (
    room_id text NOT NULL,
    event_id text NOT NULL,
    user_id text NOT NULL,
    profile_tag character varying(32),
    actions text NOT NULL,
    topological_ordering bigint,
    stream_ordering bigint,
    notif smallint,
    highlight smallint,
    unread smallint,
    thread_id text,
    CONSTRAINT event_push_actions_thread_id CHECK ((thread_id IS NOT NULL))
);


ALTER TABLE public.event_push_actions OWNER TO synapse;

--
-- Name: event_push_actions_staging; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_push_actions_staging (
    event_id text NOT NULL,
    user_id text NOT NULL,
    actions text NOT NULL,
    notif smallint NOT NULL,
    highlight smallint NOT NULL,
    unread smallint,
    thread_id text,
    inserted_ts bigint DEFAULT (EXTRACT(epoch FROM now()) * (1000)::numeric),
    CONSTRAINT event_push_actions_staging_thread_id CHECK ((thread_id IS NOT NULL))
);


ALTER TABLE public.event_push_actions_staging OWNER TO synapse;

--
-- Name: event_push_summary; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_push_summary (
    user_id text NOT NULL,
    room_id text NOT NULL,
    notif_count bigint NOT NULL,
    stream_ordering bigint NOT NULL,
    unread_count bigint,
    last_receipt_stream_ordering bigint,
    thread_id text,
    CONSTRAINT event_push_summary_thread_id CHECK ((thread_id IS NOT NULL))
);


ALTER TABLE public.event_push_summary OWNER TO synapse;

--
-- Name: event_push_summary_last_receipt_stream_id; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_push_summary_last_receipt_stream_id (
    lock character(1) DEFAULT 'X'::bpchar NOT NULL,
    stream_id bigint NOT NULL,
    CONSTRAINT event_push_summary_last_receipt_stream_id_lock_check CHECK ((lock = 'X'::bpchar))
);


ALTER TABLE public.event_push_summary_last_receipt_stream_id OWNER TO synapse;

--
-- Name: event_push_summary_stream_ordering; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_push_summary_stream_ordering (
    lock character(1) DEFAULT 'X'::bpchar NOT NULL,
    stream_ordering bigint NOT NULL,
    CONSTRAINT event_push_summary_stream_ordering_lock_check CHECK ((lock = 'X'::bpchar))
);


ALTER TABLE public.event_push_summary_stream_ordering OWNER TO synapse;

--
-- Name: event_relations; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_relations (
    event_id text NOT NULL,
    relates_to_id text NOT NULL,
    relation_type text NOT NULL,
    aggregation_key text
);


ALTER TABLE public.event_relations OWNER TO synapse;

--
-- Name: event_reports; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_reports (
    id bigint NOT NULL,
    received_ts bigint NOT NULL,
    room_id text NOT NULL,
    event_id text NOT NULL,
    user_id text NOT NULL,
    reason text,
    content text
);


ALTER TABLE public.event_reports OWNER TO synapse;

--
-- Name: event_search; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_search (
    event_id text,
    room_id text,
    sender text,
    key text,
    vector tsvector,
    origin_server_ts bigint,
    stream_ordering bigint
);
ALTER TABLE ONLY public.event_search ALTER COLUMN room_id SET (n_distinct=-0.01);


ALTER TABLE public.event_search OWNER TO synapse;

--
-- Name: event_to_state_groups; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_to_state_groups (
    event_id text NOT NULL,
    state_group bigint NOT NULL
);


ALTER TABLE public.event_to_state_groups OWNER TO synapse;

--
-- Name: event_txn_id_device_id; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.event_txn_id_device_id (
    event_id text NOT NULL,
    room_id text NOT NULL,
    user_id text NOT NULL,
    device_id text NOT NULL,
    txn_id text NOT NULL,
    inserted_ts bigint NOT NULL
);


ALTER TABLE public.event_txn_id_device_id OWNER TO synapse;

--
-- Name: events; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.events (
    topological_ordering bigint NOT NULL,
    event_id text NOT NULL,
    type text NOT NULL,
    room_id text NOT NULL,
    content text,
    unrecognized_keys text,
    processed boolean NOT NULL,
    outlier boolean NOT NULL,
    depth bigint DEFAULT 0 NOT NULL,
    origin_server_ts bigint,
    received_ts bigint,
    sender text,
    contains_url boolean,
    instance_name text,
    stream_ordering bigint,
    state_key text,
    rejection_reason text
);


ALTER TABLE public.events OWNER TO synapse;

--
-- Name: events_backfill_stream_seq; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.events_backfill_stream_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.events_backfill_stream_seq OWNER TO synapse;

--
-- Name: events_stream_seq; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.events_stream_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.events_stream_seq OWNER TO synapse;

--
-- Name: ex_outlier_stream; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.ex_outlier_stream (
    event_stream_ordering bigint NOT NULL,
    event_id text NOT NULL,
    state_group bigint NOT NULL,
    instance_name text
);


ALTER TABLE public.ex_outlier_stream OWNER TO synapse;

--
-- Name: federation_inbound_events_staging; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.federation_inbound_events_staging (
    origin text NOT NULL,
    room_id text NOT NULL,
    event_id text NOT NULL,
    received_ts bigint NOT NULL,
    event_json text NOT NULL,
    internal_metadata text NOT NULL
);


ALTER TABLE public.federation_inbound_events_staging OWNER TO synapse;

--
-- Name: federation_stream_position; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.federation_stream_position (
    type text NOT NULL,
    stream_id bigint NOT NULL,
    instance_name text DEFAULT 'master'::text NOT NULL
);


ALTER TABLE public.federation_stream_position OWNER TO synapse;

--
-- Name: ignored_users; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.ignored_users (
    ignorer_user_id text NOT NULL,
    ignored_user_id text NOT NULL
);


ALTER TABLE public.ignored_users OWNER TO synapse;

--
-- Name: instance_map; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.instance_map (
    instance_id integer NOT NULL,
    instance_name text NOT NULL
);


ALTER TABLE public.instance_map OWNER TO synapse;

--
-- Name: instance_map_instance_id_seq; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.instance_map_instance_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.instance_map_instance_id_seq OWNER TO synapse;

--
-- Name: instance_map_instance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: synapse
--

ALTER SEQUENCE public.instance_map_instance_id_seq OWNED BY public.instance_map.instance_id;


--
-- Name: local_current_membership; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.local_current_membership (
    room_id text NOT NULL,
    user_id text NOT NULL,
    event_id text NOT NULL,
    membership text NOT NULL,
    event_stream_ordering bigint
);


ALTER TABLE public.local_current_membership OWNER TO synapse;

--
-- Name: local_media_repository; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.local_media_repository (
    media_id text,
    media_type text,
    media_length integer,
    created_ts bigint,
    upload_name text,
    user_id text,
    quarantined_by text,
    url_cache text,
    last_access_ts bigint,
    safe_from_quarantine boolean DEFAULT false NOT NULL,
    authenticated boolean DEFAULT false NOT NULL,
    sha256 text
);


ALTER TABLE public.local_media_repository OWNER TO synapse;

--
-- Name: local_media_repository_thumbnails; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.local_media_repository_thumbnails (
    media_id text,
    thumbnail_width integer,
    thumbnail_height integer,
    thumbnail_type text,
    thumbnail_method text,
    thumbnail_length integer
);


ALTER TABLE public.local_media_repository_thumbnails OWNER TO synapse;

--
-- Name: local_media_repository_url_cache; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.local_media_repository_url_cache (
    url text,
    response_code integer,
    etag text,
    expires_ts bigint,
    og text,
    media_id text,
    download_ts bigint
);


ALTER TABLE public.local_media_repository_url_cache OWNER TO synapse;

--
-- Name: login_tokens; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.login_tokens (
    token text NOT NULL,
    user_id text NOT NULL,
    expiry_ts bigint NOT NULL,
    used_ts bigint,
    auth_provider_id text,
    auth_provider_session_id text
);


ALTER TABLE public.login_tokens OWNER TO synapse;

--
-- Name: monthly_active_users; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.monthly_active_users (
    user_id text NOT NULL,
    "timestamp" bigint NOT NULL
);


ALTER TABLE public.monthly_active_users OWNER TO synapse;

--
-- Name: msc4242_state_dag_edges; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.msc4242_state_dag_edges (
    room_id text NOT NULL,
    event_id text NOT NULL,
    prev_state_event_id text
);


ALTER TABLE public.msc4242_state_dag_edges OWNER TO synapse;

--
-- Name: msc4242_state_dag_forward_extremities; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.msc4242_state_dag_forward_extremities (
    room_id text NOT NULL,
    event_id text NOT NULL
);


ALTER TABLE public.msc4242_state_dag_forward_extremities OWNER TO synapse;

--
-- Name: open_id_tokens; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.open_id_tokens (
    token text NOT NULL,
    ts_valid_until_ms bigint NOT NULL,
    user_id text NOT NULL
);


ALTER TABLE public.open_id_tokens OWNER TO synapse;

--
-- Name: partial_state_events; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.partial_state_events (
    room_id text NOT NULL,
    event_id text NOT NULL
);


ALTER TABLE public.partial_state_events OWNER TO synapse;

--
-- Name: partial_state_rooms; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.partial_state_rooms (
    room_id text NOT NULL,
    device_lists_stream_id bigint DEFAULT 0 NOT NULL,
    join_event_id text,
    joined_via text
);


ALTER TABLE public.partial_state_rooms OWNER TO synapse;

--
-- Name: partial_state_rooms_servers; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.partial_state_rooms_servers (
    room_id text NOT NULL,
    server_name text NOT NULL
);


ALTER TABLE public.partial_state_rooms_servers OWNER TO synapse;

--
-- Name: per_user_experimental_features; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.per_user_experimental_features (
    user_id text NOT NULL,
    feature text NOT NULL,
    enabled boolean DEFAULT false
);


ALTER TABLE public.per_user_experimental_features OWNER TO synapse;

--
-- Name: presence_stream; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.presence_stream (
    stream_id bigint,
    user_id text,
    state text,
    last_active_ts bigint,
    last_federation_update_ts bigint,
    last_user_sync_ts bigint,
    status_msg text,
    currently_active boolean,
    instance_name text
);


ALTER TABLE public.presence_stream OWNER TO synapse;

--
-- Name: presence_stream_sequence; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.presence_stream_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.presence_stream_sequence OWNER TO synapse;

--
-- Name: profiles; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.profiles (
    user_id text NOT NULL,
    displayname text,
    avatar_url text,
    full_user_id text,
    fields jsonb,
    CONSTRAINT full_user_id_not_null CHECK ((full_user_id IS NOT NULL))
);


ALTER TABLE public.profiles OWNER TO synapse;

--
-- Name: push_rules; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.push_rules (
    id bigint NOT NULL,
    user_name text NOT NULL,
    rule_id text NOT NULL,
    priority_class smallint NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    conditions text NOT NULL,
    actions text NOT NULL
);


ALTER TABLE public.push_rules OWNER TO synapse;

--
-- Name: push_rules_enable; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.push_rules_enable (
    id bigint NOT NULL,
    user_name text NOT NULL,
    rule_id text NOT NULL,
    enabled smallint
);


ALTER TABLE public.push_rules_enable OWNER TO synapse;

--
-- Name: push_rules_stream; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.push_rules_stream (
    stream_id bigint NOT NULL,
    event_stream_ordering bigint NOT NULL,
    user_id text NOT NULL,
    rule_id text NOT NULL,
    op text NOT NULL,
    priority_class smallint,
    priority integer,
    conditions text,
    actions text,
    instance_name text
);


ALTER TABLE public.push_rules_stream OWNER TO synapse;

--
-- Name: push_rules_stream_sequence; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.push_rules_stream_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.push_rules_stream_sequence OWNER TO synapse;

--
-- Name: pusher_throttle; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.pusher_throttle (
    pusher bigint NOT NULL,
    room_id text NOT NULL,
    last_sent_ts bigint,
    throttle_ms bigint
);


ALTER TABLE public.pusher_throttle OWNER TO synapse;

--
-- Name: pushers; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.pushers (
    id bigint NOT NULL,
    user_name text NOT NULL,
    access_token bigint,
    profile_tag text NOT NULL,
    kind text NOT NULL,
    app_id text NOT NULL,
    app_display_name text NOT NULL,
    device_display_name text NOT NULL,
    pushkey text NOT NULL,
    ts bigint NOT NULL,
    lang text,
    data text,
    last_stream_ordering bigint,
    last_success bigint,
    failing_since bigint,
    enabled boolean,
    device_id text,
    instance_name text
);


ALTER TABLE public.pushers OWNER TO synapse;

--
-- Name: pushers_sequence; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.pushers_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pushers_sequence OWNER TO synapse;

--
-- Name: quarantined_media_changes; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.quarantined_media_changes (
    stream_id integer NOT NULL,
    instance_name text NOT NULL,
    origin text,
    media_id text NOT NULL,
    quarantined boolean NOT NULL
);


ALTER TABLE public.quarantined_media_changes OWNER TO synapse;

--
-- Name: quarantined_media_id_seq; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.quarantined_media_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.quarantined_media_id_seq OWNER TO synapse;

--
-- Name: ratelimit_override; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.ratelimit_override (
    user_id text NOT NULL,
    messages_per_second bigint,
    burst_count bigint
);


ALTER TABLE public.ratelimit_override OWNER TO synapse;

--
-- Name: receipts_graph; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.receipts_graph (
    room_id text NOT NULL,
    receipt_type text NOT NULL,
    user_id text NOT NULL,
    event_ids text NOT NULL,
    data text NOT NULL,
    thread_id text
);


ALTER TABLE public.receipts_graph OWNER TO synapse;

--
-- Name: receipts_linearized; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.receipts_linearized (
    stream_id bigint NOT NULL,
    room_id text NOT NULL,
    receipt_type text NOT NULL,
    user_id text NOT NULL,
    event_id text NOT NULL,
    data text NOT NULL,
    instance_name text,
    event_stream_ordering bigint,
    thread_id text
);


ALTER TABLE public.receipts_linearized OWNER TO synapse;

--
-- Name: receipts_sequence; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.receipts_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.receipts_sequence OWNER TO synapse;

--
-- Name: received_transactions; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.received_transactions (
    transaction_id text,
    origin text,
    ts bigint,
    response_code integer,
    response_json bytea,
    has_been_referenced smallint DEFAULT 0
);


ALTER TABLE public.received_transactions OWNER TO synapse;

--
-- Name: redactions; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.redactions (
    event_id text NOT NULL,
    redacts text NOT NULL,
    have_censored boolean DEFAULT false NOT NULL,
    received_ts bigint,
    recheck boolean DEFAULT true NOT NULL
);


ALTER TABLE public.redactions OWNER TO synapse;

--
-- Name: refresh_tokens; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.refresh_tokens (
    id bigint NOT NULL,
    user_id text NOT NULL,
    device_id text NOT NULL,
    token text NOT NULL,
    next_token_id bigint,
    expiry_ts bigint,
    ultimate_session_expiry_ts bigint
);


ALTER TABLE public.refresh_tokens OWNER TO synapse;

--
-- Name: registration_tokens; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.registration_tokens (
    token text NOT NULL,
    uses_allowed integer,
    pending integer NOT NULL,
    completed integer NOT NULL,
    expiry_time bigint
);


ALTER TABLE public.registration_tokens OWNER TO synapse;

--
-- Name: rejections; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.rejections (
    event_id text NOT NULL,
    reason text NOT NULL,
    last_check text NOT NULL
);


ALTER TABLE public.rejections OWNER TO synapse;

--
-- Name: remote_media_cache; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.remote_media_cache (
    media_origin text,
    media_id text,
    media_type text,
    created_ts bigint,
    upload_name text,
    media_length integer,
    filesystem_id text,
    last_access_ts bigint,
    quarantined_by text,
    authenticated boolean DEFAULT false NOT NULL,
    sha256 text
);


ALTER TABLE public.remote_media_cache OWNER TO synapse;

--
-- Name: remote_media_cache_thumbnails; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.remote_media_cache_thumbnails (
    media_origin text,
    media_id text,
    thumbnail_width integer,
    thumbnail_height integer,
    thumbnail_method text,
    thumbnail_type text,
    thumbnail_length integer,
    filesystem_id text
);


ALTER TABLE public.remote_media_cache_thumbnails OWNER TO synapse;

--
-- Name: room_account_data; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.room_account_data (
    user_id text NOT NULL,
    room_id text NOT NULL,
    account_data_type text NOT NULL,
    stream_id bigint NOT NULL,
    content text NOT NULL,
    instance_name text
);


ALTER TABLE public.room_account_data OWNER TO synapse;

--
-- Name: room_alias_servers; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.room_alias_servers (
    room_alias text NOT NULL,
    server text NOT NULL
);


ALTER TABLE public.room_alias_servers OWNER TO synapse;

--
-- Name: room_aliases; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.room_aliases (
    room_alias text NOT NULL,
    room_id text NOT NULL,
    creator text
);


ALTER TABLE public.room_aliases OWNER TO synapse;

--
-- Name: room_ban_redactions; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.room_ban_redactions (
    room_id text NOT NULL,
    user_id text NOT NULL,
    redacting_event_id text NOT NULL,
    redact_end_ordering bigint
);


ALTER TABLE public.room_ban_redactions OWNER TO synapse;

--
-- Name: room_depth; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.room_depth (
    room_id text NOT NULL,
    min_depth bigint
);


ALTER TABLE public.room_depth OWNER TO synapse;

--
-- Name: room_forgetter_stream_pos; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.room_forgetter_stream_pos (
    lock character(1) DEFAULT 'X'::bpchar NOT NULL,
    stream_id bigint NOT NULL,
    CONSTRAINT room_forgetter_stream_pos_lock_check CHECK ((lock = 'X'::bpchar))
);


ALTER TABLE public.room_forgetter_stream_pos OWNER TO synapse;

--
-- Name: room_memberships; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.room_memberships (
    event_id text NOT NULL,
    user_id text NOT NULL,
    sender text NOT NULL,
    room_id text NOT NULL,
    membership text NOT NULL,
    forgotten integer DEFAULT 0,
    display_name text,
    avatar_url text,
    event_stream_ordering bigint,
    participant boolean DEFAULT false
);


ALTER TABLE public.room_memberships OWNER TO synapse;

--
-- Name: room_reports; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.room_reports (
    id bigint NOT NULL,
    received_ts bigint NOT NULL,
    room_id text NOT NULL,
    user_id text NOT NULL,
    reason text NOT NULL
);


ALTER TABLE public.room_reports OWNER TO synapse;

--
-- Name: room_retention; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.room_retention (
    room_id text NOT NULL,
    event_id text NOT NULL,
    min_lifetime bigint,
    max_lifetime bigint
);


ALTER TABLE public.room_retention OWNER TO synapse;

--
-- Name: room_stats_current; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.room_stats_current (
    room_id text NOT NULL,
    current_state_events integer NOT NULL,
    joined_members integer NOT NULL,
    invited_members integer NOT NULL,
    left_members integer NOT NULL,
    banned_members integer NOT NULL,
    local_users_in_room integer NOT NULL,
    completed_delta_stream_id bigint NOT NULL,
    knocked_members integer
);


ALTER TABLE public.room_stats_current OWNER TO synapse;

--
-- Name: room_stats_earliest_token; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.room_stats_earliest_token (
    room_id text NOT NULL,
    token bigint NOT NULL
);


ALTER TABLE public.room_stats_earliest_token OWNER TO synapse;

--
-- Name: room_stats_state; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.room_stats_state (
    room_id text NOT NULL,
    name text,
    canonical_alias text,
    join_rules text,
    history_visibility text,
    encryption text,
    avatar text,
    guest_access text,
    is_federatable boolean,
    topic text,
    room_type text
);


ALTER TABLE public.room_stats_state OWNER TO synapse;

--
-- Name: room_tags; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.room_tags (
    user_id text NOT NULL,
    room_id text NOT NULL,
    tag text NOT NULL,
    content text NOT NULL
);


ALTER TABLE public.room_tags OWNER TO synapse;

--
-- Name: room_tags_revisions; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.room_tags_revisions (
    user_id text NOT NULL,
    room_id text NOT NULL,
    stream_id bigint NOT NULL,
    instance_name text
);


ALTER TABLE public.room_tags_revisions OWNER TO synapse;

--
-- Name: rooms; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.rooms (
    room_id text NOT NULL,
    is_public boolean,
    creator text,
    room_version text,
    has_auth_chain_index boolean
);


ALTER TABLE public.rooms OWNER TO synapse;

--
-- Name: scheduled_tasks; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.scheduled_tasks (
    id text NOT NULL,
    action text NOT NULL,
    status text NOT NULL,
    "timestamp" bigint NOT NULL,
    resource_id text,
    params text,
    result text,
    error text
);


ALTER TABLE public.scheduled_tasks OWNER TO synapse;

--
-- Name: schema_compat_version; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.schema_compat_version (
    lock character(1) DEFAULT 'X'::bpchar NOT NULL,
    compat_version integer NOT NULL,
    CONSTRAINT schema_compat_version_lock_check CHECK ((lock = 'X'::bpchar))
);


ALTER TABLE public.schema_compat_version OWNER TO synapse;

--
-- Name: schema_version; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.schema_version (
    lock character(1) DEFAULT 'X'::bpchar NOT NULL,
    version integer NOT NULL,
    upgraded boolean NOT NULL,
    CONSTRAINT schema_version_lock_check CHECK ((lock = 'X'::bpchar))
);


ALTER TABLE public.schema_version OWNER TO synapse;

--
-- Name: server_keys_json; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.server_keys_json (
    server_name text NOT NULL,
    key_id text NOT NULL,
    from_server text NOT NULL,
    ts_added_ms bigint NOT NULL,
    ts_valid_until_ms bigint NOT NULL,
    key_json bytea NOT NULL
);


ALTER TABLE public.server_keys_json OWNER TO synapse;

--
-- Name: server_signature_keys; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.server_signature_keys (
    server_name text,
    key_id text,
    from_server text,
    ts_added_ms bigint,
    verify_key bytea,
    ts_valid_until_ms bigint
);


ALTER TABLE public.server_signature_keys OWNER TO synapse;

--
-- Name: sessions; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.sessions (
    session_type text NOT NULL,
    session_id text NOT NULL,
    value text NOT NULL,
    expiry_time_ms bigint NOT NULL
);


ALTER TABLE public.sessions OWNER TO synapse;

--
-- Name: sliding_sync_connection_lazy_members; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.sliding_sync_connection_lazy_members (
    connection_key bigint NOT NULL,
    connection_position bigint,
    room_id text NOT NULL,
    user_id text NOT NULL,
    last_seen_ts bigint NOT NULL
);


ALTER TABLE public.sliding_sync_connection_lazy_members OWNER TO synapse;

--
-- Name: sliding_sync_connection_positions; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.sliding_sync_connection_positions (
    connection_position bigint NOT NULL,
    connection_key bigint NOT NULL,
    created_ts bigint NOT NULL
);


ALTER TABLE public.sliding_sync_connection_positions OWNER TO synapse;

--
-- Name: sliding_sync_connection_positions_connection_position_seq; Type: SEQUENCE; Schema: public; Owner: synapse
--

ALTER TABLE public.sliding_sync_connection_positions ALTER COLUMN connection_position ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.sliding_sync_connection_positions_connection_position_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: sliding_sync_connection_required_state; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.sliding_sync_connection_required_state (
    required_state_id bigint NOT NULL,
    connection_key bigint NOT NULL,
    required_state text NOT NULL
);


ALTER TABLE public.sliding_sync_connection_required_state OWNER TO synapse;

--
-- Name: sliding_sync_connection_required_state_required_state_id_seq; Type: SEQUENCE; Schema: public; Owner: synapse
--

ALTER TABLE public.sliding_sync_connection_required_state ALTER COLUMN required_state_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.sliding_sync_connection_required_state_required_state_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: sliding_sync_connection_room_configs; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.sliding_sync_connection_room_configs (
    connection_position bigint NOT NULL,
    room_id text NOT NULL,
    timeline_limit bigint NOT NULL,
    required_state_id bigint NOT NULL
);


ALTER TABLE public.sliding_sync_connection_room_configs OWNER TO synapse;

--
-- Name: sliding_sync_connection_streams; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.sliding_sync_connection_streams (
    connection_position bigint NOT NULL,
    stream text NOT NULL,
    room_id text NOT NULL,
    room_status text NOT NULL,
    last_token text
);


ALTER TABLE public.sliding_sync_connection_streams OWNER TO synapse;

--
-- Name: sliding_sync_connections; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.sliding_sync_connections (
    connection_key bigint NOT NULL,
    user_id text NOT NULL,
    effective_device_id text NOT NULL,
    conn_id text NOT NULL,
    created_ts bigint NOT NULL,
    last_used_ts bigint
);


ALTER TABLE public.sliding_sync_connections OWNER TO synapse;

--
-- Name: sliding_sync_connections_connection_key_seq; Type: SEQUENCE; Schema: public; Owner: synapse
--

ALTER TABLE public.sliding_sync_connections ALTER COLUMN connection_key ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.sliding_sync_connections_connection_key_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: sliding_sync_joined_rooms; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.sliding_sync_joined_rooms (
    room_id text NOT NULL,
    event_stream_ordering bigint NOT NULL,
    bump_stamp bigint,
    room_type text,
    room_name text,
    is_encrypted boolean DEFAULT false NOT NULL,
    tombstone_successor_room_id text
);


ALTER TABLE public.sliding_sync_joined_rooms OWNER TO synapse;

--
-- Name: sliding_sync_joined_rooms_to_recalculate; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.sliding_sync_joined_rooms_to_recalculate (
    room_id text NOT NULL
);


ALTER TABLE public.sliding_sync_joined_rooms_to_recalculate OWNER TO synapse;

--
-- Name: sliding_sync_membership_snapshots; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.sliding_sync_membership_snapshots (
    room_id text NOT NULL,
    user_id text NOT NULL,
    sender text NOT NULL,
    membership_event_id text NOT NULL,
    membership text NOT NULL,
    forgotten integer DEFAULT 0 NOT NULL,
    event_stream_ordering bigint NOT NULL,
    event_instance_name text NOT NULL,
    has_known_state boolean DEFAULT false NOT NULL,
    room_type text,
    room_name text,
    is_encrypted boolean DEFAULT false NOT NULL,
    tombstone_successor_room_id text
);


ALTER TABLE public.sliding_sync_membership_snapshots OWNER TO synapse;

--
-- Name: state_events; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.state_events (
    event_id text NOT NULL,
    room_id text NOT NULL,
    type text NOT NULL,
    state_key text NOT NULL,
    prev_state text
);


ALTER TABLE public.state_events OWNER TO synapse;

--
-- Name: state_group_edges; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.state_group_edges (
    state_group bigint NOT NULL,
    prev_state_group bigint NOT NULL
);


ALTER TABLE public.state_group_edges OWNER TO synapse;

--
-- Name: state_group_id_seq; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.state_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.state_group_id_seq OWNER TO synapse;

--
-- Name: state_groups; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.state_groups (
    id bigint NOT NULL,
    room_id text NOT NULL,
    event_id text NOT NULL
);


ALTER TABLE public.state_groups OWNER TO synapse;

--
-- Name: state_groups_pending_deletion; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.state_groups_pending_deletion (
    sequence_number bigint NOT NULL,
    state_group bigint NOT NULL,
    insertion_ts bigint NOT NULL
);


ALTER TABLE public.state_groups_pending_deletion OWNER TO synapse;

--
-- Name: state_groups_pending_deletion_sequence_number_seq; Type: SEQUENCE; Schema: public; Owner: synapse
--

ALTER TABLE public.state_groups_pending_deletion ALTER COLUMN sequence_number ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.state_groups_pending_deletion_sequence_number_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: state_groups_persisting; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.state_groups_persisting (
    state_group bigint NOT NULL,
    instance_name text NOT NULL
);


ALTER TABLE public.state_groups_persisting OWNER TO synapse;

--
-- Name: state_groups_state; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.state_groups_state (
    state_group bigint NOT NULL,
    room_id text NOT NULL,
    type text NOT NULL,
    state_key text NOT NULL,
    event_id text NOT NULL
);
ALTER TABLE ONLY public.state_groups_state ALTER COLUMN state_group SET (n_distinct=-0.02);


ALTER TABLE public.state_groups_state OWNER TO synapse;

--
-- Name: stats_incremental_position; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.stats_incremental_position (
    lock character(1) DEFAULT 'X'::bpchar NOT NULL,
    stream_id bigint NOT NULL,
    CONSTRAINT stats_incremental_position_lock_check CHECK ((lock = 'X'::bpchar))
);


ALTER TABLE public.stats_incremental_position OWNER TO synapse;

--
-- Name: sticky_events; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.sticky_events (
    stream_id integer NOT NULL,
    instance_name text NOT NULL,
    event_id text NOT NULL,
    room_id text NOT NULL,
    event_stream_ordering integer NOT NULL,
    sender text NOT NULL,
    expires_at bigint NOT NULL
);


ALTER TABLE public.sticky_events OWNER TO synapse;

--
-- Name: sticky_events_sequence; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.sticky_events_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sticky_events_sequence OWNER TO synapse;

--
-- Name: stream_ordering_to_exterm; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.stream_ordering_to_exterm (
    stream_ordering bigint NOT NULL,
    room_id text NOT NULL,
    event_id text NOT NULL
);


ALTER TABLE public.stream_ordering_to_exterm OWNER TO synapse;

--
-- Name: stream_positions; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.stream_positions (
    stream_name text NOT NULL,
    instance_name text NOT NULL,
    stream_id bigint NOT NULL
);


ALTER TABLE public.stream_positions OWNER TO synapse;

--
-- Name: thread_subscriptions; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.thread_subscriptions (
    stream_id integer NOT NULL,
    instance_name text NOT NULL,
    room_id text NOT NULL,
    event_id text NOT NULL,
    user_id text NOT NULL,
    subscribed boolean NOT NULL,
    automatic boolean NOT NULL,
    unsubscribed_at_stream_ordering bigint,
    unsubscribed_at_topological_ordering bigint
);


ALTER TABLE public.thread_subscriptions OWNER TO synapse;

--
-- Name: TABLE thread_subscriptions; Type: COMMENT; Schema: public; Owner: synapse
--

COMMENT ON TABLE public.thread_subscriptions IS 'Tracks local users that subscribe to threads';


--
-- Name: COLUMN thread_subscriptions.subscribed; Type: COMMENT; Schema: public; Owner: synapse
--

COMMENT ON COLUMN public.thread_subscriptions.subscribed IS 'Whether the user is subscribed to the thread or not. We track unsubscribed threads because we need to stream the subscription change to the client.';


--
-- Name: COLUMN thread_subscriptions.automatic; Type: COMMENT; Schema: public; Owner: synapse
--

COMMENT ON COLUMN public.thread_subscriptions.automatic IS 'True if the user was subscribed to the thread automatically by their client, or false if the client manually requested the subscription.';


--
-- Name: COLUMN thread_subscriptions.unsubscribed_at_stream_ordering; Type: COMMENT; Schema: public; Owner: synapse
--

COMMENT ON COLUMN public.thread_subscriptions.unsubscribed_at_stream_ordering IS 'The maximum stream_ordering in the room when the unsubscription was made.';


--
-- Name: COLUMN thread_subscriptions.unsubscribed_at_topological_ordering; Type: COMMENT; Schema: public; Owner: synapse
--

COMMENT ON COLUMN public.thread_subscriptions.unsubscribed_at_topological_ordering IS 'The maximum topological_ordering in the room when the unsubscription was made.';


--
-- Name: thread_subscriptions_sequence; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.thread_subscriptions_sequence
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.thread_subscriptions_sequence OWNER TO synapse;

--
-- Name: threads; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.threads (
    room_id text NOT NULL,
    thread_id text NOT NULL,
    latest_event_id text NOT NULL,
    topological_ordering bigint NOT NULL,
    stream_ordering bigint NOT NULL
);


ALTER TABLE public.threads OWNER TO synapse;

--
-- Name: COLUMN threads.latest_event_id; Type: COMMENT; Schema: public; Owner: synapse
--

COMMENT ON COLUMN public.threads.latest_event_id IS 'the ID of the event that is latest, ordered by (topological_ordering, stream_ordering)';


--
-- Name: COLUMN threads.topological_ordering; Type: COMMENT; Schema: public; Owner: synapse
--

COMMENT ON COLUMN public.threads.topological_ordering IS 'the topological ordering of the thread''''s LATEST event.
Used as the primary way of ordering threads by recency in a room.';


--
-- Name: COLUMN threads.stream_ordering; Type: COMMENT; Schema: public; Owner: synapse
--

COMMENT ON COLUMN public.threads.stream_ordering IS 'the stream ordering of the thread''s LATEST event.
Used as a tie-breaker for ordering threads by recency in a room, when the topological order is a tie.
Also used for recency ordering in sliding sync.';


--
-- Name: threepid_guest_access_tokens; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.threepid_guest_access_tokens (
    medium text,
    address text,
    guest_access_token text,
    first_inviter text
);


ALTER TABLE public.threepid_guest_access_tokens OWNER TO synapse;

--
-- Name: threepid_validation_session; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.threepid_validation_session (
    session_id text NOT NULL,
    medium text NOT NULL,
    address text NOT NULL,
    client_secret text NOT NULL,
    last_send_attempt bigint NOT NULL,
    validated_at bigint
);


ALTER TABLE public.threepid_validation_session OWNER TO synapse;

--
-- Name: threepid_validation_token; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.threepid_validation_token (
    token text NOT NULL,
    session_id text NOT NULL,
    next_link text,
    expires bigint NOT NULL
);


ALTER TABLE public.threepid_validation_token OWNER TO synapse;

--
-- Name: timeline_gaps; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.timeline_gaps (
    room_id text NOT NULL,
    instance_name text NOT NULL,
    stream_ordering bigint NOT NULL
);


ALTER TABLE public.timeline_gaps OWNER TO synapse;

--
-- Name: ui_auth_sessions; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.ui_auth_sessions (
    session_id text NOT NULL,
    creation_time bigint NOT NULL,
    serverdict text NOT NULL,
    clientdict text NOT NULL,
    uri text NOT NULL,
    method text NOT NULL,
    description text NOT NULL
);


ALTER TABLE public.ui_auth_sessions OWNER TO synapse;

--
-- Name: ui_auth_sessions_credentials; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.ui_auth_sessions_credentials (
    session_id text NOT NULL,
    stage_type text NOT NULL,
    result text NOT NULL
);


ALTER TABLE public.ui_auth_sessions_credentials OWNER TO synapse;

--
-- Name: ui_auth_sessions_ips; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.ui_auth_sessions_ips (
    session_id text NOT NULL,
    ip text NOT NULL,
    user_agent text NOT NULL
);


ALTER TABLE public.ui_auth_sessions_ips OWNER TO synapse;

--
-- Name: un_partial_stated_event_stream; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.un_partial_stated_event_stream (
    stream_id bigint NOT NULL,
    instance_name text NOT NULL,
    event_id text NOT NULL,
    rejection_status_changed boolean NOT NULL
);


ALTER TABLE public.un_partial_stated_event_stream OWNER TO synapse;

--
-- Name: un_partial_stated_event_stream_sequence; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.un_partial_stated_event_stream_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.un_partial_stated_event_stream_sequence OWNER TO synapse;

--
-- Name: un_partial_stated_room_stream; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.un_partial_stated_room_stream (
    stream_id bigint NOT NULL,
    instance_name text NOT NULL,
    room_id text NOT NULL
);


ALTER TABLE public.un_partial_stated_room_stream OWNER TO synapse;

--
-- Name: un_partial_stated_room_stream_sequence; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.un_partial_stated_room_stream_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.un_partial_stated_room_stream_sequence OWNER TO synapse;

--
-- Name: user_daily_visits; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.user_daily_visits (
    user_id text NOT NULL,
    device_id text,
    "timestamp" bigint NOT NULL,
    user_agent text
);


ALTER TABLE public.user_daily_visits OWNER TO synapse;

--
-- Name: user_directory; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.user_directory (
    user_id text NOT NULL,
    room_id text,
    display_name text,
    avatar_url text
);


ALTER TABLE public.user_directory OWNER TO synapse;

--
-- Name: user_directory_search; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.user_directory_search (
    user_id text NOT NULL,
    vector tsvector
);


ALTER TABLE public.user_directory_search OWNER TO synapse;

--
-- Name: user_directory_stale_remote_users; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.user_directory_stale_remote_users (
    user_id text NOT NULL,
    user_server_name text NOT NULL,
    next_try_at_ts bigint NOT NULL,
    retry_counter integer NOT NULL
);


ALTER TABLE public.user_directory_stale_remote_users OWNER TO synapse;

--
-- Name: user_directory_stream_pos; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.user_directory_stream_pos (
    lock character(1) DEFAULT 'X'::bpchar NOT NULL,
    stream_id bigint,
    CONSTRAINT user_directory_stream_pos_lock_check CHECK ((lock = 'X'::bpchar))
);


ALTER TABLE public.user_directory_stream_pos OWNER TO synapse;

--
-- Name: user_external_ids; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.user_external_ids (
    auth_provider text NOT NULL,
    external_id text NOT NULL,
    user_id text NOT NULL
);


ALTER TABLE public.user_external_ids OWNER TO synapse;

--
-- Name: user_filters; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.user_filters (
    user_id text NOT NULL,
    filter_id bigint NOT NULL,
    filter_json bytea NOT NULL,
    full_user_id text,
    CONSTRAINT full_user_id_not_null CHECK ((full_user_id IS NOT NULL))
);


ALTER TABLE public.user_filters OWNER TO synapse;

--
-- Name: user_id_seq; Type: SEQUENCE; Schema: public; Owner: synapse
--

CREATE SEQUENCE public.user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_id_seq OWNER TO synapse;

--
-- Name: user_ips; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.user_ips (
    user_id text NOT NULL,
    access_token text NOT NULL,
    device_id text,
    ip text NOT NULL,
    user_agent text NOT NULL,
    last_seen bigint NOT NULL
);


ALTER TABLE public.user_ips OWNER TO synapse;

--
-- Name: user_reports; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.user_reports (
    id bigint NOT NULL,
    received_ts bigint NOT NULL,
    target_user_id text NOT NULL,
    user_id text NOT NULL,
    reason text NOT NULL
);


ALTER TABLE public.user_reports OWNER TO synapse;

--
-- Name: user_signature_stream; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.user_signature_stream (
    stream_id bigint NOT NULL,
    from_user_id text NOT NULL,
    user_ids text NOT NULL,
    instance_name text
);


ALTER TABLE public.user_signature_stream OWNER TO synapse;

--
-- Name: user_stats_current; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.user_stats_current (
    user_id text NOT NULL,
    joined_rooms bigint NOT NULL,
    completed_delta_stream_id bigint NOT NULL
);


ALTER TABLE public.user_stats_current OWNER TO synapse;

--
-- Name: user_threepid_id_server; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.user_threepid_id_server (
    user_id text NOT NULL,
    medium text NOT NULL,
    address text NOT NULL,
    id_server text NOT NULL
);


ALTER TABLE public.user_threepid_id_server OWNER TO synapse;

--
-- Name: user_threepids; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.user_threepids (
    user_id text NOT NULL,
    medium text NOT NULL,
    address text NOT NULL,
    validated_at bigint NOT NULL,
    added_at bigint NOT NULL
);


ALTER TABLE public.user_threepids OWNER TO synapse;

--
-- Name: users; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.users (
    name text,
    password_hash text,
    creation_ts bigint,
    admin smallint DEFAULT 0 NOT NULL,
    upgrade_ts bigint,
    is_guest smallint DEFAULT 0 NOT NULL,
    appservice_id text,
    consent_version text,
    consent_server_notice_sent text,
    user_type text,
    deactivated smallint DEFAULT 0 NOT NULL,
    shadow_banned boolean,
    consent_ts bigint,
    approved boolean,
    locked boolean DEFAULT false NOT NULL,
    suspended boolean DEFAULT false NOT NULL
);


ALTER TABLE public.users OWNER TO synapse;

--
-- Name: users_in_public_rooms; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.users_in_public_rooms (
    user_id text NOT NULL,
    room_id text NOT NULL
);


ALTER TABLE public.users_in_public_rooms OWNER TO synapse;

--
-- Name: users_pending_deactivation; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.users_pending_deactivation (
    user_id text NOT NULL
);


ALTER TABLE public.users_pending_deactivation OWNER TO synapse;

--
-- Name: users_to_send_full_presence_to; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.users_to_send_full_presence_to (
    user_id text NOT NULL,
    presence_stream_id bigint
);


ALTER TABLE public.users_to_send_full_presence_to OWNER TO synapse;

--
-- Name: users_who_share_private_rooms; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.users_who_share_private_rooms (
    user_id text NOT NULL,
    other_user_id text NOT NULL,
    room_id text NOT NULL
);


ALTER TABLE public.users_who_share_private_rooms OWNER TO synapse;

--
-- Name: worker_locks; Type: TABLE; Schema: public; Owner: synapse
--

CREATE TABLE public.worker_locks (
    lock_name text NOT NULL,
    lock_key text NOT NULL,
    instance_name text NOT NULL,
    token text NOT NULL,
    last_renewed_ts bigint NOT NULL
);


ALTER TABLE public.worker_locks OWNER TO synapse;

--
-- Name: worker_read_write_locks; Type: TABLE; Schema: public; Owner: synapse
--

CREATE UNLOGGED TABLE public.worker_read_write_locks (
    lock_name text NOT NULL,
    lock_key text NOT NULL,
    instance_name text NOT NULL,
    write_lock boolean NOT NULL,
    token text NOT NULL,
    last_renewed_ts bigint NOT NULL
);


ALTER TABLE public.worker_read_write_locks OWNER TO synapse;

--
-- Name: worker_read_write_locks_mode; Type: TABLE; Schema: public; Owner: synapse
--

CREATE UNLOGGED TABLE public.worker_read_write_locks_mode (
    lock_name text NOT NULL,
    lock_key text NOT NULL,
    write_lock boolean NOT NULL,
    token text NOT NULL
);


ALTER TABLE public.worker_read_write_locks_mode OWNER TO synapse;

--
-- Name: instance_map instance_id; Type: DEFAULT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.instance_map ALTER COLUMN instance_id SET DEFAULT nextval('public.instance_map_instance_id_seq'::regclass);


--
-- Data for Name: access_tokens; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.access_tokens (id, user_id, device_id, token, valid_until_ms, puppets_user_id, last_validated, refresh_token_id, used) FROM stdin;
2	@alextaylor:matrix.shikpooshaan.ir	SAWFHDVRYA	syt_YWxleHRheWxvcg_uyNKDzOebMfMhLVoWGZa_35IZBx	\N	\N	1783624770288	\N	f
3	@ali:matrix.shikpooshaan.ir	DRPHZPCPVD	syt_YWxp_ZWUCthebpNygkdKvSnfK_0kWsWZ	\N	\N	1783624935930	\N	f
5	@alex-taylor:matrix.shikpooshaan.ir	CRYINYFIHK	syt_YWxleC10YXlsb3I_IHHpoZfKjyxQCsgVCOpE_0jqOpG	\N	\N	1783625058093	\N	f
6	@brianrockwell:matrix.shikpooshaan.ir	AVTTVCQSYF	syt_YnJpYW5yb2Nrd2VsbA_nfrnIcHdQqKlOVGduHCY_4clEpa	\N	\N	1783625084832	\N	f
9	@alextaylor98:matrix.shikpooshaan.ir	GZIPKPHOVU	syt_YWxleHRheWxvcjk4_gvcsCDXGJleBfoMqHVLs_4OjmZl	\N	\N	1783625564152	\N	f
12	@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	syt_YWxpcGF6_LPgkFYTguydoyiTYTumo_3GUZ3Z	\N	\N	1783627041638	\N	t
13	@monir:matrix.shikpooshaan.ir	CAOSKJQGSV	syt_bW9uaXI_TQKTDyTSpGPrRhNkobFO_0e2Ozf	\N	\N	1783627463362	\N	f
14	@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	syt_bW9uaXI_ThRpFyvLvmUlyTkGNgOC_0oZflN	\N	\N	1783627502555	\N	t
15	@aa0922ny:matrix.shikpooshaan.ir	BOOHWYAZFZ	syt_YWEwOTIybnk_HKdMnPElsLmEZXrFedtb_3SI51N	\N	\N	1783628161399	\N	f
16	@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	syt_YWxleC10YXlsb3I_pLQjkRkxGWMsucXnoIiB_4dI8LT	\N	\N	1783667620892	\N	t
10	@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	syt_YWxleHRheWxvcjk4_IXeZrfDMuGZGDEHFzjZM_0aT6mb	\N	\N	1783625580492	\N	t
17	@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	syt_YWxleHRheWxvcjk4_RxhGRYLCjJMTuYkJENro_0vujPJ	\N	\N	1783671837403	\N	t
19	@brian:matrix.shikpooshaan.ir	XSUPBBJATQ	syt_YnJpYW4_HBXuRQhklzfMwDCdNGgk_2elhfw	\N	\N	1783672033781	\N	f
20	@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	syt_YnJpYW4_DfefGINhIqmpDrPzocmq_4GCYMs	\N	\N	1783672182396	\N	t
\.


--
-- Data for Name: account_data; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.account_data (user_id, account_data_type, stream_id, content, instance_name) FROM stdin;
@ali:matrix.shikpooshaan.ir	org.matrix.msc3890.local_notification_settings.WGYBGBWZQI	3	{"is_silenced":false}	\N
@brianrockwell:matrix.shikpooshaan.ir	m.key_backup	6	{"enabled":true}	\N
@brianrockwell:matrix.shikpooshaan.ir	m.org.matrix.custom.backup_disabled	7	{"disabled":false}	\N
@ali:matrix.shikpooshaan.ir	io.element.recovery	10	{"enabled":false}	\N
@ali:matrix.shikpooshaan.ir	im.vector.analytics	11	{"pseudonymousAnalyticsOptIn":false}	\N
@ali:matrix.shikpooshaan.ir	im.vector.web.settings	12	{"releaseAnnouncementData":{"room_list_section":true}}	\N
@alextaylor98:matrix.shikpooshaan.ir	m.key_backup	24	{"enabled":true}	\N
@alextaylor98:matrix.shikpooshaan.ir	m.org.matrix.custom.backup_disabled	25	{"disabled":false}	\N
@brianrockwell:matrix.shikpooshaan.ir	m.direct	31	{"@alextaylor98:matrix.shikpooshaan.ir":["!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir"],"@ali:matrix.shikpooshaan.ir":["!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir"]}	\N
@alex-taylor:matrix.shikpooshaan.ir	m.key_backup	46	{"enabled":true}	\N
@alex-taylor:matrix.shikpooshaan.ir	m.org.matrix.custom.backup_disabled	47	{"disabled":false}	\N
@ali:matrix.shikpooshaan.ir	im.vector.setting.breadcrumbs	49	{"recent_rooms":["!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir","!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir","!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir"]}	\N
@ali:matrix.shikpooshaan.ir	m.direct	52	{"@brianrockwell:matrix.shikpooshaan.ir":["!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir"],"@alex-taylor:matrix.shikpooshaan.ir":["!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir"]}	\N
@alipaz:matrix.shikpooshaan.ir	org.matrix.msc3890.local_notification_settings.SPEPVPSHPR	54	{"is_silenced":false}	\N
@alipaz:matrix.shikpooshaan.ir	io.element.recovery	56	{"enabled":false}	\N
@alipaz:matrix.shikpooshaan.ir	im.vector.web.settings	58	{"releaseAnnouncementData":{"room_list_section":true}}	\N
@alipaz:matrix.shikpooshaan.ir	m.direct	60	{"@alex-taylor:matrix.shikpooshaan.ir":["!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir"]}	\N
@alipaz:matrix.shikpooshaan.ir	im.vector.setting.breadcrumbs	62	{"recent_rooms":["!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir","local+m1783627126262.0"]}	\N
@monir:matrix.shikpooshaan.ir	org.matrix.msc3890.local_notification_settings.WGFMZTWZEK	65	{"is_silenced":false}	\N
@alex-taylor:matrix.shikpooshaan.ir	m.secret_storage.key.2p3H0Bs80SVwSzzxSEajw6RKJ88gZDzF	67	{"algorithm":"m.secret_storage.v1.aes-hmac-sha2","iv":"yH9/txNiVSlKRDxXX+bOCw","mac":"Hpn9eQKEv8uj1OcAUFYBRTj3k4NfrEiERp9YeZxeAbg"}	\N
@alex-taylor:matrix.shikpooshaan.ir	m.cross_signing.master	68	{"encrypted":{"2p3H0Bs80SVwSzzxSEajw6RKJ88gZDzF":{"iv":"JKqjX+w9UVoWeBRfP9eTXg","ciphertext":"QG8LwFgieiOYlk1AamDa6YDcgUvZB77mbOpvXg9yqpzn07fa0gIosp7ctg","mac":"RtbAgeSSO0phQqYjWaeaxTSXW6Wr43JR9fPE3F4GIAU"}}}	\N
@alex-taylor:matrix.shikpooshaan.ir	m.cross_signing.user_signing	69	{"encrypted":{"2p3H0Bs80SVwSzzxSEajw6RKJ88gZDzF":{"iv":"8wK/iC9z8h1CAsEYa0mWaQ","ciphertext":"WFFfqIKJMUkUsudhjM3HBOH/mhL6GsiQcmX7VoJAYqMoGjehWehg4/2EYg","mac":"fRjwIkNwEbPY0OlVAEAPbQGGpE5a4yJvX0dfXPkwfUc"}}}	\N
@alex-taylor:matrix.shikpooshaan.ir	m.cross_signing.self_signing	70	{"encrypted":{"2p3H0Bs80SVwSzzxSEajw6RKJ88gZDzF":{"iv":"f/Jmmy9I6YsEhTuDeQ3iNw","ciphertext":"nRAu5Y+GPYbzqFauLtUPqtEVQ9RyK4GZTDfswARXtBz1yO1Buc6W1RLCxg","mac":"wxDVoSjMD/l1P6i+pEBTfUmQBaZxzs29ccU4Wu4USSE"}}}	\N
@alex-taylor:matrix.shikpooshaan.ir	m.megolm_backup.v1	71	{"encrypted":{"2p3H0Bs80SVwSzzxSEajw6RKJ88gZDzF":{"iv":"QoFwxocGw4dBj3ecXuR3/g","ciphertext":"m/RbZuegyPeG8JvlQ1SnmVqxIUkMPDtfJB0+/fMlKjrc1Y5neC3lhG0TKg","mac":"qTsyPebxgBU3kF0hxRwwsYrJ4X0AHHyFklpiLNj8UCM"}}}	\N
@alex-taylor:matrix.shikpooshaan.ir	m.secret_storage.default_key	72	{"key":"2p3H0Bs80SVwSzzxSEajw6RKJ88gZDzF"}	\N
@alex-taylor:matrix.shikpooshaan.ir	m.direct	76	{"@alextaylor98:matrix.shikpooshaan.ir":["!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir"],"@alextaylor:matrix.shikpooshaan.ir":["!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir"],"@ali:matrix.shikpooshaan.ir":["!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir"],"@alipaz:matrix.shikpooshaan.ir":["!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir"]}	\N
@alextaylor98:matrix.shikpooshaan.ir	org.matrix.msc3890.local_notification_settings.CEAAYOLHOD	86	{"is_silenced":false}	\N
@alextaylor98:matrix.shikpooshaan.ir	m.cross_signing.master	87	{}	\N
@alextaylor98:matrix.shikpooshaan.ir	m.cross_signing.self_signing	88	{}	\N
@alextaylor98:matrix.shikpooshaan.ir	m.cross_signing.user_signing	89	{}	\N
@alextaylor98:matrix.shikpooshaan.ir	m.megolm_backup.v1	90	{}	\N
@alextaylor98:matrix.shikpooshaan.ir	m.secret_storage.default_key	91	{}	\N
@alextaylor98:matrix.shikpooshaan.ir	io.element.recovery	92	{"enabled":false}	\N
@alextaylor98:matrix.shikpooshaan.ir	im.vector.analytics	93	{"pseudonymousAnalyticsOptIn":false}	\N
@brian:matrix.shikpooshaan.ir	m.key_backup	94	{"enabled":true}	\N
@brian:matrix.shikpooshaan.ir	m.org.matrix.custom.backup_disabled	95	{"disabled":false}	\N
@brian:matrix.shikpooshaan.ir	m.direct	96	{"@alextaylor98:matrix.shikpooshaan.ir":["!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir"]}	\N
@alextaylor98:matrix.shikpooshaan.ir	m.direct	97	{"@alex-taylor:matrix.shikpooshaan.ir":["!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir"],"@brian:matrix.shikpooshaan.ir":["!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir"],"@brianrockwell:matrix.shikpooshaan.ir":["!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir"]}	\N
@alextaylor98:matrix.shikpooshaan.ir	im.vector.web.settings	100	{"releaseAnnouncementData":{"room_list_section":true}}	\N
@alextaylor98:matrix.shikpooshaan.ir	im.vector.setting.breadcrumbs	101	{"recent_rooms":["!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir"]}	\N
\.


--
-- Data for Name: account_validity; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.account_validity (user_id, expiration_ts_ms, email_sent, renewal_token, token_used_ts_ms) FROM stdin;
\.


--
-- Data for Name: application_services_state; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.application_services_state (as_id, state, read_receipt_stream_id, presence_stream_id, to_device_stream_id, device_list_stream_id) FROM stdin;
\.


--
-- Data for Name: application_services_txns; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.application_services_txns (as_id, txn_id, event_ids) FROM stdin;
\.


--
-- Data for Name: applied_module_schemas; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.applied_module_schemas (module_name, file) FROM stdin;
\.


--
-- Data for Name: applied_schema_deltas; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.applied_schema_deltas (version, file) FROM stdin;
73	73/01event_failed_pull_attempts.sql
73	73/02add_pusher_enabled.sql
73	73/02room_id_indexes_for_purging.sql
73	73/03pusher_device_id.sql
73	73/03users_approved_column.sql
73	73/04partial_join_details.sql
73	73/04pending_device_list_updates.sql
73	73/05old_push_actions.sql.postgres
73	73/06thread_notifications_thread_id_idx.sql
73	73/08thread_receipts_non_null.sql.postgres
73	73/09partial_joined_via_destination.sql
73	73/09threads_table.sql
73	73/10_update_sqlite_fts4_tokenizer.py
73	73/10login_tokens.sql
73	73/11event_search_room_id_n_distinct.sql.postgres
73	73/12refactor_device_list_outbound_pokes.sql
73	73/13add_device_lists_index.sql
73	73/20_un_partial_stated_room_stream.sql
73	73/21_un_partial_stated_room_stream_seq.sql.postgres
73	73/22_rebuild_user_dir_stats.sql
73	73/22_un_partial_stated_event_stream.sql
73	73/23_fix_thread_index.sql
73	73/23_un_partial_stated_room_stream_seq.sql.postgres
73	73/24_events_jump_to_date_index.sql
73	73/25drop_presence.sql
74	74/01_user_directory_stale_remote_users.sql
74	74/02_set_device_id_for_pushers_bg_update.sql
74	74/03_membership_tables_event_stream_ordering.sql.postgres
74	74/03_room_membership_index.sql
74	74/04_delete_e2e_backup_keys_for_deactivated_users.sql
74	74/04_membership_tables_event_stream_ordering_triggers.py
74	74/05_events_txn_id_device_id.sql
74	74/90COMMENTS_destinations.sql.postgres
76	76/01_add_profiles_full_user_id_column.sql
76	76/02_add_user_filters_full_user_id_column.sql
76	76/03_per_user_experimental_features.sql
76	76/04_add_room_forgetter.sql
77	77/01_add_profiles_not_valid_check.sql.postgres
77	77/02_add_user_filters_not_valid_check.sql.postgres
77	77/03bg_populate_full_user_id_profiles.sql
77	77/04bg_populate_full_user_id_user_filters.sql
77	77/05thread_notifications_backfill.sql
77	77/06thread_notifications_not_null_event_push_actions.sql.postgres
77	77/06thread_notifications_not_null_event_push_actions_staging.sql.postgres
77	77/06thread_notifications_not_null_event_push_summary.sql.postgres
77	77/14bg_indices_event_stream_ordering.sql
78	78/01_validate_and_update_profiles.py
78	78/02_validate_and_update_user_filters.py
78	78/03_remove_unused_indexes_user_filters.py
78	78/03event_extremities_constraints.py
78	78/04_add_full_user_id_index_user_filters.py
79	79/03_read_write_locks_triggers.sql.postgres
79	79/04_mitigate_stream_ordering_update_race.py
79	79/05_read_write_locks_triggers.sql.postgres
80	80/01_users_alter_locked.sql
80	80/02_read_write_locks_unlogged.sql.postgres
80	80/02_scheduled_tasks.sql
80	80/03_read_write_locks_triggers.sql.postgres
80	80/04_read_write_locks_deadlock.sql.postgres
82	82/02_scheduled_tasks_index.sql
82	82/04_add_indices_for_purging_rooms.sql
82	82/05gaps.sql
83	83/01_drop_old_tables.sql
83	83/05_cross_signing_key_update_grant.sql
83	83/06_event_push_summary_room.sql
84	84/01_auth_links_stats.sql.postgres
84	84/02_auth_links_index.sql
84	84/03_auth_links_analyze.sql.postgres
84	84/04_access_token_index.sql
85	85/01_add_suspended.sql
85	85/02_add_instance_names.sql
85	85/03_new_sequences.sql.postgres
85	85/04_cleanup_device_federation_outbox.sql
85	85/05_add_instance_names_converted_pos.sql
85	85/06_add_room_reports.sql
86	86/01_authenticate_media.sql
86	86/02_receipts_event_id_index.sql
87	87/01_sliding_sync_memberships.sql
87	87/02_per_connection_state.sql
87	87/03_current_state_index.sql
88	88/01_add_delayed_events.sql
88	88/01_custom_profile_fields.sql
88	88/02_fix_sliding_sync_membership_snapshots_forgotten_column.sql
88	88/03_add_otk_ts_added_index.sql
88	88/04_current_state_delta_index.sql
88	88/05_drop_old_otks.sql.postgres
88	88/05_sliding_sync_room_config_index.sql
88	88/06_events_received_ts_index.sql
89	89/01_sliding_sync_membership_snapshot_index.sql
89	89/01_state_groups_deletion.sql
90	90/01_add_column_participant_room_memberships_table.sql
90	90/02_delete_unreferenced_state_groups.sql
90	90/03_remove_old_deletion_bg_update.sql
91	91/01_media_hash.sql
92	92/01_remove_trigger.sql.postgres
92	92/02_remove_populate_participant_bg_update.sql
92	92/04_ss_membership_snapshot_idx.sql
92	92/04_thread_subscriptions.sql
92	92/04_thread_subscriptions_seq.sql.postgres
92	92/05_fixup_max_depth_cap.sql
92	92/05_thread_subscriptions_comments.sql.postgres
92	92/06_device_federation_inbox_index.sql
92	92/06_threads_last_sent_stream_ordering_comments.sql.postgres
92	92/07_add_user_reports.sql
92	92/07_event_txn_id_device_id_txn_id2.sql
92	92/08_room_ban_redactions.sql
92	92/08_thread_subscriptions_seq_fixup.sql.postgres
92	92/09_thread_subscriptions_update.sql
92	92/09_thread_subscriptions_update.sql.postgres
93	93/01_add_delayed_events.sql
93	93/01_sticky_events.sql
93	93/01_sticky_events_seq.sql.postgres
93	93/02_sliding_sync_members.sql
93	93/03_sss_pos_last_used.sql
93	93/04_make_delayed_event_content_text.py
94	94/01_redactions_recheck.sql
94	94/02_redactions_recheck_bg_update.sql
94	94/03_device_lists_room_timestamp.sql
94	94/03_quarantined_media_tracking.sql
94	94/03_quarantined_media_tracking_seq.sql.postgres
94	94/03_state_dag_fwd_extrems.sql
94	94/04_device_lists_changes_max_pruned.sql
\.


--
-- Data for Name: appservice_room_list; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.appservice_room_list (appservice_id, network_id, room_id) FROM stdin;
\.


--
-- Data for Name: appservice_stream_position; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.appservice_stream_position (lock, stream_ordering) FROM stdin;
X	0
\.


--
-- Data for Name: background_updates; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.background_updates (update_name, progress_json, depends_on, ordering) FROM stdin;
\.


--
-- Data for Name: blocked_rooms; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.blocked_rooms (room_id, user_id) FROM stdin;
\.


--
-- Data for Name: cache_invalidation_stream_by_instance; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.cache_invalidation_stream_by_instance (stream_id, instance_name, cache_func, keys, invalidation_ts) FROM stdin;
2	master	user_last_seen_monthly_active	\N	1783624292298
3	master	get_monthly_active_count	{}	1783624292316
4	master	user_last_seen_monthly_active	\N	1783624307050
5	master	get_monthly_active_count	{}	1783624307054
6	master	get_user_by_id	{@alextaylor:matrix.shikpooshaan.ir}	1783624770212
7	master	get_device	{@alextaylor:matrix.shikpooshaan.ir,SAWFHDVRYA}	1783624770256
8	master	get_user_by_id	{@ali:matrix.shikpooshaan.ir}	1783624935850
9	master	get_device	{@ali:matrix.shikpooshaan.ir,DRPHZPCPVD}	1783624935898
10	master	get_device	{@ali:matrix.shikpooshaan.ir,WGYBGBWZQI}	1783624974977
11	master	get_device	{@ali:matrix.shikpooshaan.ir,WGYBGBWZQI}	1783624982880
12	master	count_e2e_one_time_keys	{@ali:matrix.shikpooshaan.ir,WGYBGBWZQI}	1783624982920
13	master	get_e2e_unused_fallback_key_types	{@ali:matrix.shikpooshaan.ir,WGYBGBWZQI}	1783624982945
14	master	get_device	{@ali:matrix.shikpooshaan.ir,WGYBGBWZQI}	1783624983341
15	master	count_e2e_one_time_keys	{@ali:matrix.shikpooshaan.ir,WGYBGBWZQI}	1783624983361
16	master	get_e2e_unused_fallback_key_types	{@ali:matrix.shikpooshaan.ir,WGYBGBWZQI}	1783624983378
17	master	_get_bare_e2e_cross_signing_keys	{@ali:matrix.shikpooshaan.ir}	1783624984426
18	master	_get_bare_e2e_cross_signing_keys	{@ali:matrix.shikpooshaan.ir}	1783624984444
19	master	_get_bare_e2e_cross_signing_keys	{@ali:matrix.shikpooshaan.ir}	1783624984461
20	master	get_user_by_id	{@alex-taylor:matrix.shikpooshaan.ir}	1783625058031
21	master	get_device	{@alex-taylor:matrix.shikpooshaan.ir,CRYINYFIHK}	1783625058062
22	master	get_user_by_id	{@brianrockwell:matrix.shikpooshaan.ir}	1783625084777
23	master	get_device	{@brianrockwell:matrix.shikpooshaan.ir,AVTTVCQSYF}	1783625084805
24	master	get_device	{@alex-taylor:matrix.shikpooshaan.ir,HPQGRDHEVK}	1783625109586
25	master	get_device	{@alex-taylor:matrix.shikpooshaan.ir,HPQGRDHEVK}	1783625111354
26	master	count_e2e_one_time_keys	{@alex-taylor:matrix.shikpooshaan.ir,HPQGRDHEVK}	1783625111414
27	master	get_device	{@alex-taylor:matrix.shikpooshaan.ir,HPQGRDHEVK}	1783625111426
28	master	count_e2e_one_time_keys	{@alex-taylor:matrix.shikpooshaan.ir,HPQGRDHEVK}	1783625111467
29	master	_get_bare_e2e_cross_signing_keys	{@alex-taylor:matrix.shikpooshaan.ir}	1783625111867
30	master	_get_bare_e2e_cross_signing_keys	{@alex-taylor:matrix.shikpooshaan.ir}	1783625111883
31	master	_get_bare_e2e_cross_signing_keys	{@alex-taylor:matrix.shikpooshaan.ir}	1783625111906
32	master	get_if_user_has_pusher	{@alex-taylor:matrix.shikpooshaan.ir}	1783625114135
33	master	get_device	{@alex-taylor:matrix.shikpooshaan.ir}	1783625155898
34	master	count_e2e_one_time_keys	{@alex-taylor:matrix.shikpooshaan.ir}	1783625155899
35	master	get_e2e_unused_fallback_key_types	{@alex-taylor:matrix.shikpooshaan.ir}	1783625155901
36	master	get_user_by_access_token	{syt_YWxleC10YXlsb3I_MzbdOSwHsgrWWPoTjuzQ_337zkC}	1783625155924
37	master	get_if_user_has_pusher	{@alex-taylor:matrix.shikpooshaan.ir}	1783625155948
38	master	get_device	{@brianrockwell:matrix.shikpooshaan.ir,KYQHVGSULI}	1783625206478
39	master	get_device	{@brianrockwell:matrix.shikpooshaan.ir,KYQHVGSULI}	1783625208224
40	master	get_device	{@brianrockwell:matrix.shikpooshaan.ir,KYQHVGSULI}	1783625208247
41	master	count_e2e_one_time_keys	{@brianrockwell:matrix.shikpooshaan.ir,KYQHVGSULI}	1783625208274
42	master	count_e2e_one_time_keys	{@brianrockwell:matrix.shikpooshaan.ir,KYQHVGSULI}	1783625208302
43	master	_get_bare_e2e_cross_signing_keys	{@brianrockwell:matrix.shikpooshaan.ir}	1783625208629
44	master	_get_bare_e2e_cross_signing_keys	{@brianrockwell:matrix.shikpooshaan.ir}	1783625208640
45	master	_get_bare_e2e_cross_signing_keys	{@brianrockwell:matrix.shikpooshaan.ir}	1783625208653
46	master	count_e2e_one_time_keys	{@brianrockwell:matrix.shikpooshaan.ir,KYQHVGSULI}	1783625208884
47	master	get_e2e_unused_fallback_key_types	{@brianrockwell:matrix.shikpooshaan.ir,KYQHVGSULI}	1783625208907
48	master	get_if_user_has_pusher	{@brianrockwell:matrix.shikpooshaan.ir}	1783625211048
49	master	cs_cache_fake	{!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir}	1783625247996
50	master	cs_cache_fake	{!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir,@brianrockwell:matrix.shikpooshaan.ir}	1783625248208
51	master	cs_cache_fake	{!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir}	1783625248625
52	master	cs_cache_fake	{!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir,@ali:matrix.shikpooshaan.ir}	1783625248865
53	master	cs_cache_fake	{!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir,@ali:matrix.shikpooshaan.ir}	1783625265400
54	master	user_last_seen_monthly_active	\N	1783625330758
55	master	get_monthly_active_count	{}	1783625330785
56	master	get_if_user_has_pusher	{@brianrockwell:matrix.shikpooshaan.ir}	1783625366494
57	master	get_if_user_has_pusher	{@brianrockwell:matrix.shikpooshaan.ir}	1783625424499
58	master	count_e2e_one_time_keys	{@brianrockwell:matrix.shikpooshaan.ir,KYQHVGSULI}	1783625441853
59	master	get_user_by_id	{@alextaylor98:matrix.shikpooshaan.ir}	1783625564084
60	master	get_device	{@alextaylor98:matrix.shikpooshaan.ir,GZIPKPHOVU}	1783625564114
61	master	get_device	{@alextaylor98:matrix.shikpooshaan.ir,NFLNJMUACW}	1783625580471
62	master	get_device	{@alextaylor98:matrix.shikpooshaan.ir,NFLNJMUACW}	1783625580920
66	master	count_e2e_one_time_keys	{@alextaylor98:matrix.shikpooshaan.ir,NFLNJMUACW}	1783625581089
67	master	count_e2e_one_time_keys	{@alextaylor98:matrix.shikpooshaan.ir,NFLNJMUACW}	1783625581167
72	master	cs_cache_fake	{!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir,@brianrockwell:matrix.shikpooshaan.ir}	1783625679572
77	master	cs_cache_fake	{!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir,@brianrockwell:matrix.shikpooshaan.ir}	1783625720713
78	master	get_if_user_has_pusher	{@alextaylor98:matrix.shikpooshaan.ir}	1783625869698
80	master	get_if_user_has_pusher	{@alextaylor98:matrix.shikpooshaan.ir}	1783626185108
93	master	get_if_user_has_pusher	{@alextaylor98:matrix.shikpooshaan.ir}	1783626691842
96	master	count_e2e_one_time_keys	{@alex-taylor:matrix.shikpooshaan.ir,OFUSOVXTZJ}	1783626748123
105	master	cs_cache_fake	{!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir,@alex-taylor:matrix.shikpooshaan.ir}	1783626825411
108	master	cs_cache_fake	{!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir,@ali:matrix.shikpooshaan.ir}	1783626835450
111	master	get_device	{@alipaz:matrix.shikpooshaan.ir,SPEPVPSHPR}	1783627062081
113	master	get_e2e_unused_fallback_key_types	{@alipaz:matrix.shikpooshaan.ir,SPEPVPSHPR}	1783627062127
114	master	get_device	{@alipaz:matrix.shikpooshaan.ir,SPEPVPSHPR}	1783627062237
115	master	count_e2e_one_time_keys	{@alipaz:matrix.shikpooshaan.ir,SPEPVPSHPR}	1783627062267
117	master	_get_bare_e2e_cross_signing_keys	{@alipaz:matrix.shikpooshaan.ir}	1783627063320
63	master	get_if_user_has_pusher	{@alextaylor98:matrix.shikpooshaan.ir}	1783625580945
64	master	count_e2e_one_time_keys	{@alextaylor98:matrix.shikpooshaan.ir,NFLNJMUACW}	1783625580989
68	master	get_e2e_unused_fallback_key_types	{@alextaylor98:matrix.shikpooshaan.ir,NFLNJMUACW}	1783625581184
70	master	_get_bare_e2e_cross_signing_keys	{@alextaylor98:matrix.shikpooshaan.ir}	1783625581229
73	master	cs_cache_fake	{!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir}	1783625715154
79	master	get_if_user_has_pusher	{@brianrockwell:matrix.shikpooshaan.ir}	1783625878213
81	master	get_if_user_has_pusher	{@brianrockwell:matrix.shikpooshaan.ir}	1783626191395
85	master	cs_cache_fake	{!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir}	1783626314974
94	master	get_device	{@alex-taylor:matrix.shikpooshaan.ir,OFUSOVXTZJ}	1783626746366
95	master	get_device	{@alex-taylor:matrix.shikpooshaan.ir,OFUSOVXTZJ}	1783626748089
102	master	_get_e2e_cross_signing_signatures_for_device	{"[\\"@alex-taylor:matrix.shikpooshaan.ir\\", \\"OFUSOVXTZJ\\"]"}	1783626798175
109	master	get_user_by_id	{@alipaz:matrix.shikpooshaan.ir}	1783627041558
112	master	count_e2e_one_time_keys	{@alipaz:matrix.shikpooshaan.ir,SPEPVPSHPR}	1783627062110
65	master	get_device	{@alextaylor98:matrix.shikpooshaan.ir,NFLNJMUACW}	1783625581045
91	master	get_user_by_access_token	{syt_YnJpYW5yb2Nrd2VsbA_YMQnaUBzwbWbOFkyBBcO_24gRQQ}	1783626429863
98	master	get_e2e_unused_fallback_key_types	{@alex-taylor:matrix.shikpooshaan.ir,OFUSOVXTZJ}	1783626748718
101	master	_get_bare_e2e_cross_signing_keys	{@alex-taylor:matrix.shikpooshaan.ir}	1783626797832
69	master	_get_bare_e2e_cross_signing_keys	{@alextaylor98:matrix.shikpooshaan.ir}	1783625581215
76	master	cs_cache_fake	{!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir,@brianrockwell:matrix.shikpooshaan.ir}	1783625715989
103	master	get_if_user_has_pusher	{@alex-taylor:matrix.shikpooshaan.ir}	1783626801795
110	master	get_device	{@alipaz:matrix.shikpooshaan.ir,SPEPVPSHPR}	1783627041605
116	master	get_e2e_unused_fallback_key_types	{@alipaz:matrix.shikpooshaan.ir,SPEPVPSHPR}	1783627062285
71	master	_get_bare_e2e_cross_signing_keys	{@alextaylor98:matrix.shikpooshaan.ir}	1783625581248
75	master	cs_cache_fake	{!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir}	1783625715712
99	master	_get_bare_e2e_cross_signing_keys	{@alex-taylor:matrix.shikpooshaan.ir}	1783626797799
104	master	cs_cache_fake	{!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir}	1783626825151
119	master	_get_bare_e2e_cross_signing_keys	{@alipaz:matrix.shikpooshaan.ir}	1783627063366
74	master	cs_cache_fake	{!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir,@alextaylor98:matrix.shikpooshaan.ir}	1783625715323
82	master	get_if_user_has_pusher	{@brianrockwell:matrix.shikpooshaan.ir}	1783626231506
83	master	cs_cache_fake	{!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir}	1783626314435
84	master	cs_cache_fake	{!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir,@brianrockwell:matrix.shikpooshaan.ir}	1783626314616
86	master	cs_cache_fake	{!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir,@ali:matrix.shikpooshaan.ir}	1783626315195
87	master	cs_cache_fake	{!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir,@ali:matrix.shikpooshaan.ir}	1783626325299
88	master	get_device	{@brianrockwell:matrix.shikpooshaan.ir}	1783626429834
89	master	count_e2e_one_time_keys	{@brianrockwell:matrix.shikpooshaan.ir}	1783626429836
90	master	get_e2e_unused_fallback_key_types	{@brianrockwell:matrix.shikpooshaan.ir}	1783626429837
92	master	get_if_user_has_pusher	{@brianrockwell:matrix.shikpooshaan.ir}	1783626429891
97	master	count_e2e_one_time_keys	{@alex-taylor:matrix.shikpooshaan.ir,OFUSOVXTZJ}	1783626748698
100	master	_get_bare_e2e_cross_signing_keys	{@alex-taylor:matrix.shikpooshaan.ir}	1783626797816
106	master	cs_cache_fake	{!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir}	1783626825885
107	master	cs_cache_fake	{!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir,@ali:matrix.shikpooshaan.ir}	1783626826176
118	master	_get_bare_e2e_cross_signing_keys	{@alipaz:matrix.shikpooshaan.ir}	1783627063340
120	master	cs_cache_fake	{!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir}	1783627136084
121	master	cs_cache_fake	{!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir,@alipaz:matrix.shikpooshaan.ir}	1783627136264
122	master	cs_cache_fake	{!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir}	1783627136592
123	master	cs_cache_fake	{!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir,@alex-taylor:matrix.shikpooshaan.ir}	1783627136854
124	master	cs_cache_fake	{!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir,@alex-taylor:matrix.shikpooshaan.ir}	1783627139116
125	master	count_e2e_one_time_keys	{@alex-taylor:matrix.shikpooshaan.ir,OFUSOVXTZJ}	1783627140900
126	master	get_user_by_id	{@monir:matrix.shikpooshaan.ir}	1783627463297
127	master	get_device	{@monir:matrix.shikpooshaan.ir,CAOSKJQGSV}	1783627463336
128	master	get_device	{@monir:matrix.shikpooshaan.ir,WGFMZTWZEK}	1783627502534
129	master	get_device	{@monir:matrix.shikpooshaan.ir,WGFMZTWZEK}	1783627509960
130	master	get_device	{@monir:matrix.shikpooshaan.ir,WGFMZTWZEK}	1783627510015
131	master	count_e2e_one_time_keys	{@monir:matrix.shikpooshaan.ir,WGFMZTWZEK}	1783627510018
132	master	get_e2e_unused_fallback_key_types	{@monir:matrix.shikpooshaan.ir,WGFMZTWZEK}	1783627510047
133	master	count_e2e_one_time_keys	{@monir:matrix.shikpooshaan.ir,WGFMZTWZEK}	1783627510055
134	master	get_e2e_unused_fallback_key_types	{@monir:matrix.shikpooshaan.ir,WGFMZTWZEK}	1783627510081
135	master	_get_bare_e2e_cross_signing_keys	{@monir:matrix.shikpooshaan.ir}	1783627511118
136	master	_get_bare_e2e_cross_signing_keys	{@monir:matrix.shikpooshaan.ir}	1783627511136
137	master	_get_bare_e2e_cross_signing_keys	{@monir:matrix.shikpooshaan.ir}	1783627511153
138	master	get_user_by_id	{@aa0922ny:matrix.shikpooshaan.ir}	1783628161338
139	master	get_device	{@aa0922ny:matrix.shikpooshaan.ir,BOOHWYAZFZ}	1783628161367
140	master	user_last_seen_monthly_active	\N	1783628930602
141	master	get_monthly_active_count	{}	1783628930604
142	master	get_if_user_has_pusher	{@alextaylor98:matrix.shikpooshaan.ir}	1783629278745
143	master	user_last_seen_monthly_active	\N	1783632530602
144	master	get_monthly_active_count	{}	1783632530604
145	master	get_if_user_has_pusher	{@alex-taylor:matrix.shikpooshaan.ir}	1783635465384
146	master	get_if_user_has_pusher	{@alex-taylor:matrix.shikpooshaan.ir}	1783635480638
147	master	user_last_seen_monthly_active	\N	1783636130604
148	master	get_monthly_active_count	{}	1783636130606
149	master	user_last_seen_monthly_active	\N	1783639730609
150	master	get_monthly_active_count	{}	1783639730611
151	master	user_last_seen_monthly_active	\N	1783643330606
152	master	get_monthly_active_count	{}	1783643330632
153	master	user_last_seen_monthly_active	\N	1783646930630
154	master	get_monthly_active_count	{}	1783646930640
155	master	user_last_seen_monthly_active	\N	1783650530717
156	master	get_monthly_active_count	{}	1783650530734
157	master	user_last_seen_monthly_active	\N	1783654130605
158	master	get_monthly_active_count	{}	1783654130609
159	master	user_last_seen_monthly_active	\N	1783657730600
160	master	get_monthly_active_count	{}	1783657730603
161	master	user_last_seen_monthly_active	\N	1783661330610
162	master	get_monthly_active_count	{}	1783661330615
163	master	user_last_seen_monthly_active	\N	1783664930599
164	master	get_monthly_active_count	{}	1783664930602
165	master	get_if_user_has_pusher	{@alex-taylor:matrix.shikpooshaan.ir}	1783667435849
166	master	get_device	{@alex-taylor:matrix.shikpooshaan.ir}	1783667563794
167	master	count_e2e_one_time_keys	{@alex-taylor:matrix.shikpooshaan.ir}	1783667563804
168	master	get_e2e_unused_fallback_key_types	{@alex-taylor:matrix.shikpooshaan.ir}	1783667563805
169	master	get_user_by_access_token	{syt_YWxleC10YXlsb3I_TYsjHasChExFPdRvYTFY_0auyiV}	1783667563938
170	master	get_if_user_has_pusher	{@alex-taylor:matrix.shikpooshaan.ir}	1783667564034
173	master	count_e2e_one_time_keys	{@alex-taylor:matrix.shikpooshaan.ir,CHFTPUHNYF}	1783667623413
178	master	user_last_seen_monthly_active	\N	1783668530601
179	master	get_monthly_active_count	{}	1783668530605
171	master	get_device	{@alex-taylor:matrix.shikpooshaan.ir,CHFTPUHNYF}	1783667620807
174	master	count_e2e_one_time_keys	{@alex-taylor:matrix.shikpooshaan.ir,CHFTPUHNYF}	1783667624362
181	master	cs_cache_fake	{!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir,@alex-taylor:matrix.shikpooshaan.ir}	1783669887585
182	master	cs_cache_fake	{!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir,@alex-taylor:matrix.shikpooshaan.ir}	1783669888711
172	master	get_device	{@alex-taylor:matrix.shikpooshaan.ir,CHFTPUHNYF}	1783667622860
175	master	get_e2e_unused_fallback_key_types	{@alex-taylor:matrix.shikpooshaan.ir,CHFTPUHNYF}	1783667624485
176	master	_get_e2e_cross_signing_signatures_for_device	{"[\\"@alex-taylor:matrix.shikpooshaan.ir\\", \\"CHFTPUHNYF\\"]"}	1783667634024
177	master	get_if_user_has_pusher	{@alex-taylor:matrix.shikpooshaan.ir}	1783667639488
180	master	get_if_user_has_pusher	{@alex-taylor:matrix.shikpooshaan.ir}	1783669607025
183	master	cs_cache_fake	{!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir,@alex-taylor:matrix.shikpooshaan.ir}	1783669998288
184	master	cs_cache_fake	{!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir,@alex-taylor:matrix.shikpooshaan.ir}	1783669998765
185	master	cs_cache_fake	{!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir}	1783670157045
186	master	cs_cache_fake	{!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir,@alex-taylor:matrix.shikpooshaan.ir}	1783670157465
187	master	cs_cache_fake	{!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir}	1783670158425
188	master	cs_cache_fake	{!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir,@alextaylor:matrix.shikpooshaan.ir}	1783670158834
189	master	cs_cache_fake	{!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir}	1783670197872
190	master	cs_cache_fake	{!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir,@alex-taylor:matrix.shikpooshaan.ir}	1783670198063
191	master	cs_cache_fake	{!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir}	1783670198504
192	master	cs_cache_fake	{!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir,@alextaylor98:matrix.shikpooshaan.ir}	1783670198792
193	master	cs_cache_fake	{!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir,@alextaylor98:matrix.shikpooshaan.ir}	1783670202009
194	master	count_e2e_one_time_keys	{@alex-taylor:matrix.shikpooshaan.ir,CHFTPUHNYF}	1783670208368
195	master	cs_cache_fake	{!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir,@alextaylor98:matrix.shikpooshaan.ir}	1783670495694
196	master	cs_cache_fake	{!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir,@alextaylor98:matrix.shikpooshaan.ir}	1783670495991
197	master	get_if_user_has_pusher	{@alex-taylor:matrix.shikpooshaan.ir}	1783671102858
198	master	cs_cache_fake	{!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir,@alextaylor98:matrix.shikpooshaan.ir}	1783671328843
199	master	get_device	{@ali:matrix.shikpooshaan.ir}	1783671622063
200	master	count_e2e_one_time_keys	{@ali:matrix.shikpooshaan.ir}	1783671622065
201	master	get_e2e_unused_fallback_key_types	{@ali:matrix.shikpooshaan.ir}	1783671622066
202	master	get_user_by_access_token	{syt_YWxp_gJELLPHxEfAqNykGIbFf_040SC8}	1783671622090
203	master	get_device	{@alextaylor98:matrix.shikpooshaan.ir,CEAAYOLHOD}	1783671786851
204	master	get_device	{@alextaylor98:matrix.shikpooshaan.ir,CEAAYOLHOD}	1783671796310
205	master	count_e2e_one_time_keys	{@alextaylor98:matrix.shikpooshaan.ir,CEAAYOLHOD}	1783671796371
206	master	get_e2e_unused_fallback_key_types	{@alextaylor98:matrix.shikpooshaan.ir,CEAAYOLHOD}	1783671796389
207	master	_get_e2e_cross_signing_signatures_for_device	{"[\\"@alextaylor98:matrix.shikpooshaan.ir\\", \\"CEAAYOLHOD\\"]"}	1783671808534
208	master	count_e2e_one_time_keys	{@alextaylor98:matrix.shikpooshaan.ir,CEAAYOLHOD}	1783671809577
209	master	count_e2e_one_time_keys	{@alextaylor98:matrix.shikpooshaan.ir,CEAAYOLHOD}	1783671812524
210	master	get_device	{@brianrockwell:matrix.shikpooshaan.ir,WRMJDYQTPZ}	1783671830652
211	master	get_device	{@brianrockwell:matrix.shikpooshaan.ir,WRMJDYQTPZ}	1783671834681
212	master	count_e2e_one_time_keys	{@brianrockwell:matrix.shikpooshaan.ir,WRMJDYQTPZ}	1783671834734
213	master	count_e2e_one_time_keys	{@brianrockwell:matrix.shikpooshaan.ir,WRMJDYQTPZ}	1783671835681
214	master	get_e2e_unused_fallback_key_types	{@brianrockwell:matrix.shikpooshaan.ir,WRMJDYQTPZ}	1783671835714
215	master	_get_bare_e2e_cross_signing_keys	{@alextaylor98:matrix.shikpooshaan.ir}	1783671837427
216	master	_get_bare_e2e_cross_signing_keys	{@alextaylor98:matrix.shikpooshaan.ir}	1783671837444
217	master	_get_bare_e2e_cross_signing_keys	{@alextaylor98:matrix.shikpooshaan.ir}	1783671837463
218	master	_get_e2e_cross_signing_signatures_for_device	{"[\\"@alextaylor98:matrix.shikpooshaan.ir\\", \\"CEAAYOLHOD\\"]"}	1783671838590
219	master	_get_e2e_cross_signing_signatures_for_device	{"[\\"@alextaylor98:matrix.shikpooshaan.ir\\", \\"NFLNJMUACW\\"]"}	1783671862066
220	master	get_device	{@brianrockwell:matrix.shikpooshaan.ir}	1783671973731
221	master	count_e2e_one_time_keys	{@brianrockwell:matrix.shikpooshaan.ir}	1783671973738
222	master	get_e2e_unused_fallback_key_types	{@brianrockwell:matrix.shikpooshaan.ir}	1783671973739
223	master	get_user_by_access_token	{syt_YnJpYW5yb2Nrd2VsbA_ugVZqsfWmCMbpPnuRzmR_4gSDFo}	1783671973775
224	master	get_user_by_id	{@brian:matrix.shikpooshaan.ir}	1783672033715
225	master	get_device	{@brian:matrix.shikpooshaan.ir,XSUPBBJATQ}	1783672033753
226	master	user_last_seen_monthly_active	\N	1783672130600
227	master	get_monthly_active_count	{}	1783672130603
228	master	get_device	{@brian:matrix.shikpooshaan.ir,YOCYFXUGYQ}	1783672182383
229	master	get_device	{@brian:matrix.shikpooshaan.ir,YOCYFXUGYQ}	1783672186154
230	master	count_e2e_one_time_keys	{@brian:matrix.shikpooshaan.ir,YOCYFXUGYQ}	1783672186195
231	master	get_device	{@brian:matrix.shikpooshaan.ir,YOCYFXUGYQ}	1783672186520
232	master	count_e2e_one_time_keys	{@brian:matrix.shikpooshaan.ir,YOCYFXUGYQ}	1783672186550
233	master	count_e2e_one_time_keys	{@brian:matrix.shikpooshaan.ir,YOCYFXUGYQ}	1783672187500
234	master	get_e2e_unused_fallback_key_types	{@brian:matrix.shikpooshaan.ir,YOCYFXUGYQ}	1783672187520
235	master	_get_bare_e2e_cross_signing_keys	{@brian:matrix.shikpooshaan.ir}	1783672187674
236	master	_get_bare_e2e_cross_signing_keys	{@brian:matrix.shikpooshaan.ir}	1783672187720
238	master	get_if_user_has_pusher	{@brian:matrix.shikpooshaan.ir}	1783672225279
239	master	cs_cache_fake	{!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir}	1783672403545
240	master	cs_cache_fake	{!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir,@brian:matrix.shikpooshaan.ir}	1783672403829
241	master	cs_cache_fake	{!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir}	1783672404334
242	master	cs_cache_fake	{!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir,@alextaylor98:matrix.shikpooshaan.ir}	1783672404588
237	master	_get_bare_e2e_cross_signing_keys	{@brian:matrix.shikpooshaan.ir}	1783672187734
243	master	cs_cache_fake	{!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir,@alextaylor98:matrix.shikpooshaan.ir}	1783672409822
245	master	count_e2e_one_time_keys	{@alextaylor98:matrix.shikpooshaan.ir,CEAAYOLHOD}	1783672422357
244	master	count_e2e_one_time_keys	{@brian:matrix.shikpooshaan.ir,YOCYFXUGYQ}	1783672413906
246	master	count_e2e_one_time_keys	{@alextaylor98:matrix.shikpooshaan.ir,CEAAYOLHOD}	1783672423869
\.


--
-- Data for Name: current_state_delta_stream; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.current_state_delta_stream (stream_id, room_id, type, state_key, event_id, prev_event_id, instance_name) FROM stdin;
2	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.create		$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE	\N	master
3	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.member	@brianrockwell:matrix.shikpooshaan.ir	$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag	\N	master
4	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.encryption		$A960r4luhjM4-N8ZlQT_oZvugpHLDMyoL7N8LsvnnlI	\N	master
4	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.guest_access		$prihY7_PFyGlMWv4ENxfD2iizqJyMNoQbig1eNbs7UY	\N	master
4	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.history_visibility		$-Yvs0xYmtCB-d_v2Z7zGwQj8jvY11ZDzzMQaPKj3DHw	\N	master
4	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.join_rules		$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00	\N	master
4	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.power_levels		$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4	\N	master
9	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA	\N	master
10	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI	$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA	master
18	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.member	@brianrockwell:matrix.shikpooshaan.ir	$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU	$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag	master
19	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.create		$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU	\N	master
20	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY	\N	master
21	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.encryption		$uPRJ79eQQkEtz9GsgfXr0y-f3JPTNkvLdecu65l13Eo	\N	master
21	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.guest_access		$pR2OnVDcJjiIYWrhS9nEoocIiQESVvpdsQfYu64Jhp4	\N	master
21	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.history_visibility		$h_Aewnb-d3kjnDHdRL1B_3KhQvXaRyb0xNw9N0ctEUM	\N	master
21	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.join_rules		$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M	\N	master
21	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.power_levels		$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	\N	master
26	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.member	@brianrockwell:matrix.shikpooshaan.ir	$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU	\N	master
27	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.member	@brianrockwell:matrix.shikpooshaan.ir	$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg	$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU	master
28	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.create		$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY	\N	master
29	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.member	@brianrockwell:matrix.shikpooshaan.ir	$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	\N	master
30	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.encryption		$egxiNGcQc850qQa01Ox8mP5yoEj1Q5Ex-bzUWtN4W5c	\N	master
30	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.guest_access		$VWhXTrJ895IdYCilHYuIInhbeUE8rsIzTWUjb7gSL1M	\N	master
30	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.history_visibility		$JrVCAJ9f2DtGYEV120F1HrAvVIjWumvsdBmenypJvNY	\N	master
30	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.join_rules		$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0	\N	master
30	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.power_levels		$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM	\N	master
35	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I	\N	master
36	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg	$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I	master
45	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.create		$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg	\N	master
46	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY	\N	master
47	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.encryption		$_VnHK-C5uJEI_LtZ6Edmfv4J6T35_tYN-Em2qO-sRyU	\N	master
47	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.guest_access		$14g0e4tQc-4i_Vdo1U2pNGwl-QbxmmrnRRA2DOZjnYs	\N	master
47	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.history_visibility		$NFsUH4yHF1VWTTF3R7erS73-88ifZ3r1Lk1lrp7s5rI	\N	master
47	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.join_rules		$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI	\N	master
47	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.power_levels		$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	\N	master
52	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA	\N	master
53	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA	$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA	master
54	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.create		$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg	\N	master
55	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.member	@alipaz:matrix.shikpooshaan.ir	$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	\N	master
56	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.encryption		$oUHPDjqakCWglPegHTY6TC8e_Qaqub-Yoh_XfUKTjjc	\N	master
56	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.guest_access		$Z2e6JO81o3A3wHKKBJSTB-q68xOeUakOBJi-6H0er2I	\N	master
56	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.history_visibility		$ZaaKYiCE_n9AzqSGJntdPRcRM7BRhym69EHSrFwgdac	\N	master
56	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.join_rules		$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE	\N	master
56	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.power_levels		$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	\N	master
61	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA	\N	master
62	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s	$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA	master
68	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg	$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY	master
69	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A	$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s	master
71	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k	$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A	master
70	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo	$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg	master
72	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.create		$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4	\N	master
73	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	\N	master
74	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.encryption		$KTjmV6JHWFiwg8JXvrYWGjeMxJtAvzZoRDulWpsNaSw	\N	master
74	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.guest_access		$zc8tOpOdwrt2LhO6ZIPa8Tv1PyclAu-E3cFNvQTB_rw	\N	master
74	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.history_visibility		$Dc3jotNRZdjzDW_y7eg_fRWeyXs382gqm43HSX5lbOI	\N	master
74	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.join_rules		$ekFlSyfMDYeG34nr1qqB9Bi-AbjdiJ_J9bLNNsHuLKs	\N	master
74	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.power_levels		$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY	\N	master
80	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.create		$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U	\N	master
81	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	\N	master
82	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.encryption		$RDmQ4EMxY-FgFox84X5UWejaA1ImHNYssM_nyAlLSbs	\N	master
82	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.guest_access		$xRkldK4rXGoVy6SNEazvj_642j0z4vnhDKSsno94oMs	\N	master
82	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.history_visibility		$YP8LBjVbUpZKdDbx8B7q46a8-CJwDp3EK1qyDJCSoio	\N	master
82	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.join_rules		$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw	\N	master
82	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.power_levels		$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo	\N	master
79	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.member	@alextaylor:matrix.shikpooshaan.ir	$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE	\N	master
87	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg	\N	master
88	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk	$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg	master
91	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is	$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY	master
92	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY	$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk	master
95	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	$4X_PjJl7QiE3U7c8UuRUw5-rEt6S9u2f1fEzR5tiWso	$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is	master
96	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.create		$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs	\N	master
97	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.member	@brian:matrix.shikpooshaan.ir	$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	\N	master
98	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.encryption		$d-DLbKD_o_R1rzHrZD8hyXWTZsKArLYnNTv9_1HRatE	\N	master
98	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.guest_access		$lzdi23BC1bOIDnNJnuoZzfFYBb3iv4PDZ1pw9Tg4z1M	\N	master
98	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.history_visibility		$6UQ-qIZULcBYRTpiEHtIjLH-lHfTx1ipANQeBo3ldw0	\N	master
98	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.join_rules		$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ	\N	master
98	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.power_levels		$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk	\N	master
103	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg	\N	master
104	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk	$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg	master
\.


--
-- Data for Name: current_state_events; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.current_state_events (event_id, room_id, type, state_key, membership, event_stream_ordering) FROM stdin;
$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.create		\N	2
$A960r4luhjM4-N8ZlQT_oZvugpHLDMyoL7N8LsvnnlI	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.encryption		\N	7
$prihY7_PFyGlMWv4ENxfD2iizqJyMNoQbig1eNbs7UY	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.guest_access		\N	6
$-Yvs0xYmtCB-d_v2Z7zGwQj8jvY11ZDzzMQaPKj3DHw	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.history_visibility		\N	8
$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.join_rules		\N	5
$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.power_levels		\N	4
$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	join	10
$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.member	@brianrockwell:matrix.shikpooshaan.ir	leave	18
$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.create		\N	19
$uPRJ79eQQkEtz9GsgfXr0y-f3JPTNkvLdecu65l13Eo	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.encryption		\N	24
$pR2OnVDcJjiIYWrhS9nEoocIiQESVvpdsQfYu64Jhp4	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.guest_access		\N	23
$h_Aewnb-d3kjnDHdRL1B_3KhQvXaRyb0xNw9N0ctEUM	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.history_visibility		\N	25
$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.join_rules		\N	22
$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.power_levels		\N	21
$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.member	@brianrockwell:matrix.shikpooshaan.ir	join	27
$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.create		\N	28
$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.member	@brianrockwell:matrix.shikpooshaan.ir	join	29
$egxiNGcQc850qQa01Ox8mP5yoEj1Q5Ex-bzUWtN4W5c	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.encryption		\N	33
$VWhXTrJ895IdYCilHYuIInhbeUE8rsIzTWUjb7gSL1M	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.guest_access		\N	32
$JrVCAJ9f2DtGYEV120F1HrAvVIjWumvsdBmenypJvNY	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.history_visibility		\N	34
$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.join_rules		\N	31
$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.power_levels		\N	30
$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	join	36
$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.create		\N	45
$_VnHK-C5uJEI_LtZ6Edmfv4J6T35_tYN-Em2qO-sRyU	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.encryption		\N	50
$14g0e4tQc-4i_Vdo1U2pNGwl-QbxmmrnRRA2DOZjnYs	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.guest_access		\N	49
$NFsUH4yHF1VWTTF3R7erS73-88ifZ3r1Lk1lrp7s5rI	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.history_visibility		\N	51
$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.join_rules		\N	48
$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.power_levels		\N	47
$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	join	53
$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.create		\N	54
$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.member	@alipaz:matrix.shikpooshaan.ir	join	55
$oUHPDjqakCWglPegHTY6TC8e_Qaqub-Yoh_XfUKTjjc	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.encryption		\N	59
$Z2e6JO81o3A3wHKKBJSTB-q68xOeUakOBJi-6H0er2I	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.guest_access		\N	58
$ZaaKYiCE_n9AzqSGJntdPRcRM7BRhym69EHSrFwgdac	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.history_visibility		\N	60
$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.join_rules		\N	57
$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.power_levels		\N	56
$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	join	70
$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	join	71
$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.create		\N	72
$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	join	73
$KTjmV6JHWFiwg8JXvrYWGjeMxJtAvzZoRDulWpsNaSw	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.encryption		\N	77
$zc8tOpOdwrt2LhO6ZIPa8Tv1PyclAu-E3cFNvQTB_rw	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.guest_access		\N	76
$Dc3jotNRZdjzDW_y7eg_fRWeyXs382gqm43HSX5lbOI	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.history_visibility		\N	78
$ekFlSyfMDYeG34nr1qqB9Bi-AbjdiJ_J9bLNNsHuLKs	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.join_rules		\N	75
$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.power_levels		\N	74
$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.member	@alextaylor:matrix.shikpooshaan.ir	invite	79
$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.create		\N	80
$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	join	81
$RDmQ4EMxY-FgFox84X5UWejaA1ImHNYssM_nyAlLSbs	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.encryption		\N	85
$xRkldK4rXGoVy6SNEazvj_642j0z4vnhDKSsno94oMs	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.guest_access		\N	84
$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.create		\N	96
$YP8LBjVbUpZKdDbx8B7q46a8-CJwDp3EK1qyDJCSoio	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.history_visibility		\N	86
$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.join_rules		\N	83
$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.power_levels		\N	82
$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	join	92
$4X_PjJl7QiE3U7c8UuRUw5-rEt6S9u2f1fEzR5tiWso	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	leave	95
$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	join	104
$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.member	@brian:matrix.shikpooshaan.ir	join	97
$d-DLbKD_o_R1rzHrZD8hyXWTZsKArLYnNTv9_1HRatE	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.encryption		\N	101
$lzdi23BC1bOIDnNJnuoZzfFYBb3iv4PDZ1pw9Tg4z1M	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.guest_access		\N	100
$6UQ-qIZULcBYRTpiEHtIjLH-lHfTx1ipANQeBo3ldw0	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.history_visibility		\N	102
$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.join_rules		\N	99
$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.power_levels		\N	98
\.


--
-- Data for Name: dehydrated_devices; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.dehydrated_devices (user_id, device_id, device_data) FROM stdin;
\.


--
-- Data for Name: delayed_events; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.delayed_events (delay_id, user_localpart, device_id, delay, send_ts, room_id, event_type, state_key, origin_server_ts, content, is_processed, sticky_duration_ms) FROM stdin;
\.


--
-- Data for Name: delayed_events_stream_pos; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.delayed_events_stream_pos (lock, stream_id) FROM stdin;
X	109
\.


--
-- Data for Name: deleted_pushers; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.deleted_pushers (stream_id, app_id, pushkey, user_id, instance_name) FROM stdin;
3	im.vector.app.android	cXRzOJQKSF-uUKfMghugq0	@alex-taylor:matrix.shikpooshaan.ir	master
13	im.vector.app.android	cXRzOJQKSF-uUKfMghugq0	@brianrockwell:matrix.shikpooshaan.ir	master
20	im.vector.app.android	cXRzOJQKSF-uUKfMghugq0	@alex-taylor:matrix.shikpooshaan.ir	master
\.


--
-- Data for Name: destination_rooms; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.destination_rooms (destination, room_id, stream_ordering) FROM stdin;
\.


--
-- Data for Name: destinations; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.destinations (destination, retry_last_ts, retry_interval, failure_ts, last_successful_stream_ordering) FROM stdin;
\.


--
-- Data for Name: device_auth_providers; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.device_auth_providers (user_id, device_id, auth_provider_id, auth_provider_session_id) FROM stdin;
\.


--
-- Data for Name: device_federation_inbox; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.device_federation_inbox (origin, message_id, received_ts, instance_name) FROM stdin;
\.


--
-- Data for Name: device_federation_outbox; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.device_federation_outbox (destination, stream_id, queued_ts, messages_json, instance_name) FROM stdin;
\.


--
-- Data for Name: device_inbox; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.device_inbox (user_id, device_id, stream_id, message_json, instance_name) FROM stdin;
@alextaylor98:matrix.shikpooshaan.ir	GZIPKPHOVU	17	{"content":{"action":"request","name":"m.cross_signing.master","request_id":"278a80a9ed414a86a735b1510b56858e","requesting_device_id":"CEAAYOLHOD"},"type":"m.secret.request","sender":"@alextaylor98:matrix.shikpooshaan.ir"}	master
@alextaylor98:matrix.shikpooshaan.ir	GZIPKPHOVU	19	{"content":{"action":"request","name":"m.megolm_backup.v1","request_id":"d41a5fcf8ce3448db54ed2c8b3b8a89f","requesting_device_id":"CEAAYOLHOD"},"type":"m.secret.request","sender":"@alextaylor98:matrix.shikpooshaan.ir"}	master
@alextaylor98:matrix.shikpooshaan.ir	GZIPKPHOVU	21	{"content":{"action":"request","name":"m.cross_signing.self_signing","request_id":"54854bbab353480ea8f5dd4a74d08a87","requesting_device_id":"CEAAYOLHOD"},"type":"m.secret.request","sender":"@alextaylor98:matrix.shikpooshaan.ir"}	master
@alextaylor98:matrix.shikpooshaan.ir	GZIPKPHOVU	25	{"content":{"action":"request_cancellation","request_id":"54854bbab353480ea8f5dd4a74d08a87","requesting_device_id":"CEAAYOLHOD"},"type":"m.secret.request","sender":"@alextaylor98:matrix.shikpooshaan.ir"}	master
@alextaylor98:matrix.shikpooshaan.ir	GZIPKPHOVU	23	{"content":{"action":"request","name":"m.cross_signing.user_signing","request_id":"1db8688bc95a4b4882c8fd139a60fe9f","requesting_device_id":"CEAAYOLHOD"},"type":"m.secret.request","sender":"@alextaylor98:matrix.shikpooshaan.ir"}	master
@alextaylor98:matrix.shikpooshaan.ir	GZIPKPHOVU	26	{"content":{"action":"request_cancellation","request_id":"1db8688bc95a4b4882c8fd139a60fe9f","requesting_device_id":"CEAAYOLHOD"},"type":"m.secret.request","sender":"@alextaylor98:matrix.shikpooshaan.ir"}	master
@alextaylor98:matrix.shikpooshaan.ir	GZIPKPHOVU	39	{"content":{"action":"request","name":"m.cross_signing.master","requesting_device_id":"NFLNJMUACW","request_id":"0ea42501a5c5424ca6a73248c0e95d78"},"type":"m.secret.request","sender":"@alextaylor98:matrix.shikpooshaan.ir"}	master
@alextaylor98:matrix.shikpooshaan.ir	GZIPKPHOVU	38	{"content":{"action":"request","name":"m.cross_signing.self_signing","requesting_device_id":"NFLNJMUACW","request_id":"4f0a6ecafe714ea18d7853f4528f2404"},"type":"m.secret.request","sender":"@alextaylor98:matrix.shikpooshaan.ir"}	master
@alextaylor98:matrix.shikpooshaan.ir	GZIPKPHOVU	40	{"content":{"action":"request","name":"m.cross_signing.user_signing","requesting_device_id":"NFLNJMUACW","request_id":"40580d494d2f4119a573a50dc7d9f5eb"},"type":"m.secret.request","sender":"@alextaylor98:matrix.shikpooshaan.ir"}	master
@alextaylor98:matrix.shikpooshaan.ir	GZIPKPHOVU	42	{"content":{"action":"request_cancellation","requesting_device_id":"NFLNJMUACW","request_id":"4f0a6ecafe714ea18d7853f4528f2404"},"type":"m.secret.request","sender":"@alextaylor98:matrix.shikpooshaan.ir"}	master
@alextaylor98:matrix.shikpooshaan.ir	GZIPKPHOVU	44	{"content":{"action":"request_cancellation","requesting_device_id":"NFLNJMUACW","request_id":"40580d494d2f4119a573a50dc7d9f5eb"},"type":"m.secret.request","sender":"@alextaylor98:matrix.shikpooshaan.ir"}	master
@alextaylor98:matrix.shikpooshaan.ir	GZIPKPHOVU	46	{"content":{"action":"request_cancellation","requesting_device_id":"NFLNJMUACW","request_id":"0ea42501a5c5424ca6a73248c0e95d78"},"type":"m.secret.request","sender":"@alextaylor98:matrix.shikpooshaan.ir"}	master
\.


--
-- Data for Name: device_lists_changes_converted_stream_position; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.device_lists_changes_converted_stream_position (lock, stream_id, room_id, instance_name) FROM stdin;
X	75		master
\.


--
-- Data for Name: device_lists_changes_in_room; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.device_lists_changes_in_room (user_id, device_id, room_id, stream_id, converted_to_destinations, opentracing_context, instance_name, inserted_ts) FROM stdin;
@brianrockwell:matrix.shikpooshaan.ir	KYQHVGSULI	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	32	f	{}	master	1783626429906
@brianrockwell:matrix.shikpooshaan.ir	KYQHVGSULI	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	32	f	{}	master	1783626429906
@alex-taylor:matrix.shikpooshaan.ir	OFUSOVXTZJ	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	53	f	{}	master	1783667564102
@alex-taylor:matrix.shikpooshaan.ir	OFUSOVXTZJ	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	53	f	{}	master	1783667564102
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	54	f	{}	master	1783667620837
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	54	f	{}	master	1783667620837
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	55	f	{}	master	1783667622794
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	55	f	{}	master	1783667622794
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	56	f	{}	master	1783667634061
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	56	f	{}	master	1783667634061
@ali:matrix.shikpooshaan.ir	WGYBGBWZQI	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	57	f	{}	master	1783671622120
@ali:matrix.shikpooshaan.ir	WGYBGBWZQI	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	57	f	{}	master	1783671622120
@ali:matrix.shikpooshaan.ir	WGYBGBWZQI	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	57	f	{}	master	1783671622120
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	58	f	{}	master	1783671786863
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	59	f	{}	master	1783671796289
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	60	f	{}	master	1783671808546
@brianrockwell:matrix.shikpooshaan.ir	WRMJDYQTPZ	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	61	f	{}	master	1783671830662
@brianrockwell:matrix.shikpooshaan.ir	WRMJDYQTPZ	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	61	f	{}	master	1783671830662
@brianrockwell:matrix.shikpooshaan.ir	WRMJDYQTPZ	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	62	f	{}	master	1783671834649
@brianrockwell:matrix.shikpooshaan.ir	WRMJDYQTPZ	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	62	f	{}	master	1783671834649
@alextaylor98:matrix.shikpooshaan.ir	a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	64	f	{}	master	1783671837518
@alextaylor98:matrix.shikpooshaan.ir	JEWJByMqHvdRd45VbQ89uTuPUUPlJ1EBYuEdQqVuG+c	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	65	f	{}	master	1783671837518
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	66	f	{}	master	1783671838604
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	67	f	{}	master	1783671862079
@brianrockwell:matrix.shikpooshaan.ir	WRMJDYQTPZ	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	68	f	{}	master	1783671973802
@brianrockwell:matrix.shikpooshaan.ir	WRMJDYQTPZ	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	68	f	{}	master	1783671973802
\.


--
-- Data for Name: device_lists_changes_in_room_max_pruned_stream_id; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.device_lists_changes_in_room_max_pruned_stream_id (lock, stream_id) FROM stdin;
X	0
\.


--
-- Data for Name: device_lists_outbound_last_success; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.device_lists_outbound_last_success (destination, user_id, stream_id) FROM stdin;
\.


--
-- Data for Name: device_lists_outbound_pokes; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.device_lists_outbound_pokes (destination, stream_id, user_id, device_id, sent, ts, opentracing_context, instance_name) FROM stdin;
\.


--
-- Data for Name: device_lists_remote_cache; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.device_lists_remote_cache (user_id, device_id, content) FROM stdin;
\.


--
-- Data for Name: device_lists_remote_extremeties; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.device_lists_remote_extremeties (user_id, stream_id) FROM stdin;
\.


--
-- Data for Name: device_lists_remote_pending; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.device_lists_remote_pending (stream_id, user_id, device_id, instance_name) FROM stdin;
\.


--
-- Data for Name: device_lists_remote_resync; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.device_lists_remote_resync (user_id, added_ts) FROM stdin;
\.


--
-- Data for Name: device_lists_stream; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.device_lists_stream (stream_id, user_id, device_id, instance_name) FROM stdin;
2	@alextaylor:matrix.shikpooshaan.ir	SAWFHDVRYA	master
3	@ali:matrix.shikpooshaan.ir	DRPHZPCPVD	master
8	@ali:matrix.shikpooshaan.ir	5+ArUwizcScHeHQxyQqSnvma0Ul/IdEcsjbP8C+BAfs	master
9	@ali:matrix.shikpooshaan.ir	rHXekuQKtYVClW0YKa5d3+tMcY4vcSkh/ACekrxuUm8	master
10	@alex-taylor:matrix.shikpooshaan.ir	CRYINYFIHK	master
11	@brianrockwell:matrix.shikpooshaan.ir	AVTTVCQSYF	master
16	@alex-taylor:matrix.shikpooshaan.ir	Mw70aYuCoCmYXLZ2UKd4oI3PRHgs+++SO6XA55t02E8	master
17	@alex-taylor:matrix.shikpooshaan.ir	dQUtuFpGt0/aNRD3xSLD88m+XbxyBT+3WVi+5fBhS4M	master
18	@alex-taylor:matrix.shikpooshaan.ir	HPQGRDHEVK	master
23	@brianrockwell:matrix.shikpooshaan.ir	w63RBZ0TOEnArMjlVYeB4pYUFbA0U3uX5/2bKizFQFM	master
24	@brianrockwell:matrix.shikpooshaan.ir	NfByZPDSPrY47gx1qkOpva3X5ZYi3hZz3lvZAIvZ1Q8	master
25	@alextaylor98:matrix.shikpooshaan.ir	GZIPKPHOVU	master
30	@alextaylor98:matrix.shikpooshaan.ir	ATHMCRr8Wd/Gvx8HUYoSHZZzjqWdwjSl8IbWwoVaQrE	master
31	@alextaylor98:matrix.shikpooshaan.ir	GDt3RZufIgjvlXDT++RSBrsnG9170V/OArQ7jAzQrQ0	master
32	@brianrockwell:matrix.shikpooshaan.ir	KYQHVGSULI	master
36	@alex-taylor:matrix.shikpooshaan.ir	9rBlDG6qTbTubxNp3++LEV1m/Z4nww7OA8SMeIJzRkk	master
37	@alex-taylor:matrix.shikpooshaan.ir	j8Q/cqkuuRUqrYDUFsx4q2rXayMtTZHCFD34Xv+Rkgw	master
41	@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	master
43	@alipaz:matrix.shikpooshaan.ir	Dk409XoilPTlLlWveqoUgBEPII6npHC1C657tmHP2VQ	master
44	@alipaz:matrix.shikpooshaan.ir	Yud8T69IrQtmC/X2KFrPfaN28E81pdZBWKVMAinDv7w	master
45	@monir:matrix.shikpooshaan.ir	CAOSKJQGSV	master
48	@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	master
50	@monir:matrix.shikpooshaan.ir	Hy/5/dagWfQI6psqnjJrzeYpLs7/t/EIynf3tYQeocE	master
51	@monir:matrix.shikpooshaan.ir	fJe66cgaEl2d0NUoi1n3Oph3gCPZWmQpoZ+JVro7xms	master
52	@aa0922ny:matrix.shikpooshaan.ir	BOOHWYAZFZ	master
53	@alex-taylor:matrix.shikpooshaan.ir	OFUSOVXTZJ	master
56	@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	master
57	@ali:matrix.shikpooshaan.ir	WGYBGBWZQI	master
64	@alextaylor98:matrix.shikpooshaan.ir	a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY	master
65	@alextaylor98:matrix.shikpooshaan.ir	JEWJByMqHvdRd45VbQ89uTuPUUPlJ1EBYuEdQqVuG+c	master
66	@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	master
67	@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	master
68	@brianrockwell:matrix.shikpooshaan.ir	WRMJDYQTPZ	master
69	@brian:matrix.shikpooshaan.ir	XSUPBBJATQ	master
72	@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	master
74	@brian:matrix.shikpooshaan.ir	ee2Crc4cHA1rBL7A1enR4V+p3l6vvHFLTajf01Afkmg	master
75	@brian:matrix.shikpooshaan.ir	xIHCRPRA2KyGK1bvMbVgm0/7U5jkE/yA1cLzdtmieJ8	master
\.


--
-- Data for Name: devices; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.devices (user_id, device_id, display_name, last_seen, ip, user_agent, hidden) FROM stdin;
@alextaylor:matrix.shikpooshaan.ir	SAWFHDVRYA	\N	\N	\N	\N	f
@ali:matrix.shikpooshaan.ir	DRPHZPCPVD	\N	\N	\N	\N	f
@alipaz:matrix.shikpooshaan.ir	Dk409XoilPTlLlWveqoUgBEPII6npHC1C657tmHP2VQ	master signing key	\N	\N	\N	t
@ali:matrix.shikpooshaan.ir	5+ArUwizcScHeHQxyQqSnvma0Ul/IdEcsjbP8C+BAfs	master signing key	\N	\N	\N	t
@ali:matrix.shikpooshaan.ir	rHXekuQKtYVClW0YKa5d3+tMcY4vcSkh/ACekrxuUm8	self_signing signing key	\N	\N	\N	t
@ali:matrix.shikpooshaan.ir	FL/n1a1R2fsqNjDQ8eE0YZUJGrbWim5EfNOh6ttpgu8	user_signing signing key	\N	\N	\N	t
@alex-taylor:matrix.shikpooshaan.ir	CRYINYFIHK	\N	\N	\N	\N	f
@brianrockwell:matrix.shikpooshaan.ir	AVTTVCQSYF	\N	\N	\N	\N	f
@alipaz:matrix.shikpooshaan.ir	Yud8T69IrQtmC/X2KFrPfaN28E81pdZBWKVMAinDv7w	self_signing signing key	\N	\N	\N	t
@alex-taylor:matrix.shikpooshaan.ir	Mw70aYuCoCmYXLZ2UKd4oI3PRHgs+++SO6XA55t02E8	master signing key	\N	\N	\N	t
@alex-taylor:matrix.shikpooshaan.ir	dQUtuFpGt0/aNRD3xSLD88m+XbxyBT+3WVi+5fBhS4M	self_signing signing key	\N	\N	\N	t
@alex-taylor:matrix.shikpooshaan.ir	bdcZ/y/g57mHbSI2PDY9QEtwdKIYVfD5y68AztNZJ6w	user_signing signing key	\N	\N	\N	t
@alipaz:matrix.shikpooshaan.ir	nRsrY6W2+asEwwRMhL5KFe9kZnvBuzD03efN29v+MHA	user_signing signing key	\N	\N	\N	t
@brianrockwell:matrix.shikpooshaan.ir	w63RBZ0TOEnArMjlVYeB4pYUFbA0U3uX5/2bKizFQFM	master signing key	\N	\N	\N	t
@brianrockwell:matrix.shikpooshaan.ir	NfByZPDSPrY47gx1qkOpva3X5ZYi3hZz3lvZAIvZ1Q8	self_signing signing key	\N	\N	\N	t
@brianrockwell:matrix.shikpooshaan.ir	gNwJ+2Mo2ssf5VNiGSlNA1TcfFaqNFKdYd5jW2oqs/w	user_signing signing key	\N	\N	\N	t
@alextaylor98:matrix.shikpooshaan.ir	a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY	master signing key	\N	\N	\N	t
@alextaylor98:matrix.shikpooshaan.ir	JEWJByMqHvdRd45VbQ89uTuPUUPlJ1EBYuEdQqVuG+c	self_signing signing key	\N	\N	\N	t
@alextaylor98:matrix.shikpooshaan.ir	tl/tOabB4e6Bu6YBjeVMKsdET92ViX7yBfLyhskIHH8	user_signing signing key	\N	\N	\N	t
@aa0922ny:matrix.shikpooshaan.ir	BOOHWYAZFZ	\N	\N	\N	\N	f
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	Element X Android	1783672206052	93.114.98.127	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)	f
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	chatapp.shikpooshaan.ir: Chrome on Windows	1783628229728	217.28.137.165	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36	f
@alextaylor98:matrix.shikpooshaan.ir	GZIPKPHOVU	\N	\N	\N	\N	f
@alextaylor98:matrix.shikpooshaan.ir	ATHMCRr8Wd/Gvx8HUYoSHZZzjqWdwjSl8IbWwoVaQrE	master signing key	\N	\N	\N	t
@alextaylor98:matrix.shikpooshaan.ir	GDt3RZufIgjvlXDT++RSBrsnG9170V/OArQ7jAzQrQ0	self_signing signing key	\N	\N	\N	t
@alextaylor98:matrix.shikpooshaan.ir	rPiqbgWjW2ox0LaSDcjBRtgSK+UJxx0X1/9UlXrhsKY	user_signing signing key	\N	\N	\N	t
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	Element X Android	1783672600327	217.28.137.165	Element X/26.07.0 (Xiaomi 23021RAAEG; Android 15; AQ3A.240829.003; Sdk 023f5bdce)	f
@monir:matrix.shikpooshaan.ir	CAOSKJQGSV	\N	\N	\N	\N	f
@brian:matrix.shikpooshaan.ir	XSUPBBJATQ	\N	\N	\N	\N	f
@alex-taylor:matrix.shikpooshaan.ir	9rBlDG6qTbTubxNp3++LEV1m/Z4nww7OA8SMeIJzRkk	master signing key	\N	\N	\N	t
@alex-taylor:matrix.shikpooshaan.ir	j8Q/cqkuuRUqrYDUFsx4q2rXayMtTZHCFD34Xv+Rkgw	self_signing signing key	\N	\N	\N	t
@alex-taylor:matrix.shikpooshaan.ir	2c5xO3QJFV3H5v6GYzi7oHYm9fP8vvGmcPZzTsTPrOU	user_signing signing key	\N	\N	\N	t
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	chatapp.shikpooshaan.ir: Chrome on Windows	1783628283319	94.24.18.95	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36	f
@monir:matrix.shikpooshaan.ir	Hy/5/dagWfQI6psqnjJrzeYpLs7/t/EIynf3tYQeocE	master signing key	\N	\N	\N	t
@monir:matrix.shikpooshaan.ir	fJe66cgaEl2d0NUoi1n3Oph3gCPZWmQpoZ+JVro7xms	self_signing signing key	\N	\N	\N	t
@monir:matrix.shikpooshaan.ir	QGV3JWTNF8lPZX6rriruueaCC1cpImxYtTnJzJJMVcM	user_signing signing key	\N	\N	\N	t
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	Element X iOS	1783672856923	94.24.18.95	Element X/26.06.1 (iPhone 14 Pro Max; iOS 26.5.2; Scale/3.00)	f
@brian:matrix.shikpooshaan.ir	ee2Crc4cHA1rBL7A1enR4V+p3l6vvHFLTajf01Afkmg	master signing key	\N	\N	\N	t
@brian:matrix.shikpooshaan.ir	xIHCRPRA2KyGK1bvMbVgm0/7U5jkE/yA1cLzdtmieJ8	self_signing signing key	\N	\N	\N	t
@brian:matrix.shikpooshaan.ir	t+4UbQWjbOr+jsC8dWCd1vXpnBOhwcj/J72OEMFS6fo	user_signing signing key	\N	\N	\N	t
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	Element Desktop: Windows	1783672942646	94.24.18.95	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Element/1.12.23 Chrome/148.0.7778.265 Electron/42.4.1 Safari/537.36	f
\.


--
-- Data for Name: e2e_cross_signing_keys; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.e2e_cross_signing_keys (user_id, keytype, keydata, stream_id, updatable_without_uia_before_ms, instance_name) FROM stdin;
@ali:matrix.shikpooshaan.ir	master	{"keys":{"ed25519:5+ArUwizcScHeHQxyQqSnvma0Ul/IdEcsjbP8C+BAfs":"5+ArUwizcScHeHQxyQqSnvma0Ul/IdEcsjbP8C+BAfs"},"signatures":{"@ali:matrix.shikpooshaan.ir":{"ed25519:5+ArUwizcScHeHQxyQqSnvma0Ul/IdEcsjbP8C+BAfs":"KkOB8mtYh1Epcr2Nnylm9ClH3WFy5UJtoeEQnSqqi/BlUgk8SDh082kgiRuDiyTL/k71ED4HqmXVld/pLVXICw","ed25519:WGYBGBWZQI":"6OL17oNPMOI82dcUtrqrce4HYZg2CkpDS7LLxqMN4EiV4Pw6jb/udROoDd5LoCfqC1dKoWyyJ7AmaFIDqv1ADw"}},"usage":["master"],"user_id":"@ali:matrix.shikpooshaan.ir"}	2	\N	master
@ali:matrix.shikpooshaan.ir	self_signing	{"keys":{"ed25519:rHXekuQKtYVClW0YKa5d3+tMcY4vcSkh/ACekrxuUm8":"rHXekuQKtYVClW0YKa5d3+tMcY4vcSkh/ACekrxuUm8"},"signatures":{"@ali:matrix.shikpooshaan.ir":{"ed25519:5+ArUwizcScHeHQxyQqSnvma0Ul/IdEcsjbP8C+BAfs":"mfBb33wiW/t1LxK5GCEN49iJeLXPiT62S+G645mtZzPOXYN6/gVu/vEfWfahtPUh0DAnN0/UMXB3gE/tnqJVCg"}},"usage":["self_signing"],"user_id":"@ali:matrix.shikpooshaan.ir"}	3	\N	master
@ali:matrix.shikpooshaan.ir	user_signing	{"keys":{"ed25519:FL/n1a1R2fsqNjDQ8eE0YZUJGrbWim5EfNOh6ttpgu8":"FL/n1a1R2fsqNjDQ8eE0YZUJGrbWim5EfNOh6ttpgu8"},"signatures":{"@ali:matrix.shikpooshaan.ir":{"ed25519:5+ArUwizcScHeHQxyQqSnvma0Ul/IdEcsjbP8C+BAfs":"PhFNr/6UHkLFKashI3tVSa9NDj8SPTPmJGvOzCcVfTfM9EFJjw9zyyP/tF/aH8hNIS7qRXXY+A3a+xvYGZATCQ"}},"usage":["user_signing"],"user_id":"@ali:matrix.shikpooshaan.ir"}	4	\N	master
@alex-taylor:matrix.shikpooshaan.ir	master	{"user_id":"@alex-taylor:matrix.shikpooshaan.ir","usage":["master"],"keys":{"ed25519:Mw70aYuCoCmYXLZ2UKd4oI3PRHgs+++SO6XA55t02E8":"Mw70aYuCoCmYXLZ2UKd4oI3PRHgs+++SO6XA55t02E8"},"signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:HPQGRDHEVK":"UqoB17DsyXlhcpgBCYhvI9tLuiS8gyz4G0ucFy0vhxtu8yPUTtvxemDLCs2FDT6bvh7dnp6L4vJf8eDadU9OAg","ed25519:Mw70aYuCoCmYXLZ2UKd4oI3PRHgs+++SO6XA55t02E8":"TzIeLHaJcJq4pLsdPHrfyVzBRwvMBsIkez2U2P3+0Z3FKQdIv6AE27c2WMybQy+/hbTfIwTM/qtXFvrdVCnGAg"}}}	5	\N	master
@alex-taylor:matrix.shikpooshaan.ir	self_signing	{"user_id":"@alex-taylor:matrix.shikpooshaan.ir","usage":["self_signing"],"keys":{"ed25519:dQUtuFpGt0/aNRD3xSLD88m+XbxyBT+3WVi+5fBhS4M":"dQUtuFpGt0/aNRD3xSLD88m+XbxyBT+3WVi+5fBhS4M"},"signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:Mw70aYuCoCmYXLZ2UKd4oI3PRHgs+++SO6XA55t02E8":"SOxERxZdWMwCwClLIhB/C/S26h5767573MnPF8sIXB32aeWtZvwtoBNf1XGPM5B2imMPXLGOzJFr/Ijm4Ru0AA"}}}	6	\N	master
@alex-taylor:matrix.shikpooshaan.ir	user_signing	{"user_id":"@alex-taylor:matrix.shikpooshaan.ir","usage":["user_signing"],"keys":{"ed25519:bdcZ/y/g57mHbSI2PDY9QEtwdKIYVfD5y68AztNZJ6w":"bdcZ/y/g57mHbSI2PDY9QEtwdKIYVfD5y68AztNZJ6w"},"signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:Mw70aYuCoCmYXLZ2UKd4oI3PRHgs+++SO6XA55t02E8":"NbF34lQ1sPnO1NOROT3PFdcIz2X4j7k6eVfZ+nT+PshdBgsy8diG9AqxKsMGI3+H5wajarzHKQ1j4gzm+xQjAQ"}}}	7	\N	master
@brianrockwell:matrix.shikpooshaan.ir	master	{"user_id":"@brianrockwell:matrix.shikpooshaan.ir","usage":["master"],"keys":{"ed25519:w63RBZ0TOEnArMjlVYeB4pYUFbA0U3uX5/2bKizFQFM":"w63RBZ0TOEnArMjlVYeB4pYUFbA0U3uX5/2bKizFQFM"},"signatures":{"@brianrockwell:matrix.shikpooshaan.ir":{"ed25519:KYQHVGSULI":"nKEgH8jbSQbLeb95ivwf7HtFjlSZc+0XKTbgXx5J0SkRPcdmE2EsC6aX/rWlxaD6aavAhxPJzLBAJh8HVRm+Dw","ed25519:w63RBZ0TOEnArMjlVYeB4pYUFbA0U3uX5/2bKizFQFM":"Xjlyoq1F9Gk5jBKnGPzmn6Ew70KUz8PEwk0AQgfsvx0/wEMtl8S0QEUqDNnaBKBIThUjWzWYR7yiUIOJuFXTCA"}}}	8	\N	master
@brianrockwell:matrix.shikpooshaan.ir	self_signing	{"user_id":"@brianrockwell:matrix.shikpooshaan.ir","usage":["self_signing"],"keys":{"ed25519:NfByZPDSPrY47gx1qkOpva3X5ZYi3hZz3lvZAIvZ1Q8":"NfByZPDSPrY47gx1qkOpva3X5ZYi3hZz3lvZAIvZ1Q8"},"signatures":{"@brianrockwell:matrix.shikpooshaan.ir":{"ed25519:w63RBZ0TOEnArMjlVYeB4pYUFbA0U3uX5/2bKizFQFM":"Xp0TC8wntuRxvyYiSaNsYSngEAr8DTOUotgQExHJ25FKnzoyGXJWdbwI4rXG5Uh2FOR1cS7CcHggzsZTu7K9Cg"}}}	9	\N	master
@brianrockwell:matrix.shikpooshaan.ir	user_signing	{"user_id":"@brianrockwell:matrix.shikpooshaan.ir","usage":["user_signing"],"keys":{"ed25519:gNwJ+2Mo2ssf5VNiGSlNA1TcfFaqNFKdYd5jW2oqs/w":"gNwJ+2Mo2ssf5VNiGSlNA1TcfFaqNFKdYd5jW2oqs/w"},"signatures":{"@brianrockwell:matrix.shikpooshaan.ir":{"ed25519:w63RBZ0TOEnArMjlVYeB4pYUFbA0U3uX5/2bKizFQFM":"h6wpPmvF38mYIb5S8Y82EqUsF7+vzYfymm4fQGdxV79ghBMkaNOg5ahEMAtEBK9fXhPVCR+6yYJkQRIHvoENDA"}}}	10	\N	master
@alextaylor98:matrix.shikpooshaan.ir	master	{"user_id":"@alextaylor98:matrix.shikpooshaan.ir","usage":["master"],"keys":{"ed25519:ATHMCRr8Wd/Gvx8HUYoSHZZzjqWdwjSl8IbWwoVaQrE":"ATHMCRr8Wd/Gvx8HUYoSHZZzjqWdwjSl8IbWwoVaQrE"},"signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:ATHMCRr8Wd/Gvx8HUYoSHZZzjqWdwjSl8IbWwoVaQrE":"3WEk0mSvjMUpdLH+HZJ0mBDd7XfK+X84KbP6zh23r7vK7+FiSA/YnxkPhPCrwvhw4HPi2Pstd2Hb6I2fUo4EBg","ed25519:NFLNJMUACW":"IWy/A/Dd5Hwsd1XtF+npj63jLgfs6UmjaJd3VLQA/ldcV+FV6V+ajnvRJvOMs9RqbNKD2iiPw3GISYQgRwhBCA"}}}	11	\N	master
@alextaylor98:matrix.shikpooshaan.ir	self_signing	{"user_id":"@alextaylor98:matrix.shikpooshaan.ir","usage":["self_signing"],"keys":{"ed25519:GDt3RZufIgjvlXDT++RSBrsnG9170V/OArQ7jAzQrQ0":"GDt3RZufIgjvlXDT++RSBrsnG9170V/OArQ7jAzQrQ0"},"signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:ATHMCRr8Wd/Gvx8HUYoSHZZzjqWdwjSl8IbWwoVaQrE":"DFiKhBXLFKrcLdbtChs9c3/zGHG8pWotm3IytkDNf3sdDbJgkNqm/MOOyydB/QO+r8X1kokZcSv1MiccMt52Aw"}}}	12	\N	master
@alextaylor98:matrix.shikpooshaan.ir	user_signing	{"user_id":"@alextaylor98:matrix.shikpooshaan.ir","usage":["user_signing"],"keys":{"ed25519:rPiqbgWjW2ox0LaSDcjBRtgSK+UJxx0X1/9UlXrhsKY":"rPiqbgWjW2ox0LaSDcjBRtgSK+UJxx0X1/9UlXrhsKY"},"signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:ATHMCRr8Wd/Gvx8HUYoSHZZzjqWdwjSl8IbWwoVaQrE":"JvR+oztd1F9TXjRNMvQZpvVCHHs1y/B8gOoS47GDeNt0LYCPNYml7qFqkAj+C6HXw9kfCLvzk2+g1TYCpJtQCA"}}}	13	\N	master
@alex-taylor:matrix.shikpooshaan.ir	master	{"user_id":"@alex-taylor:matrix.shikpooshaan.ir","usage":["master"],"keys":{"ed25519:9rBlDG6qTbTubxNp3++LEV1m/Z4nww7OA8SMeIJzRkk":"9rBlDG6qTbTubxNp3++LEV1m/Z4nww7OA8SMeIJzRkk"},"signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:9rBlDG6qTbTubxNp3++LEV1m/Z4nww7OA8SMeIJzRkk":"P831PUpcy/GWWwE2p4AlSvOZXCEAUEwVvIkMM0Yp2FcHnboTRKfeUXE0nBgG85lmzZGpbLO2zPpNNRyASlk0Ag","ed25519:OFUSOVXTZJ":"rH/xgu9npBuXO+b/5yb7LURVgq2rcJAUWNr4m2EevIqAuzACqxqCR/Y+pfPweWgfs4sPkSpeRrJNdm4OHZMMAw"}}}	14	\N	master
@alex-taylor:matrix.shikpooshaan.ir	self_signing	{"user_id":"@alex-taylor:matrix.shikpooshaan.ir","usage":["self_signing"],"keys":{"ed25519:j8Q/cqkuuRUqrYDUFsx4q2rXayMtTZHCFD34Xv+Rkgw":"j8Q/cqkuuRUqrYDUFsx4q2rXayMtTZHCFD34Xv+Rkgw"},"signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:9rBlDG6qTbTubxNp3++LEV1m/Z4nww7OA8SMeIJzRkk":"wekCpK6cbS6NW+HvLv4HiSS9QCnYAg8h1lQksf9cxc+VII4rIN/y1SfwA5pmcZB5cr/cdH69Gqa4VvYvu8T1Dw"}}}	15	\N	master
@alex-taylor:matrix.shikpooshaan.ir	user_signing	{"user_id":"@alex-taylor:matrix.shikpooshaan.ir","usage":["user_signing"],"keys":{"ed25519:2c5xO3QJFV3H5v6GYzi7oHYm9fP8vvGmcPZzTsTPrOU":"2c5xO3QJFV3H5v6GYzi7oHYm9fP8vvGmcPZzTsTPrOU"},"signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:9rBlDG6qTbTubxNp3++LEV1m/Z4nww7OA8SMeIJzRkk":"nq4nPnk4VtHftE0p3Pw3B+i+XcfHTO7XFMk/oDmwkkiOCdY85SS95jlPuUyuI95K+eHJtS05QUgL1QwBl1iCAA"}}}	16	\N	master
@alipaz:matrix.shikpooshaan.ir	self_signing	{"keys":{"ed25519:Yud8T69IrQtmC/X2KFrPfaN28E81pdZBWKVMAinDv7w":"Yud8T69IrQtmC/X2KFrPfaN28E81pdZBWKVMAinDv7w"},"signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:Dk409XoilPTlLlWveqoUgBEPII6npHC1C657tmHP2VQ":"P5PCDPk+i98kAPI777aFVIxJfmb8Fcqj/6CrXHl4BttmZrLQ/NPoaUmbGfmqy9C3Gx2OapEQ/eEbX2GJ2ySjDg"}},"usage":["self_signing"],"user_id":"@alipaz:matrix.shikpooshaan.ir"}	18	\N	master
@alipaz:matrix.shikpooshaan.ir	master	{"keys":{"ed25519:Dk409XoilPTlLlWveqoUgBEPII6npHC1C657tmHP2VQ":"Dk409XoilPTlLlWveqoUgBEPII6npHC1C657tmHP2VQ"},"signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:Dk409XoilPTlLlWveqoUgBEPII6npHC1C657tmHP2VQ":"K8D459MK/O3Dp3uaxf83QPZJVC9VTjQ86dWb7WAw/8MLorYefP8OCqlMQUnpXfcey04s5Ye7e33+EOSptJHVCA","ed25519:SPEPVPSHPR":"/AVf4bYMqbgHY3766VjG0RxVHy5tzwBqJmxYyCOZzHac9FSN52ySKz0VhzogqOCfHvER9KmGdPEOc0Zw7WCrCA"}},"usage":["master"],"user_id":"@alipaz:matrix.shikpooshaan.ir"}	17	\N	master
@alipaz:matrix.shikpooshaan.ir	user_signing	{"keys":{"ed25519:nRsrY6W2+asEwwRMhL5KFe9kZnvBuzD03efN29v+MHA":"nRsrY6W2+asEwwRMhL5KFe9kZnvBuzD03efN29v+MHA"},"signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:Dk409XoilPTlLlWveqoUgBEPII6npHC1C657tmHP2VQ":"VpFS2TMZuREU9K29PgJjasWzrl1vPrRe7OKqVAZIFFEAAMbNyJlp4uOLqfAeCU7L8A/QuNVVJeOikmXYF1HnBQ"}},"usage":["user_signing"],"user_id":"@alipaz:matrix.shikpooshaan.ir"}	19	\N	master
@monir:matrix.shikpooshaan.ir	master	{"keys":{"ed25519:Hy/5/dagWfQI6psqnjJrzeYpLs7/t/EIynf3tYQeocE":"Hy/5/dagWfQI6psqnjJrzeYpLs7/t/EIynf3tYQeocE"},"signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:Hy/5/dagWfQI6psqnjJrzeYpLs7/t/EIynf3tYQeocE":"GXDs4ywoJ7OUwYhAXO75DJ6JcMf4jvaYfst/1+OfMq+lDM5KTvBvflTGntISb7+I/z0/cDeDG73yCswYFl4XDg","ed25519:WGFMZTWZEK":"dZK3cuqoOPVA7Dv30SxpDKcf0hePqoqobQ4unDGbOqKFR37JAlpprCjk2K9unXCoxM2IiWroa3uMnj3AOSUcDw"}},"usage":["master"],"user_id":"@monir:matrix.shikpooshaan.ir"}	20	\N	master
@monir:matrix.shikpooshaan.ir	self_signing	{"keys":{"ed25519:fJe66cgaEl2d0NUoi1n3Oph3gCPZWmQpoZ+JVro7xms":"fJe66cgaEl2d0NUoi1n3Oph3gCPZWmQpoZ+JVro7xms"},"signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:Hy/5/dagWfQI6psqnjJrzeYpLs7/t/EIynf3tYQeocE":"fer6mZr/4racFHU5H7tGvYnjzq2xz6FYA2osvl49gtcRQ5sPu1EKC2m747WamukMhbqXbpHX87VwXQzX+eH/Ag"}},"usage":["self_signing"],"user_id":"@monir:matrix.shikpooshaan.ir"}	21	\N	master
@monir:matrix.shikpooshaan.ir	user_signing	{"keys":{"ed25519:QGV3JWTNF8lPZX6rriruueaCC1cpImxYtTnJzJJMVcM":"QGV3JWTNF8lPZX6rriruueaCC1cpImxYtTnJzJJMVcM"},"signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:Hy/5/dagWfQI6psqnjJrzeYpLs7/t/EIynf3tYQeocE":"592fJrRLgji21vLzHzFGm3y5pMT5mwSJyZXbWjYRAJr77wjuFWI6/WV/WcZ1GAsaBt376Fzg2hPQLSsP6FDxBQ"}},"usage":["user_signing"],"user_id":"@monir:matrix.shikpooshaan.ir"}	22	\N	master
@alextaylor98:matrix.shikpooshaan.ir	user_signing	{"keys":{"ed25519:tl/tOabB4e6Bu6YBjeVMKsdET92ViX7yBfLyhskIHH8":"tl/tOabB4e6Bu6YBjeVMKsdET92ViX7yBfLyhskIHH8"},"signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY":"Xnccqe7r2KF2r5vYbS6a64mzE/lZbwdQSlzzFHc7IRFVWYAGIhdwC9MaeCAzWb/ePBFug+w4fDSUpPgEknBBAQ"}},"usage":["user_signing"],"user_id":"@alextaylor98:matrix.shikpooshaan.ir"}	25	\N	master
@alextaylor98:matrix.shikpooshaan.ir	master	{"keys":{"ed25519:a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY":"a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY"},"signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"LajeCSEQmA8IJlUsXM6ap7uFeqTmMK8u8kI0AI9iLnuHbuCcLXc23tHXdrr0FPtK5edT+pggXCOILLbsU5jQDw","ed25519:a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY":"uQ9WFeg7r2BGHwZUC+yNvExB1SeEJs7ewqQiAZVzbFgw8lyEAAj2FYdXpqLSvtdbfL/GLEWWIujR8diTMd+kCA"}},"usage":["master"],"user_id":"@alextaylor98:matrix.shikpooshaan.ir"}	23	\N	master
@alextaylor98:matrix.shikpooshaan.ir	self_signing	{"keys":{"ed25519:JEWJByMqHvdRd45VbQ89uTuPUUPlJ1EBYuEdQqVuG+c":"JEWJByMqHvdRd45VbQ89uTuPUUPlJ1EBYuEdQqVuG+c"},"signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY":"LGhBb7X3FDvCCVNik+CFNxyMwkSMG3t8VMSrTBrRbHQG38tzaerobynu1lyfoqULHE7INoALgSm7FmOkd6P/AA"}},"usage":["self_signing"],"user_id":"@alextaylor98:matrix.shikpooshaan.ir"}	24	\N	master
@brian:matrix.shikpooshaan.ir	master	{"user_id":"@brian:matrix.shikpooshaan.ir","usage":["master"],"keys":{"ed25519:ee2Crc4cHA1rBL7A1enR4V+p3l6vvHFLTajf01Afkmg":"ee2Crc4cHA1rBL7A1enR4V+p3l6vvHFLTajf01Afkmg"},"signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"hkXmcCZyQ63osmJJ5QVwjyQFYJEwxzN3eNUx+Qj2RJHEf2cdjHOKcdfYcUWNP9Qf6AcNE1D6xT/HsnpewmTgAg","ed25519:ee2Crc4cHA1rBL7A1enR4V+p3l6vvHFLTajf01Afkmg":"x3rMp7vlcEb+uB+4s5oRS9s9If1Us3i+wHm6ZbDs++bbtWTlANkVM1gD54BdTxeqehMLl75I5IX39MWpIdG8CA"}}}	26	\N	master
@brian:matrix.shikpooshaan.ir	user_signing	{"user_id":"@brian:matrix.shikpooshaan.ir","usage":["user_signing"],"keys":{"ed25519:t+4UbQWjbOr+jsC8dWCd1vXpnBOhwcj/J72OEMFS6fo":"t+4UbQWjbOr+jsC8dWCd1vXpnBOhwcj/J72OEMFS6fo"},"signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:ee2Crc4cHA1rBL7A1enR4V+p3l6vvHFLTajf01Afkmg":"phSzAlT14UpPBIYVgfLtNtj8uj9OUpAO7kRONr+CQUgcdA5WaNpDHwEcykVFAk2N4cZh8YY0Wx23mZYTx+j0AA"}}}	28	\N	master
@brian:matrix.shikpooshaan.ir	self_signing	{"user_id":"@brian:matrix.shikpooshaan.ir","usage":["self_signing"],"keys":{"ed25519:xIHCRPRA2KyGK1bvMbVgm0/7U5jkE/yA1cLzdtmieJ8":"xIHCRPRA2KyGK1bvMbVgm0/7U5jkE/yA1cLzdtmieJ8"},"signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:ee2Crc4cHA1rBL7A1enR4V+p3l6vvHFLTajf01Afkmg":"x9hlpzvqRoR/pFjECjEVksKqSnxtwOUCb9xlCekmZKdyO5D8hAVJWqVpupeUhfx/I9EI6aJvq5BCOoJTcsFaBg"}}}	27	\N	master
\.


--
-- Data for Name: e2e_cross_signing_signatures; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.e2e_cross_signing_signatures (user_id, key_id, target_user_id, target_device_id, signature) FROM stdin;
@alex-taylor:matrix.shikpooshaan.ir	ed25519:j8Q/cqkuuRUqrYDUFsx4q2rXayMtTZHCFD34Xv+Rkgw	@alex-taylor:matrix.shikpooshaan.ir	OFUSOVXTZJ	0uctfsU6MRtJ+ycJ0TNh793NKL+zShPP5t1TGM6Gu0fG3/+W2Pw5ai52g7tVLDgicY0y2vh4xqEVRC5hxcqGCA
@alex-taylor:matrix.shikpooshaan.ir	ed25519:j8Q/cqkuuRUqrYDUFsx4q2rXayMtTZHCFD34Xv+Rkgw	@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	tYT2WjwTmxnSNY0OBm0G8Dd7NgBLVF4bvqlinI5cf9T4G29Ll2mfNxs7O+Rhn3o8Lo1orNS58bw5vNC6zwqhBQ
@alextaylor98:matrix.shikpooshaan.ir	ed25519:GDt3RZufIgjvlXDT++RSBrsnG9170V/OArQ7jAzQrQ0	@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	8EA/+lQkJKlOZtr7hFDH7ISRiCe86uE9M9zuVoJcVZ4CczgZzARbryw9HuR92AbMrol7J7+mAOJF7jRi7/BzAA
@alextaylor98:matrix.shikpooshaan.ir	ed25519:JEWJByMqHvdRd45VbQ89uTuPUUPlJ1EBYuEdQqVuG+c	@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	pluAQ4X0xYukBLxjEziXmf9D4p6XEcXgNvMZrtNX69oh5qfzUZLQFhPgZrLPU2kmXqfoMBMGW1gehUY4kgLQCQ
@alextaylor98:matrix.shikpooshaan.ir	ed25519:JEWJByMqHvdRd45VbQ89uTuPUUPlJ1EBYuEdQqVuG+c	@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	8NNAFYLhukqic5utZS4QYO1a0WFBIkD8FvtxfKHnOFi3+8gghA171iDe1f52/bJ+v2UHqEaIJE3rME4MAeZeBw
\.


--
-- Data for Name: e2e_device_keys_json; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.e2e_device_keys_json (user_id, device_id, ts_added_ms, key_json) FROM stdin;
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	1783667622644	{"algorithms":["m.olm.v1.curve25519-aes-sha2","m.megolm.v1.aes-sha2"],"device_id":"CHFTPUHNYF","keys":{"curve25519:CHFTPUHNYF":"wXEpIBKbBMaCdF2iZg9A1lQwyggMLyB+dgow0RI1bmc","ed25519:CHFTPUHNYF":"oXkdg/UqE7OnnmchJSqrJg0km5f996JhTLtnN2SLTPE"},"signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"cAwTIeIpRs9CppQwb3P+yrJcfZL3R8iKHM3T9vXsGBzN3loOTwwwLHbJ2I+LWeMxmpYJb7EiOTlKK37vCAmTAQ"}},"user_id":"@alex-taylor:matrix.shikpooshaan.ir"}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	1783671796281	{"algorithms":["m.olm.v1.curve25519-aes-sha2","m.megolm.v1.aes-sha2"],"device_id":"CEAAYOLHOD","keys":{"curve25519:CEAAYOLHOD":"6EwlDegmB5extKUQLhBvPOt3Fa8NdBFHnmuKIYqRREk","ed25519:CEAAYOLHOD":"TjZVUwIO9+qQAAEkcEhu7W6cugoVpMZjRO+g6ko0DBg"},"signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"l9KNEArMsZTAsqWtsRocGNPo5H+a1RLOH6doF+ttOyk7OKxORh0qLbJZt1okUyLazp5RVY3/1RZc+o2ghqBYBA"}},"user_id":"@alextaylor98:matrix.shikpooshaan.ir"}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	1783625580998	{"algorithms":["m.olm.v1.curve25519-aes-sha2","m.megolm.v1.aes-sha2"],"device_id":"NFLNJMUACW","keys":{"curve25519:NFLNJMUACW":"AwAHM6NjH1L2MkVS4FUG7WR8KhEnySQziynlcj1+flg","ed25519:NFLNJMUACW":"ibNEs7mp/DodxoKSAFCkfJun2JdUuSx3L+dIIaVKPJI"},"signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:GDt3RZufIgjvlXDT++RSBrsnG9170V/OArQ7jAzQrQ0":"AKR/6SKw2vw69u6mxV5v0nXJ+mkmvt+ARvj3ZhasSja89nG2OYdA4SWoUg4W1dse1DFY/quIs0g6Bb88AdWhBQ","ed25519:NFLNJMUACW":"XF5qK0Wo4qJeDae+qpKLJIgdKzlbd7PgV/wjTiQv2wdyYzv5kUxCrMT/6YTNBmEDAaGUABbJ8L0Je3rBhpxyAQ"}},"user_id":"@alextaylor98:matrix.shikpooshaan.ir"}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	1783627062211	{"algorithms":["m.olm.v1.curve25519-aes-sha2","m.megolm.v1.aes-sha2"],"device_id":"SPEPVPSHPR","keys":{"curve25519:SPEPVPSHPR":"PhSzjo5DIBBKKminzRKyXkypH+XfLbCUIu7bFjMhbxw","ed25519:SPEPVPSHPR":"KUaSQaT2RNJ1fAqImBa+W1V9FLIe8eJBbn+B46wZvcY"},"signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"xWi0vhIvMdU74LmagHjfQ99qdoFVmQAiJ31R+h04TBgmhQKdFCE0K6LjghPnMLjoEPOAqd+uPaNFdqdnZuMRCw","ed25519:Yud8T69IrQtmC/X2KFrPfaN28E81pdZBWKVMAinDv7w":"ieXIja0ur0EgmxT/rBiTitfkuY/Fwa5f7du6xjTc9Ljxq2dX8frvzh+NuriXAlmG48EyXun8t/kA7MR3FjVUAA"}},"user_id":"@alipaz:matrix.shikpooshaan.ir"}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	1783627509975	{"algorithms":["m.olm.v1.curve25519-aes-sha2","m.megolm.v1.aes-sha2"],"device_id":"WGFMZTWZEK","keys":{"curve25519:WGFMZTWZEK":"mp2LoZXnjWpWL98Ebhqh1sWGFwrkf5W6Uv4+iarVlQY","ed25519:WGFMZTWZEK":"h+OWvRGGGxqq4oxShWAHdf5LBaT6NPulX+SVmtJEdDo"},"signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"nR9yA4AK/hvpr0FRxsCvjKOFZmcB63ZypNIPkWPoKVQYOo0Qt1n84hcp35L1ZfBYx3JGDDaj8S/ujfjuSYaQBg","ed25519:fJe66cgaEl2d0NUoi1n3Oph3gCPZWmQpoZ+JVro7xms":"mTVNz6kUe5LbZQ4p4g7l2T9JgRduWussP7zNxVXJRFEQgInZXi5FIHI+sdXtD4PHKGUNIi9yHg3F8OCdYLiEBg"}},"user_id":"@monir:matrix.shikpooshaan.ir"}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	1783672186481	{"algorithms":["m.olm.v1.curve25519-aes-sha2","m.megolm.v1.aes-sha2"],"device_id":"YOCYFXUGYQ","keys":{"curve25519:YOCYFXUGYQ":"R99bo1drmc6MccpCOgPXGOJl0u+ceLj62pp9qxWjjQA","ed25519:YOCYFXUGYQ":"g2O+kEcG0mX7Rbmp5p+7n1ZqEXVxJgrZiX5FNVpjV9E"},"signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"DyFBhmHqhHJhXsXm6hnzRpwdGdPsKN+iImAIRNqv47uyVYAAFsjLZK/GFEMp7oQMgX+plw/xBQiBmaiRihyNCg","ed25519:xIHCRPRA2KyGK1bvMbVgm0/7U5jkE/yA1cLzdtmieJ8":"knhNdp0KevVi1pdZ0tkacvlkUSsx1mHdSgwFyHxqVogMaDwWinIuWc5N0GL8n4oGWjdsKrhJkrbMb6sbI8bzDA"}},"user_id":"@brian:matrix.shikpooshaan.ir"}
\.


--
-- Data for Name: e2e_fallback_keys_json; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.e2e_fallback_keys_json (user_id, device_id, algorithm, key_id, key_json, used) FROM stdin;
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAAA	{"key":"bERyIJBRN3i/y1xermBNIkG9bAlfHbp/7w15fh7fQHc","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"jt5BQWoLH1AZ/BGU/G2nTw++Ywc9lgKWE/0u/B6LSLeYbhYz90f7w/rhD/Z1aEvipXJK8nZ74FyEOJBEYz/aAQ"}},"fallback":true}	f
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAAA	{"fallback":true,"key":"bsk29YZNK/SSaEj7+kC9FtjqvUEGrTTHYprXUfnO9xI","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"D8iV9fMWKC62Avs3HB3nMBhP93yLc+kqLSGE7R1Phzn3KpPwzb9QwD4mPEJLLJTYDYdGibTXpaNWeE5vlOoWDQ"}}}	f
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAAA	{"fallback":true,"key":"pmmTbj+vb+LQp4x7ibzTBHUIsCw8TYHUjwGjaIJ/bkM","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"Qrrtj1If8V6yjypCSsuWrC/iaI6WeYtDiC4ztVMPqGke/sa9q//EEk6yf2LvwJO4sG7AG1+PEK09626K/e1lAQ"}}}	f
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAAA	{"key":"8hSh+PmSUEZx29qPS0dNRGL86uvLZeVC07UyiRNB6xo","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"drNiv+bERiotWIyjkCl/sbyy8ysrSX/qDYo+QaJDxnt42bE2IEYmvPw+cIuvd0i/anqwx/w9WtWqQJBmIZK5Ag"}},"fallback":true}	f
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAAA	{"fallback":true,"key":"xoITnzFOgZcq85ba+fIIfSfJfA9wP9NlrBtU8HnhVEk","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"bKjmAvKwN8U4UEEMp05arkU3bosmg7PLOL4saA/3pNjoncu6jVZ5hreyexF3NQe7AChgeBPAvK6wlb6YR+FSAg"}}}	f
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAAA	{"key":"gu/PREJ3AgctYfW8wxFni0O57LHEZUK3ylx4QvwEfFU","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"CLtf1307qzQ5+bKbvJU9LWcRxi4ZZyb3ztw6SxtP+zdbW0JETSp3ZB656ZIAJ4Hk5NMW/fkVxljgWKscT7bpCA"}},"fallback":true}	f
\.


--
-- Data for Name: e2e_one_time_keys_json; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.e2e_one_time_keys_json (user_id, device_id, algorithm, key_id, ts_added_ms, key_json) FROM stdin;
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAA8	1783671796281	{"key":"OHJOINoyKMxDIDqh0I6bADztGhhdFRXvnBkSWIk6zV8","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"4HzonZWxuN1BXgiEvYuJ+O4XSJd0woaIt0uPAEfKcl0lOT3snMKQInbdLtgZxNEslfTYVndEiaxkHhFll8uvAQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAAA	1783671796281	{"key":"kwY+Xe66ZEFXGiRUDDHJOKFYT6LcDyKM8AdxfXENNC8","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"C1Oei/ZMkYGNqYzEExR1dWrV+atMCDjsnYelQYfWMyo7cE35SOcNRm7/c9utQEdlYY0mIIA8uUK5wv5N16o1CQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAAE	1783671796281	{"key":"s7U3La2bVH8PVUDWjh1JIenSDyTWLRHr08OEE4FKGkg","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"+DtTl53DNtbatfhfgBY5du4N66NQQOIKcZa0x8sZvY5QexJBOvVZl4RLHsEn0SMxR+R8dmp0Te23jyxlyFXFBw"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAAI	1783671796281	{"key":"W4gkrW5CVx45GUbwFfLp/AgEp65bV/ZvCWHiMxft7iw","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"gfawjEfIi91hFBPQJTFjxjiG3rti/YFxS3piE7hlbh+YMmtOT52K5faetiaCD3J/Eo3yQ0GCe9rbHgLIOA6EDA"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAAM	1783671796281	{"key":"RSX/uLRTLirhuxBHVkQ4jcu/pn3VzGCJoK9Tm5u1i2c","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"ZepY3o+MMMCHAh+M0WITsiYsizMiKFNjxoS2GofbaCOfslOefvrTH7KO9WapBz759Qlhr1wqFEucwMbIi6HWDQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAAQ	1783671796281	{"key":"IsRB812RW72wrYHdSS0K4jB/74usmHWSgxB84BUsgGo","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"4X5EOG/R3L3ORaxWTE2lWzE4HYdKkPEDYuNE6F+PnY9Pu1rU+kj7665oGEeo2mn2vbu72eArTCDphWJsBTshBg"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAAU	1783671796281	{"key":"uW3V2AJLRGH7hybkgHWS8mY+qeTCQYpV2KsDyEY4Ngw","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"zRVq/VbZsHuShtdF7DNrsTdhiio6ybX9bgOQAlTCISNZm0S5Q9iX+laKfVPi3HIxJIj48NZ+HLSClpALlX5nCQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAAY	1783671796281	{"key":"zg0lQ2wxy+Rp8f8hX1WDDMPfQVLFEqTZgyLWgD2uY1s","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"5coN62cBrG3fzADZEJ1BTRrQk6lGyq+24mE49aA3/5kt+jh8Gx3f4NKnDs1G2+XDXvVwcpi+RpM4r7f573kVAg"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAAc	1783671796281	{"key":"v2R87kStMcGPPc6l/i5SjVdcXvb4ksoM+K3Xptp/vDc","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"xYbgs+nN/1frkx8Zaw1celxf9l+ivFMRZzy0Dcp8i7PoBXx0NsaRkjkXbdihUYQwxMzJADExQNtaiy571WXeCA"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAAg	1783671796281	{"key":"NcZ+GlKxDm53moOMDBZFp7oNruQVsN9w1if+UfYDOF4","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"gZ0mvA6Np3zSbUuFOPTvEqE8Po++Q2zrdfeYlXg/pSdfpH4d0Hn6uRiBJus47u5ubkdVj9LrOM5hDNREB6NyBQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAAk	1783671796281	{"key":"lxq9nRSMGkeqPkTwD/+mnphOi4URxrD5LEYY/tJUm2s","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"iBHa3hI4E9ofFufQBp6tMYMpLbnjpX9JuJLlLYJRRgcUAabc6GY8DiDoAbnr+obam0t7JvLae/qpT+sjQuw4Bg"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAAo	1783671796281	{"key":"zmJLXRfZdb+kObHnOHGMbG3mx+cWnjOVVX5EtRYZJD4","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"Ktc/GGSk+w09mGGQ2SiB08+e1d9f6cYwsJIqQY2kXFNSeR+siMZ09wYIqzr+0faI6teXBQma/TfEvyWne3YTDA"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAAs	1783671796281	{"key":"xPxIDv5HzZK5+vI3ccbCliG5la+i2rn+1PYkz1Wh5iI","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"366T4ZRlxolyvuFeEeqOYPNuQEVlzrcotLWYcSJK7oASSe48Ej4CvPy7FmkZmBMkYEKidQ/dGtbtuk/+VFXFBg"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAAw	1783671796281	{"key":"9yK/MAozJqIJf4DX36nmRsRhUGaQcjg/54HzmlqDDWY","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"8BJTaQhWM59UpH77W7qiXrxQBtRMJD7+vl0lYmhVq3ke6Kxp5JeEGuMZcgUZ6k2wfEtVmFS3DiyV3CUTlwwPCA"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAB0	1783671796281	{"key":"ROsKoNjKdF1txuCf8A+5cRJdXgoUJ8f+ZGKwqLLpak0","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"SPdnM2LG6vYdFBXj8TuK3SUCsLy5sfmmpUpefkcKcdPoj2/k2Iq38Ajto049FluXVOu2rFdXUvABFkAEIaXYBg"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAB4	1783671796281	{"key":"spOa6/jgc9nnKti/KqWMUEazra8kGcRAUaoMqWfjC0c","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"4pJAVi4d4pN+gAXUJhDzUeKjYvsJYhS2FWkYdfi41J15YdDdqcSWW93e3VaioYvDoQJwlscPLRZWJAFO8UTxBA"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAB8	1783671796281	{"key":"GzPpXpd4tg+5EB8S0vRYLDNaSfB1QlGjLg3YF4jlUW4","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"WVYmgNWS1GbBx0pNwI4xFElhBHaPzXpXSzt0o1miQJLOjmg/NrfmpKCzUo6sORnlxQ3XxzNqkjWGIIprjAe/BQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAABA	1783671796281	{"key":"3bhFhoozJIQHhhJL7MEtvQlNvDZstxM6WAbSAvnBuk0","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"/9rGm5FpAcoex9qlH5xdViuWEARDoJE+Jeo/bD7WBOkYqxCyNQx0Hkpgx+Cz/jqygCLpv4qELiC0MhBSTMyEDg"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAABE	1783671796281	{"key":"6A387p0QQk6Jm/nYQDscmFGNVFaVSJmc9wAmLHKQF1Y","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"ugxDXKJHxsqsavdpZGfWo67HJkHcY5TM2CWxUL7blT3uhCmV4zwLyx7xfDgpoBSw/DIrTPSnCqKyZwbz0gABCg"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAABI	1783671796281	{"key":"kIBB6WRYj8+rBvhcaF7DZcNNp0onElC9WDyR0Wv42nM","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"wsmj456pfFWrxv1s9A7yp669cEWMRkQkZbkuDJIFnqayZIgrs9gdr8JWeDrKM/HgU7tQK57F2UbHn0uut5XUBA"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAABM	1783671796281	{"key":"wkNHJNq/nNCO3RuFNrbUTS1asJNdW8Fxc4lnvL0E8F4","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"9KlT8wDsewdeeEJx6lMDZKvIrGw2bWvoilmZOdqsXJh/6GDgzpmSZdSIM5HSpTLZs4N6dK/M/dbxFGN7td1YDA"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAABQ	1783671796281	{"key":"a+x15TI/4o/n9pMekeA8TwwGQnni18XECNbvLbR2Igo","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"gX/DJsW8fCh1HAWpyu3oUShuBCeHLd94ARkETOlO9toHYyOTawSK+TglbdDta04gDlR3v5XB7RGGpw68NE6FCQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAABU	1783671796281	{"key":"FnNnd1Llv1vuYH2gUykFMNMWy1n5f1P8aQqA1ptKEmM","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"Szv6/sLNBOqyS1VGCImAznRG11zq1CUnI86fXO4QZeaK4ThhmTuj03mXBd/w8/D6r3pQYfTWVANNTU1FBHkXDg"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAABY	1783671796281	{"key":"UBWlWnj9xGBJ3Y7bxmaWaI3Ilsn6OJ4EAEjswZbfnSE","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"YsUaqd9sm83cNOLp9LDSFHGuV/BmPW2E2whodf3Kf+/V0gN5LHoUPXRLBeGmFcJI4/l3ACq3F0WnGWDbXF5YDA"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAABc	1783671796281	{"key":"nMuwztF1CnHIcYPqAdW+i/5C4DbnKS1u9eV3I3QhV0E","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"BU6iv5YzKj165WgFgT2XB/kn+zgSmy95y23+RbzdznFQRccR37Qwx57jJsCqBlGPY1pCofioKDChOYwv5frXBQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAABg	1783671796281	{"key":"91poqtgke8rj+lONOQwXdXjx+3d4XwIuTdYzQWbKyR8","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"DIYAYOYWeQkkAXCiFU/zUXvlN1UHL/SZzCTLHzRkoVJ37nQPz1kqZOGQHHHE8K/9PWrSEmiQ9wYCYMR4FprMBQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAABk	1783671796281	{"key":"UNqBKej6vp7bgBE8nok1s1lZr1NpSXQV4kEJ+Lzurzg","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"DGi1Ek+WHnI7J9P1ZkIuxyNVcr627RxlrlGYCfT4uKgOtNlJhlOckyxRUBfVV7WWQxQYVSf8kp9pNBd/zL2lCA"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAABo	1783671796281	{"key":"X2MswM795dU4O1AR2kAN4He2W3K4FEcGX6VOWr/CuAY","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"f3r2Cg8H1Msb5WFnHwDsIxLNRPKblaerZhzFp/pxyITHbiSu+fN7xDDPavGy0CfGCxzL/jAyHrYxPMWEnzT3Dg"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAABs	1783671796281	{"key":"bShObbmbqi6mUV9ic7s/IPf+316mTBq9E/Jl68wKaQ4","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"9w0Tu1ctj5NEZ8fzy1aFXwQq1RgcB4IK7AsBJ6R6EVWKjNtotOb0/ZWvBgPjtxEQBqEHhJZ6izRAuj2PwyItDg"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAABw	1783671796281	{"key":"wCIsOFQH8auGuFuNQlFaDDRskB6LQ4KbnIhfS4rGNlQ","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"mvCYUz3eJnsrqdNOn0TlVsbdVXnpc3in0XFxbQt4ng09VT5jvrY3h8AVaQh8xwrpOUKWf8GvR/ssDYsAOi4ADQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAC0	1783671796281	{"key":"C4btiLS4l6a6m+pzjWBX6z3HMKGH9PePECbrVMuanj8","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"U5a3dfZAFnyVwVYpMVejZrDhzDd7VqontiMZD1ckwKbU8vP/oQN1isIExj18Bw5snDbNqhMjzYnpwYousN6OAw"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAC4	1783671796281	{"key":"H1MSpagnKb6mw2FKHxn8eW8FJ6I641v9WqcbOvhIklA","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"2HCyj4eSuRGpuCP1k2oqnYg13hJvhtZBppR2IKqWjfnmdkwzo7+oDIgAQhUtv7GZJKOH8szhqFuN/N56y6aUDA"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAAC8	1783671796281	{"key":"YAoeYbRujk0lMb/F11fILb7OLkLWmELQChvjaNR/AGE","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"qvS2N3G9ZZatyQkD1fm34d2v0de9KwF1Ep/M81KKhYjwMDAnJEfWwuCdct7pD8J6OTTsDZ4qq7KbfBXOqypfDA"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAACA	1783671796281	{"key":"0Fs1kHpTHUjiEgJNkcPv8sGo9O2JIa8VzqSRL53Xc2E","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"g/5piFGaNxbNWT6IpFnnc9LBxkEkdGNNPjX3wJdSDd5lPTWX0hh54NbhqLeYQ7g9vRo4VoeQp9a5vBGDFDVPDA"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAACE	1783671796281	{"key":"EvpH0MzoLP8i97i0qLP1s6tSWhYEfxhQbTZYrm8Mpic","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"i22O6a4rUi4CwgJPsTAqn5n5c3XcMPG7+XAVY1VlS/gSkgVuCue8rxNFHze+vLahhC0YPzvsRDElMh5WPM/TCg"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAACI	1783671796281	{"key":"mhBeZ4NgDKPK0M6kug7TNURtRxFb9yz3CPScPNsEeFc","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"jCdNeqIByLS94w3rArHM5tNmQsT5G5BcNwxC05sSIMjvPi4h/Ug8ba00ZYnPQRDR0UsU125lwCQFzgTwN34jCw"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAACM	1783671796281	{"key":"LpWvP9gf+SjIksIUXWwUUCxKJzgkgheSmaUHVEA5Qkw","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"cTvyMyaarwQLglv9Tte/k9h5vN9v30Qj4R19q9nEMVFtgOTzwZH9hCHgdWn1C1QOVaB7dxkVx2EjtNt3jhNOCw"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAACQ	1783671796281	{"key":"5Q0LMqYDFku1CXjos4XOOvptMzoU+iPSD28Dok7spGE","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"OEFEf57dArI+FlG9OJ0nPh2KeN7niaOVuTuwre3YwN8vzMq7ER4c7wmCJ7vsB8Fnm050C4gxrYgVLIxMz1qTDg"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAACU	1783671796281	{"key":"viiB4qsSBvPA7ENTOqnlh+AkNYvMoYwsEqsBCozdkTU","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"8COrPbpqdpFrwcUS0ZLdMduZtmQRL0YQlt+HHa3nHmOiy1idjuPaYDtNkKu8ehMMcuN69Xc0sd5LBzMEv5agDg"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAACY	1783671796281	{"key":"+YEYiQVLfO9chJ7I/WZxNuNKrmvmTNK6pgiM89Nud0s","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"5YAOpF3hOqqKitosv6zWKXmiC9By8v9TaAbmSAAtyQBuRuq10mW4RnK+wMq8bcD+KdIRsv5AUux+CTIZ4TsZBg"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAACc	1783671796281	{"key":"FWx61j9TVk/nB7Cw4WOmxf7uyq3kQnD1+esb9CjG7xU","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"z/LCOvdMO7iuLTnazs1+WtwMD6TRnz5EpYgBsCT1u4cgkCDMSyRiw7evas7X4NTNUNvQ3YwYZCcQXHGMn6SVBw"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAACg	1783671796281	{"key":"tvGcuymmoT8/3A2XSaEW50bPrVQhJt6k+m2HDUCs5ig","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"Q2ytQMtre+5/uWpJPiQmS7Ok05zElNQeVzcVO2aQ24b+i3ywGJmY0yD7dq4KC13jBzx8tuTrOi+r4XwDAUtwAQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAACk	1783671796281	{"key":"CWfCr3xNQsRki5pHNKMHM4aD1ke7XBMTzamH2aLj2n0","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"9qayZTBfgOxbSPZVcmPrRgI40cUq55if3DZlJ3h5qoZPXgvLpY7sntjSpxvPwhA6TizBDU9q9baz67H1lcmEBw"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAACo	1783671796281	{"key":"KrC3Z+eE+4KeVPT3oDR5WbNTyu1yUu9bdDrVhPzxjiY","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"y9O0X82u/ZPRK6nDks074GKF8Ep4iQMUXvzHLDF6jVUOdnO+G+bUsvHLC22RzEOeBOq48uaOYGg/zi7y1vBmBQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAACs	1783671796281	{"key":"p1QNtedUOcb+Ub1xYMUNZIjVHs3KvpQI644r3/LYrTU","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"HYnB4jmLaV1Gve47KxPuphyfHi9vwEXWjrVsqiDtKCji15hcSGBQM9dhHlWE3syeXxpHezCeseCVNXB+wlnWBg"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAACw	1783671796281	{"key":"d4e7yPVV6XBGD1jWflWVsCpBrxz7RgXWnsQPHPL9bEQ","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"xOJdxoqCU234hs8ciGwcYf0ZxjqOdjhXuSi0wSx4qK+pazYNnQezqgDose73paZMsS7pABzwZQndx4Cn1kYMCA"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAADA	1783671796281	{"key":"NnCV5VcmVi3FdZu3Vzml+f7ZXFWQikSMHdt72Qc2RW0","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"8+ajtCwc2DWI/zzsicYdqKr8v7XDSJ11WbvrhxSs1xWSoK7zgamAyU6RPe498HROJ5McYDFJ+hNb0AjkQ6P+Bg"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAADE	1783671796281	{"key":"R2oNmaX4BcOQgqtrWs6SotIqEBN3gqarEVwXLmzLZi4","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"RFxovmWp7yLjMxzu7RNSsXqvP92OaX4THqYRuGDEoHAYAlqxq+8RfE4mXLrbdKlIaSDRaeuCKoySw9s1AApkBw"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAADI	1783671812499	{"key":"2nhZpw7kUWGDRYposTSe/UzWiAWW/laE/npw677Lzmw","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"3+DszdsKo5aFndRgm/viHzzxOCg2oAELQrp7xRhc0oAT2cdw/HonCNExSPbZB2Ix0+yMfq6kywLvhBQfccqvBw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAABY	1783672186104	{"key":"fspLobYHlI26Daf1yLrinJljOTRrP0/Y/ODY6oEdr2I","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"fmoPWhxOBP+qJyeJjBeXuWdrokgwFvURhIXIJAZ24Zwi1QtxCLKReYIaKyIvmuataqHXxWG3zXWxpWh6VYfeDg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAABc	1783672186104	{"key":"AfcPGxopZ9aIGhPEAeLCtEu+ke+MHZrrQpWeJyYt5ys","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"8Pm0HL7eycPmptxHfkU3VUTG7rzYz8SuEr+mKcTZrc1QRPACHFVKiKGCRaul3oehdjI0WhDQkRqdJc338+nmCg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAABg	1783672186104	{"key":"RLYXTq0fU3TrqWDZJHTBQx/E0b6QV3DMs+8R3H7ptyE","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"qXSuTiScVpZfz5ETFWE5DepFnkyBqDIcOe4j1GsOVO0/bJeuYJZGUlkqxq+WR974tCD8SwpqmyIQ4TVy9bMoBg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAABk	1783672186104	{"key":"nAg9W8+Zy2MKiInzrhKnD713bbD8AonyPeH/fLqAunI","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"sUhJkBqaPb2HEcu0CnJo1DtP4aDsWhiLhSKASjNh2hyLErx1jF36oq79luDHU05uGpp/YypfYuluC/eIG7M1CA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAABo	1783672186104	{"key":"FiqYTOsXJPjLj40dlGk1id9uhQrSIdjoxPrrXmFTcwU","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"nfUAw7cGXiaZYJ7HFgEHP14nLXc4q0so3gWA/0fwDFosLWJxBb3Vw7cGyEaGwWeFK5QKNPSVBySCinGfugeOAA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAABs	1783672186104	{"key":"F2IFIjyOOkRIOVMGVGoGt9ZJFOvJd1Du8iMxpS9DGTM","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"TrCk2fmXjmtaBJ0xl6FjB/aSt9PdfRqfISqrBsi1K6el3NM8lVDvsc/jkAclLlIg7dWH6iOrfqzSnN5AnOXpDQ"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAABE	1783627062053	{"key":"9L2Xw0Grqhk/EAyAYant1Slw3YnkI060KvRgo0gt+QY","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"Wm7v2FaOwNhuuwuaTP7gC2wgGgasrtwYbr6m1jhDgJeRvL4XG69gNKwMofLqmABihbbf4Z37oOSNc4LfT/MHDw"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAABI	1783627062053	{"key":"++dDq0Eba2bYNoD21y5cW6BWba+PZqmTft3eNmA1BxQ","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"6HwZpuYM5uNft+q+i72yWAjSWA+O6U2AuOvj9Zzp2bD0rDNwPk8v/1Jjf6ZFdU+UGGvBZHXFgIIwU5nDLG1RBg"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAABM	1783627062053	{"key":"ki3v/BuurdTk4gN1pT1OXL187rVzOqt0HlSk0sV99wk","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"yXNA9XsKjFTjB1wR5l8oS0n9nX0NVabnI1YaaMsIP2HAnYi/kdRfRrlM+yThH7Y4+QPKwJw/58YUz+4ovvPHDA"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAABQ	1783627062053	{"key":"Og5cVd8MDHSfT4sofPSIANp9g9bS40H33P/sy5mZqik","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"ZV9Yev0fA2pe7nGGZ/0n04zVIVROfmj9R8Ba+Doq0cchGzOWUWIpH5PfptBqWcbRd5kfiKD3H1mVfo1e/WyACA"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAABU	1783627062053	{"key":"lgUvn7gYwQSoIKfd2UcvDh0UibFsUYym8AMu4IxlsX4","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"Iaj+x5erVIbBHkD2QxzKLM1en7Dm1h51wdmtMK2uSHZHa68+x6qSG4bU+7+Tdy+iV8pbHL2UgFayT9IwDqThAQ"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAABY	1783627062053	{"key":"ZfbqZqAqXIx01kfCWTGrehqaCKVbbY/j09RyCMEPd1E","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"nkxwdKwkbNDyUfG1p6aKPUGsSVGjenpTEo5sYPyC9G/RSgUA9Pyu9wMvlZa9vf7q0cNB799La4tOp7wHKhqYCQ"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAABc	1783627062053	{"key":"zdEFHC2JmUteXlFpsbXwDJ0F1hDNcenFqv1PW/rgv0A","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"4PeTbcWgaCMHa+MYUyUVdUSJKc7PLqw8RDXdHZxDctDcbSskXzt8IcZv2JIRmzQSYh4drEN5EaScbsiLUCBeCg"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAABg	1783627062053	{"key":"axB3PESSsZECDFNvI3NCE+D59wC3OBCAkCCvvh/nPAE","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"Frf11tkC6ZmQlJ8XHRLsYrr+LZufeApDcjRXHackaPuZYGIeJSrcmbzU+eDFaVaaCNspqk33BKDFN/uoWnnxDg"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAABk	1783627062053	{"key":"Wii1gOgBn45xINe9BdxHKWudR/+DwePJrYdCDsKpWiw","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"e/7oO+CxzTDzIDBVWwz8qGqsgZs9lUI7aDivb5bVbMdZvTQhzEVvBq2zU5oARG8AD+IRpqw5/hOJ2xqdZtsMDA"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAABo	1783627062053	{"key":"WRzYj53PAEDeyYXkV4++igc8UAgcBeLdsbQF2Pciy0E","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"J6bUV8h0EeY3SXKVUagY6NMWpgIMIZvhPtzZKjfcw/FGvhTBTBNsv27gVmvsjf+uiiXOLDaplsiqW2RBUNmwBQ"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAABs	1783627062053	{"key":"TLUDvwZQZjzTmAydtfpKxJkhZHM+s9iDDfBmCEpc72c","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"h1WqlBYGMdRsdPbOe3rNbHBFAGE2IGkDtBRmubB3sGgGptQIs6CTU71O3rtt2cH64MLnsNofXU7RstXGlP3wBA"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAABw	1783627062053	{"key":"Y/XERb3JP1eg+3FbhhsNUmNqWVqB0L7QwbEPxu2f11M","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"jab1ULsu9qFCukf180ewf17zxeXBR1Fd1J42GUlBke1T2Zl/ZUiBxZbJNY1Gs8isFzexXNOw7kD+P9br0MlZDg"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAC0	1783627062053	{"key":"PoZWOIsgDWh5hE4g2gV5p4E3nslDagG/0aQ5Zd0tjzM","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"NNStlRj9udrxsUGKN8Gye/mDngv/+eJ6R98PIyZVGlbz3uqOLNJx/zwO7PSmkRypbKRv1tDtg3L6Su9S4fhNAQ"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAC4	1783627062053	{"key":"9ejjXo61FnXi/zFmkgGIjppLIGTQg71E6ao8xMRyABY","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"knu03+sRzlssgPnKjllzsSWfEFF5stxXgn7ynuMcQBv85EM12MIK9LYGvWpDlLytf70BgDHa2/eWsuynCa+dBg"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAC8	1783627062053	{"key":"8A4URMh3H5Nw5Pl5Fn5K4oBOKQKwV7CBRI1J0XI5qk0","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"nwhSCP+dOxXNvHEoS/9bpIkFELX+0CDzw1ndG/oUCuRva8HBlfmN5yRRIztxMpRYL1rC6S6EEU63I7DcidXPCQ"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAACA	1783627062053	{"key":"MOe0R0crIizTuF078oP0M7PgdrOjHOOYWOc9/vYeRjA","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"Nc6exq7aDRW+YbG1TKnjkYVp9o0DoX0qHLX4KA2LaAHat0Yi6dZUmvPxs2lKMMCMd4BMchCeyukzi63Vb7AUBg"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAACE	1783627062053	{"key":"7/CH6g49w2TYfu0LTlOQW9OKlv2F+98XxHzIro84xkk","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"TKm4UM/LIMpEVAId76BUz9FS1RsSN04TxEcz7iGcMQe9cCTXy/Ys725Esl2TEO/modhhCXof1lJy+EaT55mqAQ"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAACI	1783627062053	{"key":"TXoptNjx4uoOZ3aoNPX07qluQp2F054jS5dmkIuOtlI","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"eSqYXCfUSwkU/qn7oEvAjBf73FLueE864mEHHYokyS7+2aFyvTyJoK65qpQvnqFe7XDuBOGF/Xd0yYXuo2jlAw"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAACM	1783627062053	{"key":"ppDDKdbtygEobU+waScO2lGj/c/W283bqncfswiCfyQ","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"5x8wuI+g9xNChJZVCnGulZPlOOPpQE/i3nX8n2r+El4MIdKFSDKeTnIjlZwA+jNogCZR1BaG8vwV9OoM2iDCCw"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAACQ	1783627062053	{"key":"sq66UH6JzLNpoz+EQdAtwj+Gxk1Eorn/nqY1rZIVuj0","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"wodriGs053Nmwl9jodNs4OsOxBuwSx/EVXvL2GW6AMDKmMidWDGZBJIVdW9ax1q3QfD0mHob+4C0fM1wh7l3BA"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAACU	1783627062053	{"key":"wS5ugx/BPQXHrX2/E1gJ2o4rSpt1dOcrW4NCGrMEpVI","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"BLQsUMfwVTQzh4vDt92opQ+b5gX29gK2qSEjCtIA7UZguB2W3IxrJpuFooLDgUHi5m4dL4K73CI189PT7/oYDg"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAACY	1783627062053	{"key":"zhDVlvDGttrOLT3E/fBzU1TGDQX3Hr+bI5g4ccjPNwo","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"e0FNW6pQJnYHbbsM+RP8aLQpHGOM/3zXH6TN5vsCVNPvRIUiGscqmlQn5IPmvjyAB6GPcGKg4TAw9EBvt9+wCg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAA0	1783672186104	{"key":"kSqBYtpozGI6tmrnD8ikwFFSxa9bwpUyAMhENqMh3x8","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"DFsDu367iEJsNKWcEEU1xqUc9B5g4yjmkh4j0+Q8GGxh/aLvxK75ulxWL2KqHe0NRaNX1Bnw++PL8T9r2e4wCQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAA4	1783672186104	{"key":"wRtpehTKlt0E9+Ooqm126MuY/dkPYGRp3n8Vonr76BU","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"+nT0jEpT1YlWhKMeqhrhzT7nndC35HnxMhOdyjKKVrP/8qKIxq/KJoBEyvaVnyb0SXQCeBhbRjIDYpCoJ57zAQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAA8	1783672186104	{"key":"p8Juwbr3fTtwZe24LzCqybsgL7khZlIVbhZiFiBA+RM","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"jkXpgQ5H66VpqG7XJ9iZHYbtIvY9hMIe5ISbXKlbfecvOndL1AOVc6eAFGvjFzSYbI2VpQHPl/kNc2C/TFUkDQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAAA	1783672186104	{"key":"/MOdkaoihcRtkE1k/jEIrDN9lqQ/Mu6Ew/z/dnaiQHM","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"rXOT1lm+AL+GV+S9z5yHyoQ0pv+661RslfGqayrrhB8//INnhBXMyQAelTNtBrmv4vP940LNeaxSRQvRY/o6Ag"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAAE	1783672186104	{"key":"otrd/NLBrFO+2oYkpcwuhpWgkhGLKSSuvdcPOqEHJiI","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"RF6Gm7/Fl67TDgYgcrEcXLecUB4EBPVN7Fpid5R92RHkKS+IqJ8T5+r5HvbKZPk1BzTdCOVnjgFDZ5ACjBrVBA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAAI	1783672186104	{"key":"Un+3Rmtn5bCFiTcPBYU+1KRSsCXjER+3xbXwfnNf+wI","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"215Z8hCTzndpBcaQdGFpLx35+nt9HnB3++mk1bv8c0jnuW+unWb+SNqTpSgSSX9fwEo8J83maZaY4w5Z+piXDQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAAM	1783672186104	{"key":"vkkcaNY1uxAwO+7LB6riVBEJm3+687DhAwDFQARpJjw","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"gzGpaQkn3roPKLH31shTRLZGD0zj89S5X15nFMpL+GLaoi4opqk3k11cWG6RMUkVBDquva7M2ONSBWAEm5pcBA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAAQ	1783672186104	{"key":"vTBDtKnuMw+4F9D2D9wPIw/BQm34MFhw7pI9OMgThC0","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"4ruMBFD+a632TIib0y5Q+feYTFbeXDNz9WMhqcC5p14IDCRl4mIO9NngcKCtGGAzqgt/H5eXW3l7k+6W2SRvAw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAAU	1783672186104	{"key":"3j49r7cQcx0ReR4Pc4bImJmhDZMluW6bYneqW/x1V1Q","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"vI5cYR1VK4zOKVTjBpBAOuNtYqWITlFcnF3IqoU6IMnEfbjw6l+xAvEniQLWJijaAt6sl8SuwbtSfnpMYQ5aAg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAAY	1783672186104	{"key":"zX+gw2NZ9qXIFk+8ba4Sfhwe6KwcsL4VLgDG7NsCcnQ","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"uTd2F0Q5bH1C07Wfa+Ts+fg97eEHTJlSkgbCwJGfgMkVr6ywxTy0b0+sORqP2MzNusOBqGP7cp5be2gumK1nBQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAAc	1783672186104	{"key":"es3T7bJPBkMm6oqVs9moZWGoH0gVCjQgzLRD5MAYpUs","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"55Aj0sELNj1/pqI4xXLhKhWAt2G0kqOD5T4IeEjMog8R3PBC5Bkq4Xv8Sa5BDSlOpPPNutbmvPdu2gRWnLB2Ag"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAAg	1783672186104	{"key":"1qWS4bCJ4tq5suyFO7toiTGtDPAmoYojsx3bfrOfPUg","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"amH2YdodGO8obvQl7NesLcAWZBxH1XK28sVL9pwnXp2FRlTor8WWVHCWPnSSmhkmbQaTL73V8kVYKAURuUYQDw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAAk	1783672186104	{"key":"6F9VI1H6MVudy1zqGteEh89xsFaiGvqxOoTX+HyMmh0","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"C8POBsQhw6o0d99bHOuynzn2V+dA6oj6lCI720svRwUckx8FwgDilrFdG1ZmQQhBoDxZE0LUgSNc21bp+f4zAQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAAo	1783672186104	{"key":"NikyoCyDx0FyN0ATwqcTjlWzLZNknMZcNb6D1n5sEhA","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"v/JN6OWDTUtjPihPa9opdi0vk9m7BLYUf9u9f+gKHEGFjkCgcHJoMA0B5YBtzNzxS6g8ZKoAU0WtKJrdwQOSDA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAAs	1783672186104	{"key":"iZTRSjFNBR2Nu5DyCiPUd4tFtEoJjrHZSEHiqme1vB0","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"5Vgo/5zDZVwCINzuse+PDUrujnPJz4naB8znHNfUXQ0XgHlODzqaW2XiLpXTFd3hTKtnOzl6hbKqPZzrubotCg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAAw	1783672186104	{"key":"FT7uH8UsY7CDsylTZiApaTiX7adn+orG8sMYeiFdj1c","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"NfEBEzH2ZJ+kFItCLT/2g+ZYORJu/5xkxxisPaxXsf3Zt5geB2AfmbAhT69a0yeX9p2c6s3xYTP1PYuwgrdtCA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAB0	1783672186104	{"key":"WGu+sOCUGAxnLdPqSMGJUFMyvjJHuIlcQo18MvrffnU","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"N2m49RwNIYkCOWxkdYGExcd38mXDCDB8CzzhmTH0u2TBTKAQbuKRMU9s3ak5RA9wHU9d4PZ0BptRa9w21T6TBg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAB4	1783672186104	{"key":"LDxHCNgBK1UknKBolDd2bRjdZBQLuMfbicaOQd3hC1I","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"YzLlc/PJd8PMxspNgotY4XAZB2Tr9Z4ZHrEXMgFtaTasL7ga7cYMbrytdC2bhbRjP/4bw1HubVrhjL1u+WbqBQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAB8	1783672186104	{"key":"qiwptHwY+e4eZhY+3ozbARTaUhYrvO6gu8MuNao9DWI","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"A8usmXoVQb82J82BCig+ENNL3HWF+h7GlAk48j7yhKZ/PWaMGyiMgQxhsIEwaXcQyP43Z3KtfEKPxKUqKdZ7BQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAABA	1783672186104	{"key":"S07McH5wO37vwn7GDMXWyRKTzLmxFM8PuCe4O5r+AmU","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"VioMzpwlRk6wkwI76dK18NAMH3z1L/mq+24XgRqyGbqB4pWZGPYx0+Ts/ouFwNmie9/C+3x7YhpYKlG2+iG+AQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAABE	1783672186104	{"key":"mcls5UL4VPaGa/4l9pWob7jSuAQaGFONiUGQjJeqSB4","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"dzfrdIFnkp1PtG9gSdN9NQyGbv7tYTrOwkdSoIODU+eI6C883fLB3guh/OPkCirR8JPlxCBd7MVoq5GfQ+JqCQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAABI	1783672186104	{"key":"loQSD3xgUBgrcryQDrx8ej4kJaSzowN3xhah5EDFu34","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"4jbSWz+CnQBHBgVQwo/Mc/Xa5LLqH6dr0HRrJ7CfBXa33ymnOvQBajc0TuARcnIbvIgcvEAJLyQPOoKdzSxWDQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAABM	1783672186104	{"key":"KJOA1DntfIrQ1G/AZ4f234oGPmF1INlbPtDCwJiBfTs","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"KhmsWBQ0dFngmj8Q0/+IIN27ysStQgC3M3661CFUw6dOyWx13IaMhlUKvCVMhI66qzt5ro4aS6FYZWmEbfECCg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAABQ	1783672186104	{"key":"5qG7WpS7R2EwidZHLEHp2LiI0mqLJQ7nQDPiQzGR4CI","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"1Mzjj177iUKrNclpgSJvBgavL5hysn4yrYpbIu9T4YE2QV0ExzBxka90ZuCXN+F4pjDNPo5b2tYWJBVqMhKvDQ"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAACc	1783627062053	{"key":"9gOP17XXZ9KWg68woIdu2OX6CYquf6+fO9pOG2lpzBU","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"ZHQ3alnMHohX7/2I1fbKIC0llZgs3z8IZT4zQiLzKWcEoTCF1is8UugFtDvcuk04T1PMdD3l/tQvHWMhvqgLDQ"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAACg	1783627062053	{"key":"/ioy223UjTq5rM2j/XGkNsyGwKe77EyPc0rKlh46al4","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"09TzNT404tk7pZr54OuPVL7IT4gCR0sNU0Uqq1tDTOVLAUvtVPlRiabDKtcLTuyJVYxybYB84PNKE4gUd58LDQ"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAACk	1783627062053	{"key":"E5/ylVKmcROXaYRIMGj6yWiVWPeyzujwMB4eDObsdjo","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"uqHzQ1rGuZToeCyBoN98OWlC8eq1H5ar3HhoFj5B5pPLFqKHboMrFNnVk8OYxC3MkHG4uldtiG2aJmX7Y+GQBA"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAACo	1783627062053	{"key":"oDbXAePRLxFZmL6EiKGg5DSoN52oixQIHWo8lU+jY0M","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"tgXSdLa5TQUsHPjtRZG1yrXhB7aFyAhQNyaWne9kTPajBaHzf547ul9EeWJ6RSsI8KCG6ygGKwtHY1JYfwJFAQ"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAACs	1783627062053	{"key":"KXeNBrQy8uxvibIll+CQPY3Am4X0daqIi230vvOYbTw","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"CbDV5x3/RUeFnBY0uKeaOEhfOqzx1RiuD/hQoZMjvCJlYPByIub2oRkgF6Z5qUaZb82e76bmiNy/8AjhVKwaBw"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAACw	1783627062053	{"key":"7lBoc9Es+u/CNt2HKQHDhDoSLfAZPLEnknarXX4GhS4","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"d6b3UsFkLmC04AfRg4i4yKvqaqdJW00+1JvqRFsshPFtjLaVqtbDQ4P3KeS0Bf7YuIbZRIvOvcI5mk7dXMlQAg"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAADA	1783627062053	{"key":"fS7iuDGjHEOXIqejEwJ9T7v8SPLHFuXzsN63/IPk/mI","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"17qVU8k9whULtmQyyZ6p8rP7lx2+0aANcVArRepeZ4ScJ3cLPH9fzz5Sw+CKZtN2gMAW0D6iFMg8DimJJsPfAA"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAADE	1783627062053	{"key":"p8XGNUMKqvT4ae/QgBX1Gv/W96FF3WHe0mKTR3y1HzE","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"+B+AkBkF3+gMwMo6nYUeR1Fbwr0lLZO+T04z7oCrI8n2EVedq0HLZvuHeyrDUoqK0NmV6a3jnKWdkNw21vlsBQ"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAA0	1783627509932	{"key":"uLHgYLdUXma0YxbIcpLTGdm4dyMtyJy36lIbQSaml2Y","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"wLo3c4UoUCMKC5wLy5VQovb6ZdHVKXfnoJ1oaAAs2cxNA3fCDxWsoNy4Hdls4wIkwsg/02p6OOH6830uY72gDg"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAA4	1783627509932	{"key":"5wlwIMKeQOGqK396u1sGJk9zr34l4Y2m4IEBfDi9KiE","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"+SgXo5etCYZ4vjDrS1iRygz8k6aJNyzViYhnZDOxMC0gO+5QA3R86gx9zlxztkQYw7HcKL6X73GrRGuEio1cDA"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAA8	1783627509932	{"key":"MUFpR/5XIA7wYYR1e9eEg67gi7hA91oYzYEN85HBZx4","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"oHvVncg7d9pbbP+vpzI8mQFhQfjNXvmxzAo29I73DJGNANYZ0GqOpMmmuefOianx3OqRwkRA3da9AKyhAagzAA"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAAA	1783627509932	{"key":"BB3MyCQcT3ICInmUqtrnxXk/Tx1mE+VW1+k3nDiEaSU","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"SXpWta3d8aN3SRF78L/Vz5wW8BwrUpDPnFPrvaBRD3w8drKpANESwMt/wBd6u+dI54FcAjaQnv8tgMEGWCMbAw"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAAE	1783627509932	{"key":"H67AqE26ZlX2Tb0Zr6U0VLO4w8mg3SUzhM++FsmQ2xc","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"3Z1y2XXp6he6Ue9uGftSlrX75y5B94uDlZTERI3C51K2UjyrPRrpILsyD4OBhwB/kmd09ovG9C7XTKhOSR2PAg"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAAI	1783627509932	{"key":"67bkerDhGe3fsjIXrxl5oDev4iP3yLo042+OSiOdOmM","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"0MNS/WEueTdVF7AfS4156ooHCvwjWLn7Dl15pigvXWpQr/n9KFDrqEjHwV50xJQC0nInd9CRFCozszshvCBzAg"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAAM	1783627509932	{"key":"O1b7AgAsDwFDbqK4xmd0qf2n+HPfwm0pK2zSBbLFg3k","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"cudt2a8EdwQE2o8QkIHfiCdksxOVR6Fzok8r+HSwiI4amWZMe4uAbMgqJKfYGm9IF7mR19yEu8L5Iv8AhX9mBQ"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAAQ	1783627509932	{"key":"pj/enoEaZpZFJwNhdB8Ayd9G1uOf1aokVZSnoL/S808","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"ASBbw8TbLO5kzZN0kBLLAJMPCBCAdWzVHnVs/L3RcYRKFUE252Os81D9yyqcEH4gO5heemk/X02gG2Y+FDckDg"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAAU	1783627509932	{"key":"RlDE6jWBhZ6yWlKtQ50btdYDSmWHoIf6tJ7rZBo8V0U","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"/vKjUom8ZSf+nrTkQVrYaNrcUAF8TZnRG1oYrK8oD2rS75hk2vO2GgaRMkErDv2VB/aJ/xp8GulRDoU1QjeUBg"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAAY	1783627509932	{"key":"F/J8V3dkqRBccxBHijKRU9ITW8mQjnazcPsnFpES1A8","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"BEpg+q+ione3e8nh7WouykGbwXcbaWiHJGwIanBE7N4/JcgeFjpRb6zivniMiMDOhjsJCNyexKSc6+n10OC2BA"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAAc	1783627509932	{"key":"WHYx2OMGeZ6HUdhIf7N5NGN/JB/0iOzpd1qwMqT9hkM","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"7dAubo78BvqkmsoiQkV/RVCQEcy9FQ+ZbE/quK1P9iJcErm8aaWol4HW5yusFuWYVvWCvm2lnGhYLGGHqZ5rBA"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAAg	1783627509932	{"key":"Cl8z9nAir+bc4+1DlrUzL0Zj+vd09AHsxqdCWGY1YQQ","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"dF3NSx2m3Axc0AZkB0s7RKdgMHDQvFK8nhTnsRV4bKZaSL77n5hPIVDaNiSr7YoWLLG9afVahUACylvCXRZrCQ"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAAk	1783627509932	{"key":"F7p3xWYm5mioJqow2vvwiEKm4D7feziYMOavePcgqW8","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"7A3yLOM5Ae/6SJIxYxP/GeZnJhTejL6coT/ym/kIIYhBPvT4IS7yonXlVRxXn5Q315ITsc4dSa349Mq3fJ2yCA"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAAo	1783627509932	{"key":"NGQHGW55iMdDAQTlpFQGGKidprZkhSIrcq4p23xUt0I","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"l5KI2bjyBG19gT2DF8g85hXoV8aARPvRYa0/KqUmz5dKHG9zMs/tOkyhWg4MHdrByAP6iJMz26Shvt4Kz2T2DA"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAA0	1783627062053	{"key":"eSHux6b0xQ8o47TIQcoWbA0vA8SOiUbAWnceRpLAZxM","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"sIN7O8b5nXQs06ZzIMaVWqy88MoD4WfM6rhrAVLmj4Rmdr4x37ERh/wzEIy0qRMvs/135JSwgxXT6ZXadfxHDw"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAA4	1783627062053	{"key":"kTEUg0MmCaZ+mjc/QLTfKPr8JnhItIzJ7JbPS7ML1Xg","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"nFdcVlFc+GCLNDObfTI29DyyKYXGI5tHP7KHnA6jNMIJCD/b0zdcSCL9C98XmcFrh9RhhqFAlgJ3rn3k3dr+DA"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAA8	1783627062053	{"key":"lDQEKDyipRPgXpRYHMI1GkcSfJ/BKbPEhtf+JayvJgA","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"X5yFwILk1x6RYkKZPZO3ZvXGGJl8PewTyqT5oUT+oHdpGGqUKpk5SG+RlP/JxnZmyiK9HqLtDujh/7QKZOnEBg"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAAA	1783627062053	{"key":"kWDA531TUsakkFI/tnrNR6KuJVT7HpXg9P+wPPcMFhU","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"oufvIK4d0ziw295fehu8CjtVrrX2yP2a8UxaYSQasUGb/uWSfzmr1qsjwl8NKYj5H8btFcU/a6x+WLmH+9gFDw"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAAE	1783627062053	{"key":"wOJM+mmn26/RTVx1+/YFQN7SMlCkU694gQFX3Kr5Zzs","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"ofEIsw7mhUsERkDApgLHRxJohGo6uhoVkS9epp6aMr1c5bIxFM2O56gGZdZzjYz9QN8bsQAXvSbJKU6BQM22Dw"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAAI	1783627062053	{"key":"Zoyb3XyxZAIgZj4WhVvZj+CM4C2qmUaAu6xIS8eLXzU","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"qvRaJsPHaDTkAKcJb11VJ+f/omM4KX7JQkzxxD9CdJV7xiQQ7uXxWEorVb3WnJQUFIsR5zqfS0JMihfVBj2iCQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAA0	1783625580866	{"key":"Q+9tlSkB63TWKfnk6jhYf5NdwlqglIQGvXhA0CNh0SI","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"2NlKaELwQeqCFPlF+08GcpFY5D4fqN56gThLSFiOA+pMhseAf11tfOeVhbJeTCVfxEtcorC1w5R2kcF51I7eDQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAA4	1783625580866	{"key":"It6RernYVZVxY445bIDv79HQ+oUwy3j/0Er91n0hOEo","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"teYKU2sChWKUdkjDVPQX0U6XYgdH7uOHKz8TxUpdPbcoWqJBrXV18MHIZAYB6iIvPl4/Inmbs9o+uWpFrYzpBA"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAA8	1783625580866	{"key":"a4Mt67XBBupBgbuxmlyDb2av43dOe4aknZw2GRq7cFE","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"iDjkH1JMt10U/Ps5ICn+H1bTRz0oSV2TmUXYQLHBC84B2UTkBcmbtki2qUn/Ms7GC05tZ1BEaZ6auddTOpVvAQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAAA	1783625580866	{"key":"3H+wPnRNJahH5NItj+vMfx38TCSKb/ceMCpC511TGQ8","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"JDtJJrsjk4RowNAU4vO3an70b3cJHD0L+ewPuzaq13G6MYKeIQ6V2G8ILnOpwZ+Ek6VOH7DN6patfTHf2t+zAA"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAAE	1783625580866	{"key":"NNQSY15vXuh0C/8T7ciQsTVHy5whFQrbJXFmoCeZShw","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"xI1Urc+Clo4iLxFvFy0WN19x8b5B9rncLb6P//+bADkLVZNT4M47bbHTYf5EJgh6eVWInhwhJPR/Dux7BWRvBw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAAI	1783625580866	{"key":"41b14yDFHW/UyPrmmYs64nj4DlMvhvjQOPmxq+T44zY","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"HjGA/MW45NI6YN5g6JlGli3A+Nt1mfXJGiKbxNC4j4R7FkfkEn7EWjyOovLrzvEHzAJsZoJP/vMqYSXuFVQ+Cg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAAM	1783625580866	{"key":"Zj1cN60LZRGY8TRHilG0xsNTfUJu175+rwOBQW6NURw","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"k2ucPmv264oxrD4zI+5qE/Sli/djB6GlyZGHnvX3AU1cD1JmrFo/KR2g6/UD6qnuNMXHo7CqigP8+ctk2vGiAg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAAQ	1783625580866	{"key":"vFueY4yvmsk5wu4Rxiy4I9UxRMpQhbWNoTNUdZKum3E","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"NEvJh+8XhwivSJA6iPQKxogd3gOv/UZPIa3u3yICKjhlQs4LeeYlHWObVvSIBG+meA2sagZUnkiky+3bscv9Ag"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAAU	1783625580866	{"key":"Gfat08UtuE6wt5gLeKaoAZOGkjXJwPKRM/SN5MpWsBA","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"ca8JL+c/xfYiR8FXyz9vIMbCpFl2QR2I9eJF5Z7PWUHTHRQW7cH55xEgMwji9z+OEJ5RSR9IRzWFjLcI7uRhDQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAAY	1783625580866	{"key":"kNMDQoJ6bDYMZm9lOUkrs4RjnZU6CEbCoAbjTWQKIQ8","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"MwAAyKjCbFto3mwof7dtLpSdjV/nITO3yS35oVjXxxQdXExD3bP47XRcf7jSm8f92qeLpVr8R3TalTX4BKHGBQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAAc	1783625580866	{"key":"rDFudMHhQz0ZhaCQ1s3UMqcncg7XJNymji0e8UklbHU","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"FlzvSiIDSsyYWP6AxRLHdEt/XYRS/whT9HafDzK2ld5kHmcOe9Yal3sxUvvhC+Joggl51sm9pHSqnpS8Tw5GAQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAAg	1783625580866	{"key":"hhtW8Wfhj0YboKaXOABzbLzaajr5Dk0aF4JQidv/wSU","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"MrrOLwPhpH9EPpdU/ZMQAldBlxwZhDiLh9dqNIhNHOyC6u9z9Lbm0wP3saW7SfaO/QABK/4OL8h5tk7Fb/rFDQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAAk	1783625580866	{"key":"a51qDAX9YZ2eo2gtDKgovEF3Fl7YPUeFkDFEbYtRsHA","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"TYtNEHCAH0WbRGt60vIJZsy/Pi+aHYDUTeNvfRwXxhjemW8smUorL0hJpUens8ubmAn1TbvSpNePOwAM+MiDAQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAAo	1783625580866	{"key":"kiG272yTmrgnvIDd91tTfYgAahZdrMTkVav+6TYiyz0","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"Apro8iDtJqcWUQBibStgieQlri1QNF2vYaNJ+67uFz5UL2w+b1wDLfRkDJxKrteqcPOp2TLImLBgZXi1E+ZwDw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAAs	1783625580866	{"key":"gX03Lo9ebySE9uFbwETjz09HzXaWNCRP0GxFyhGVCUc","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"HtplhpDWMVGRBccmiPrCIknloPADqj1awoqzYdwTeTfnwFDZy/Al/hMcJdN0lzEomdT2gEB+Qjp7D39C5g7aBQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAAw	1783625580866	{"key":"lxibajGTffF8JDouOfdRawi7zsoO2PZsoxWtReBBk10","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"vk7O5cWnFw+IHkM4vIZ1BiTKPoADaizz4xTZ9RcuzD5iC0hEhosHkTGF/ETfD166vpayeKA34CUTbz4STfztCA"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAB0	1783625580866	{"key":"ky2ejfsZZvRPNLCphQaNFMDVJ6uF93V+B19RFu9hfWc","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"uZBQWd/XOwisULLzSJrPwZejbByBk8Y6pIWCV0ta1NuAt6+RipQ8M8BknE4NF9bN1xoyeCCd0+WivZoVkU5aCg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAB4	1783625580866	{"key":"iVST1eBDroArJ5HP4yyeiLjN93k6QMlYqwRBrmfwJn8","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"1izIb+3uXOCtNXtEmZdRUOScRhMw7oLaZHGtfoBjaXTzIGicZIkOosGkurgVp9OEJmuSLVZrvkjmHoY1DqYQBw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAB8	1783625580866	{"key":"Ps2F2NYAH4BAxE64bIUxCFXXbjH7bWH9XJh4A3bqdWE","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"EuRW9vNOcRjF/b/SYjRn461O8yvR1i7ZzhtB9BcB/NE2ZAe0Mkneyi+EedQ82m0Th0Po3DAtEyAozwRRkahoAg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAABA	1783625580866	{"key":"jidbnn7NyWYOnVoK9u/ivw/EVCjndZUFPrxWf5MHhBA","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"6bEKyZl4l8aPui6VmOZ1KxBQpch8bSZZ9J6D4A5T8mAlPRWMSR53qip9fUt/zftrL63x1AvFQCgbmCbfMDaAAw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAABE	1783625580866	{"key":"XdNA4lQ2M7EaE9oKEnW4gnYP52EnPuXp8uwqweewaWU","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"YZDYFi4W/oOkSjOdn5UYfzwQCCmLKG8k6YIEanjcVb5NQXDblgWjaCBXhcMEkGOQoe7I0gDDGMyzmMtjvOC5Cg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAABI	1783625580866	{"key":"OQlWlJE4XcSyksFxpm7brOlsalUwstozX2LojRgZuTU","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"bdtkeYcRvL+B9nTEr70DWytqjW0OIz8A/sfad0ZgHm6sI2h0IjOlXa6/QhwCmA3eO45+TZ3kXtYfEmZRTBIYAA"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAABM	1783625580866	{"key":"2998/4c/gqAXrkDRetUW6yl9ZEsJhPSaDvmsofBeaRE","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"QafimbB2GaL41mtC/IiLHxDzaGIzPn/f0TX+dTQHSgrNy7tvPsBBmAm0a+MFrFcN4ZIsk9Mc8NObUNkUID4wDg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAABQ	1783625580866	{"key":"PWa3ui50vBIDmAFXbZRBRbfCVCivtmBaF9UY3LmvREg","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"P8mhrI98qHvBJ7bSYbpXj8tmgsIoPSC5fAPlChz+6xC9hmJK+bCNKVWRO/fLK1Xu39rr4cyGf+vlR4UjxLs/DQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAABU	1783625580866	{"key":"HMHKjxj3eKGTkl+M7Cbax04mt25XOCiu1yesO7G+txQ","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"7y6IltYVjb60y19zTwohWFSiaIdrTcHoRA9isu4+7UX4B6OHnp3llfXwXhANt4obqizEVtVCncztQnF7T9yZDw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAABY	1783625580866	{"key":"G7TXoUMI6GGAuJK9FXUIS6tGaVbB9yA6C2xEtJgHsBA","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"IswYND7jvMMVbOsGLzhX0/gGvj5+/tB3dsyeNY9rTBm0SW+0NMuBconp3XK2/8F6N7xlQz3AgdKKf7AD7heXAA"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAABc	1783625580866	{"key":"q/mDfpaCK6mCbmjFxbwaGXIACYG/l4L22i5qY0UxsRs","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"LH13qzJTi15fucYWURHkwvkxcxDoFNeH/VBS2I5TkgKPrftAZ9s3w50FBeBl3U6OOfgPkElzVnNMkI9ujRjuDQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAABg	1783625580866	{"key":"kVxZsGkwlSUxYQlMhdpZ/tBOoG15WrwgOPSr9/v3NS8","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"gVriYAIjnNeQ3hJGBfg4mjvihFfrlbTLfHTueLKDZahyzpGYTODvWHq5lbH+X10pws+BnH302yvsXYnqTvRuDQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAABk	1783625580866	{"key":"Nz92qBjzOscIMaPEFWrO/wyNkwLs38Vuf6qTiIn+1Eg","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"sDEHpJCybQRXFDbesgNBiG6qV8088EvdRFwTsl24C2RBrIOh6Ke9cb1e/pwX57xczj5yZSwDX5BepcLaUpHuCA"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAABo	1783625580866	{"key":"MrHYAVcGZ2GUthC3t7s+25gIpzVbX/mU+UJT+qSXMWw","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"L/ccsvPSA2MaGOOrFB4uUj1S04Zm9Rbs/NdHTWD6oG3yTzbYFqtdvdCJMsLlsNGE8RXPu7w4TfWs9qC9Y7EiCg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAABs	1783625580866	{"key":"wjmj4i6vRQSzRWa5PlKlDzgTFq08RSMus5pYkC+PrAg","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"Ne2dVOZeD8S/vW/y9SrJlmj8o7uI44fIfrKua/w4jrS00wOABuG1/vjxyd8BFHh4eNmVRDxxI/Z/mLtbw5RTAw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAABw	1783625580866	{"key":"BxaH+FsWlTrfr4EwTh7Vml6dIDnUO0tJgVA85RCLQwA","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"y68kCNi9hH72I25JNyQkIY7bxfgJhRG9z4nJ09UK6sGLkP36THdca+8i6KfQl/yJIzL6QrKCkM0ZXbRYGpBkAQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAC0	1783625580866	{"key":"Mu56akebJua0g6vAP5BBbLwgKl4W6fAnvir020BscS0","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"rGdNpJNL/wO5tAiH+QHa9pisUgMqUC2v7HNUZ5uWrMfT3gUkPzpcsN3JRbTKDRqtiehPMSFczt+QPLAHKr+tAg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAC4	1783625580866	{"key":"5J/FDe1CMHK/Q0nhrgdqrnqdA8TXxe3ifKbSNzjqixA","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"RV0LwlBUiqUAr1GQ+xyymIbaTrhqkdkbw/6GxoJpiTcbD0781WbJjW2mReX0U7nWpJCO3Y14Zw/iOtwIiVtsCQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAC8	1783625580866	{"key":"kEfpIvxEndoEk44yrRGgjezOJH7JQ5iJxXjVw1yJin8","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"9BRAc9rqyixtm/5gjKdx5QLAR30uSZnLaoC2OsfEKVmhhZadPU2bakzgWds64eouR6xvbQejiDWauh24yjUVAQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAACA	1783625580866	{"key":"UQJaYFxMNThZSNJPqPz8wTZVtxC+vb9Z/T4OtmE8jkQ","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"3yPScju7c8hMoMfNn/rzPECLAr/0faSAocD8IV1KUcRP9hgZ3zE7jtHRPAUyDeOfj07FlF4u/eko7SCQtgtpBA"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAACE	1783625580866	{"key":"SP+giTxxL2yUqMCxd9xbutnx4iXWhCOAMwHX1K4yV2U","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"57jPCsJUnZTNdhaPToHN+hZ03yYoFB4x0qLUmt8l7FUdix2Dai93pU1noh7YEsYARpb2wiUeImvxSDr/B0EaBw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAACI	1783625580866	{"key":"0gz9dmCLp7KmT842aeKIkH5WAT/TRM79i15KPq5DwFE","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"Q5dkbXZGNodq+vS66u8kqoonb1tdkLlYXYfNjGVD6a/Ec0CyqJACcU7k1m9jlaJgTh/G6SY9Cn/eqssxBtR3CA"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAACM	1783625580866	{"key":"qG8cWoV1q8XtcKA/7LVQMYRKptYbdWW+BQxmfuhcrw4","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"QpC3WJeimLSpL3GOsvPtz27Q3T5SZgdyAam1hzMYFu4IbCXjTJKwatTv4qV9zIto10/boz/CXs3JmKqqyjd2CA"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAACQ	1783625580866	{"key":"CgyqK3DLbT/l2y4CVkr7vSEgp6vbXaNwZ6l5bFEtgTE","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"GAZlTzQ6RYdCYBPz7hzLd/SlvnbILbAxzHCfMyAmgiil4tuxdKteOIDVV15J+qYY4Cj/rvhjbaSFnkBDOEX2Aw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAACU	1783625580866	{"key":"QVJbiSId7Yt4/pnYDaTUVGTs0XyZKILLjiwpuZHBdmU","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"ktoYYIeo9/XU16baTLjnaXxQRJFt3sOUrof1YcWGfN7pRwriEl0pDtTAwtLxvNGYhvr/6Xwa3ZMcUkvo8mXNCg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAACY	1783625580866	{"key":"FKpiyDh3QBkdQUS6+vUHJvj4CPSgeuKxFuUnqMyhsyM","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"6zJmzyrJTcuW/sV8shzANwlGpozQ89fMrajfUNCKxRRA3QTdGLpj9427PjOj9JxJZ9Mo36y/yxZQQ5RFmHgwDg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAACc	1783625580866	{"key":"BTZmIsR0sA3hEhiExniNHh4FisYZqnsj+3qED9ksUgw","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"Gk/k0VB7vdBwgRZQywwsABxOdgb15XX9BWXu7HjBJ4o7NouZezW2UyD6dO+2qeqXpB2tLAmSMc8U2b6ikEIWAg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAACg	1783625580866	{"key":"1LCcBch9S6K1p8xh901SYOxoLjmuY7/BVbEm9NPnsEI","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"OnQT7pQ8qAKsgmleMuF+68OP+6Xc1IjigG4vpcCfity0iCMQraVxHQ3210KBtmQLFgglegiEFmB7NAdyF0s5CQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAACk	1783625580866	{"key":"+vzP56OC9YPphzy3MA1m2X6pLhuJfO+pXKkUkLQg4EI","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"vUprrynM+u0dkyUD0udBMQW002ewfakPrEwbyb8ak9Btnt4LtYMk62AP06i9EVmh/Gw1PCb8cybyM7r6/3A9AQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAACo	1783625580866	{"key":"eskh0CTwhFYddtA4qqjFiumK/xwy5xyzrXrwuVdtS00","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"jhhDVFYSL1Cm7lpJapm4NPpEAYS9epDS0VAgJXi2cmrMo+qxwWiSfwty4yTKpdDhf/pGMLpNKQyDeSbYfEFQDQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAACs	1783625580866	{"key":"eIU+dUuaM0dHoFhtSYsaLpZRnHLk7gfT4FuvH4VarHI","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"uXK7O0AgZyuzE4iawQc7lhEz68DfrvkAvHG/nSJM+dH7ukm7WNPwrzWMZYCThBE8W3PstFgwat4+7PU9yjqiDA"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAACw	1783625580866	{"key":"IsdE9rvX4/jGbob/NcCAEYQTknoPCw6J2srYORFcFjI","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"ZzW1E9ZVH3P8XYO7m8Tq017f25dnuvCnb3HjzmjU5xY4rj/5rVfWuuwk14C9ZsU6Z7mfn0P/yruFQXAKf2nGDg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAADA	1783625580866	{"key":"Xy3zoHiAX/1qTyjGa/WU2DSVF6q8IqkYxv0KVlTOHj4","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"l3ks14C+lyCWcUjDUMLRqpo3hQxD5Vw/qrIxQ1TUOr00vkWz53m+vk0J6PrcTJdkB7De+e1VLB33gv2dm/ZjDw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAADE	1783625580866	{"key":"UBJxWrDhawIXSyOoNgF2SOYkoKYthvRCEndiiKqFPRQ","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"+9cNDjRVSrsZ7gzRRAFQuRprVkkGX/oPjicAA+fgZxUd0IRj3FnP5JSS34A0M27BzdEZHxOihXxOxJR4frzoCg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAD0	1783625581144	{"key":"asJl4gACf3Rp3bNyZY+bHsyeNhHcxGQobN4jvI63TSM","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"wxXr88GK4kymsk2llBrq782iYsExhh0ScCLey2xQSFdEUhn9lK92mBTJiaT1j1Ml85KvWa57cYKembsnIE1fBg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAD4	1783625581144	{"key":"uRyZTsGIn0AJMAyu+7pfDUgTy3xnM2aQRG0l6ekCODY","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"kzQd+IDkZZFLDY/OubFYMkmcoHNO8yUbBtXLPfpRNyu2tkogML9FMfxcHMkqSAxGLjm2XtojCg67BiBoo7a6DQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAD8	1783625581144	{"key":"lR/oVP8Wa1qXMU4Yb+CMmLVRtQZF78qLfHGgesm3G1I","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"7LZDj3DEGPyMDKMh0vLKES3yUKSATLRXbR59eUktxMJo6hNqzq8sgeS2QlkTqyBA1kco8bD1Tr28+I0lrhgYDQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAADI	1783625581144	{"key":"wEmh9k24PkHK6czpcb7Mn3x25re9aaJx/5vj2ZByelY","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"nERzucGqd3H1mv40vlMbEbKoeYVqnW5bhzma4Z/gVuTWX0QFskFrlA0Oczr85Vr4LzjmVMqDsoe2ONHK5T7ADA"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAADM	1783625581144	{"key":"X1B/i6unNEF9lQhjLAlkIWIiaXsVbYWd3iBcsgg73Dk","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"G3CjaOI5oht0nRy3fd8TcthF7n9NE0fqyuaM2Ahc7KPHEhfwRc+VOosoep1e3HxQ9vU0bv4cDj8RE4Gi5eXHAw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAADQ	1783625581144	{"key":"rPSjBPUUs7vpefClQJclloNsqlkzq1DlqN/6mtocdQc","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"yutYmCD1fSEzTp772AMa4on27ZpraNEC0eab5QElH7JOISIOcnLd0O+05yZDhdDbYML/+fSV5rQ9IcmyxLFMCA"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAADU	1783625581144	{"key":"8H0KVGbD+aNJm4WGNAJZgNbZUIneaK9Xj1QiYTuEXDw","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"3d7zR22J1SegFd21wdoVi3pRSBxdLC6XqgEH0KSQ6OGkq9rGytz4iCso6zdIPIbH5liEIHE0ZX6QL/m45DBMCg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAADY	1783625581144	{"key":"YGShApYXoLh+/OEbBTMpetyAIkT7a3yq7NxTCZfr23E","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"f6peNnJV1pNaRikGvtPgclddvAJSCDvPlANjt+I4H5BZGDbX9Nu8N1RqEVKv89Zcifl2mQbMcc7WlrHSSzhUCw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAADc	1783625581144	{"key":"Nf/cgMTq0O/qI8w0oZ+9CugcPpgGykDYgRMw+1U58C0","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"yV49oxAjvDTFq6KMtgiEARgcMi8nzqF5gEaYBF+x6lKvzWqaEbW+UxQuBIJANHfmfxh025oKMy1fJ88e/wgNBA"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAADg	1783625581144	{"key":"D2Aly/qUbTTaJlHaIKSP1O7SgRlNs5D0cSOX0tQGGHg","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"zKNc8abuKjtje8ghXxJ2/dN46wbRc/r1EtYkui01BA/R1gjOgqIFrfw59trH7I1x+gc8oFNIrVTSKZJl1vfuAg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAADk	1783625581144	{"key":"caEU6PzBiFuwXYsf+Gi8fn/LxIRZ1+tmNHIrRMALqCg","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"RFGa4W2bXqUIjKcH9ABGQvm75bHPbRkKh2yw20sSDpJIW6B74qkk9+7vdagFcvc6qu+CIOANyB4y40R1estwCg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAADo	1783625581144	{"key":"QL87xwIJIgR8Zir7DY1mtjVgFWaxcQo/iNXq+QZHzDA","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"/smbqM7HGIOE/oxn49wVDjqsSz2ca46XZk9wvGHLW06ZAnzWeHc9Ar7tQZ4xS9hgfzBpRO3E2ChFEm2ru9FEBg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAADs	1783625581144	{"key":"VYi3SYFRqOWNnJw3Fo+a508iIPsZrflaDYbwonNuvEM","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"E5wh97/cT2MMrBUle2QqKWMJO22/4bTPL0qSUIWJXEn99bea+RmU4wAM1T2VTjoHMLzr6UYR6KBD2+9GzL2yDQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAADw	1783625581144	{"key":"OM5yQEqgBPbv2afAvZFbPeA25VMdCuiNStszq3NmkF8","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"H+aYybIy6KFhzZX+xM2cCFPi9D4/EbLj9lg3Gui4vTynLX3RVSsfbshi5IhK7iKZ4QapQxutFwKrx6Uo2ueTBg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAE0	1783625581144	{"key":"oeh1Vh+G6Stpb8JFPVPzgQmO0B1W899yqFj302aKLHw","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"9CCfHEd97E+PnFMy46Q0xrnJW/ikySEVFxDQW5GJU+GdHKpQEhbvTdbaJbWLTRNjfKXOA4VBliy9cBZe+bbUBg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAE4	1783625581144	{"key":"L39G3Q3kOvTu2z4VRX+xUMRMzUOsWZD9luNg5ij5Djk","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"n3esikPaRvN8OZreWd8w3ksNYB0WnI12yNXjWUfS/NcEiKh7D+ZnRbCxpKYuMCNHHm7E4STHBQA1OGmU7f15Cg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAE8	1783625581144	{"key":"QUi47x1Ifp+9XQUZTsHIOOVhnr5BoR3yAIQOcPyVhwE","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"qMOx9p3tcq9Epa8NuSWlgHNRTEEkVAuTx/8CW95VdyVwPMa5vR4Ti0FnXYlaNtjIesT+3rOSVsHwsDpwl23wBg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAEA	1783625581144	{"key":"QFliMaCQe1HDUJFiPbP/OPUQz8EvF32WdYiddg6GeC8","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"k8Bm4xQJRg+s4nRJhhVC3+QfhbuhIa1IeXwGbaEr5UMDglAgDQaInr+Sb4HtOPQbLcysM2K4kv2JK9qqLLtNAg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAEE	1783625581144	{"key":"D+0sxE+mUMuKuwJFsSu7y2KgyxBR6RuXa9XN9gs4c18","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"xzERWBnvieazQLQLefxNvhF8e1u5ewyd5Ef7W0+q/ZE9pjkAqbHJsw51RRCy3JKqrfk5hGc1dfh2XC2ttOkpBg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAEI	1783625581144	{"key":"BhajkdDAzE15kLoMGHE8HVJhtLMFDDdpzj5ntgBHqCY","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"m1apcP+jtRwOQRMxGKGSFC43f3vNVsg9Lvo/rQEexNqYYjuYqC8QbA2f0mDH11u6XweMPPQOnClfT+fVYIfPCg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAEM	1783625581144	{"key":"6g1hGe4bMxu03xKLpbIF28zumj772fUazr1ihrycJ2A","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"6kzBuNm/5PsCAfDRVojV1lyuVpRMYFOjq4TYrP3uB0bkrW96AyIcbURDY+UzpknvdgdWVNGZGfhyfdwMhQBnCQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAEQ	1783625581144	{"key":"SwO+RtSwa+/ddkt3xPeLjnctLukkkeDzwzNreRUfzzs","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"ZJRCmP/gDR+LxazGGxdguxdEGk0uEFMhNgSvgwck7/6WvKxMDTqch5au6OqIS1SZAKKH/PEtvQAbiwnGTpMiAg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAEU	1783625581144	{"key":"NXVh13pX2tFdYHSD0aS19iIVAeTHKaOLDlH4LkJOVlo","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"lG0DjNtP2a16YCS3SoEDJOxUf1C99xaV+/e3z0fuhf4Pt/aZ3IvjFvWybrgZTYPiPvfr/hy9oGDzEt5rb/jtAw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAEY	1783625581144	{"key":"3klXovYqv2Mzct4oTmxLX8ss22rrXl/2YzVGjdptTXI","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"YI76FWz89IyGI92rHzeVqmltCt+ytX5wKewTwNEyEm92WdX1bVQrGOZBUE6lATUQNDGIrz1Q1e/r2tbl58JVBg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAEc	1783625581144	{"key":"EyjX44/SkBefoJogSegLKa3aEWIkeh5+S091cDBqlAk","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"snn1J8tI82J3ncqP7a6sLWc6KLNKRwPywxDTg7QNhQLYzGlxoLUjfIs2lJtB8gDd4jcm/qqBBwdiztsJF1WlBw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAEg	1783625581144	{"key":"dRoUbe0UqYfcY6oMmGy06FD/V2RKrse4W/zEjW/bh3U","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"RPqg88wqho6hKcxwjDnXKtVEpp7JpJSQn6YL4Q1avyFam2VvMVS5be4qkCI1S/+zV6DEJvoYFNvveV657U2CBQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAEk	1783625581144	{"key":"JXPntqm8KfnUAMmYMSqdugK4FidLyJJ/YrL6H0SSiXk","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"nQed25PyUCf+3fHA6DIW7ATqWpnfOiX80gdq7zWEstt7eWLCnlNJ0VO+AyYTxkZ1Z9IXNOqlzWiSdqZHazk4BA"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAEo	1783625581144	{"key":"MacMK7zhOJd3W5ANp2eoN612+KFru+C77Gv7KzMvDDw","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"A/eV5VExApy7xwguPRIMgu3tEAdfSYp3DDMSxei4BdShwUf0I0JUzNwWxnxopIFOPPiNN+g22iHF81VPIEyuAQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAEs	1783625581144	{"key":"Sf5Gk9QBOqCuVdGo4EscN+ktNMwfuXKs48Wf6Kk4Ayc","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"vixzsc4IPmjbcLc5nMqa7ARRaiSJJMd8prBBnWxI1TiR+hqTy+YWJOOTVQbzIoAmN4Zoi4KlKYd0nwfWxcjeDA"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAEw	1783625581144	{"key":"Fsn/0g7DUefx8GodbWa0ksFv2POteyyeLsnB0ThD0DA","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"wAygBDmzuSSeiZig2UeRiwox33IZwKQhUkvZoaOY0auqVW7yo1pMqmQBY7Zx9iQmwIDZtri/Er3qINdRmIHpDA"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAF0	1783625581144	{"key":"+Ne79JiKV0R5x16Dc1DW25Unsy9n1tWWPRCQ/v80x0s","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"ZHik6Xxcsz16BJrLFqCXPp41oUO96lZa1cdKHgDrZlAnY4e5QKTZrDy/3mSYCC4x7qLkw777vlwZCEMGnDtvCA"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAF4	1783625581144	{"key":"TvGOwsWLbpeDwqAFjP+VLnd3U1awl+5fjwLeoSeMCWk","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"8Awp/gU5NgD8+0YQRU9HcWVKrAOCwWSSBm02x3zPYaDaSfIGwJBr9qS4dIbT6Mma0ezTb/IrGqsfni3hXgAKDQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAF8	1783625581144	{"key":"Eoof5FEha0zkBvoxuYQ5/LHOUHSCEL09LNDQAubNN1I","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"KzOzh7sCbIUgkc0v6a48YcSAykCQ1xFsA5n/gQ755CuoOcT52slQvkypmPBafMfgly6LZT5kx6OXjMgrk1bhDw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAFA	1783625581144	{"key":"b9aPhJU6RqKXuX8La7YoRzSjQ0iPrdzK/GVO/uFn0Fw","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"dJ9fjHQghPsK8w/hmamKzq8hjs2Rpj/9IuF/efOtXoYLXZo3IM/vz4NM5H/BGGa9dpQgqju4vF1kiWMbB9zdDw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAFE	1783625581144	{"key":"yoQBrL3M5Zodt/EOjxBbYNmCF0KM1KE6nwlmg3sPAAY","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"5XXbGHw0oPYXI+Rkd9HOjyxfUeR6PhgPyMY0eGbdCI4W0Y20iDv1FRXtXYUC0l0IEr9XpQq5iPxtEeEwzNsVCw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAFI	1783625581144	{"key":"PF62oDb2F6d0LqB1u1cc7qIE8Q219qKQTjR0SlEVb28","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"+y8D948Cnd7Z8t/E8wZQVU+p2deKTQ9CJlMEh5BZck+JOLugc6lopRiL6FYN96H6fBrv9q1/C/YwASY/NK18Dw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAFM	1783625581144	{"key":"OAzk5urncY0zdsi3VgyY9sIE9CrgQiI2idVUNrQcLm8","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"+VjJgdQ8FHZZBFOMfddYcMpUEI02i1uUgZFuvAhpmXIrMdTlTKXwCTr7CBjPK3KxhDXPE3fjiWbA6WqQ5bbaCw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAFQ	1783625581144	{"key":"KNkz0McCp+W5wK2LYyE96wLxCz9BgACajHWOYOrfJSs","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"pvZ3YNuRWbInpH66Xlv1aA5wfGGVvjZlnCNrfhCSEhEJZyfnqL/Ma9W2UpfJCR3oa1Zth0sy546Gnf5t4MrfCg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAFU	1783625581144	{"key":"O7cDFUof+SAMBCnXHGCXagoKC7qdiNk3rtz2F7Pr4Vs","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"utiL9Eq8cbllux1GVfMw4fgCtMeMzMCtvZzZYSEpvCy4NrXaF2N1/DoNX27uTLe+luxu9wQdgkSU7c3RylnsBQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAFY	1783625581144	{"key":"QuzHqiMwRXdUpEG/3kS3vhd/xyvMY7UJzTuKdOQ1Jzc","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"56rKWQIyjHt3WIcmpq1ciVrEYyxF/kA0yOqzf2lVs0Ft7Q2/QDd+L/Q8mDkkXMx0il3V8Cna0Ec5J1bOi1LBAQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAFc	1783625581144	{"key":"/zU+CtFcJq4VfVkct/fGyuEED5forbzSI2DM6L4KmTY","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"T+UPk/DdSBJkWi7qmnjjuMYkDqGcWiSZkm236xDp45NZSaqtGF1tXO4bRQ52WPA1pdj+a7812OxFHpyGz4sCBg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAFg	1783625581144	{"key":"jcu9sTM7ja4PL2spMRu9/smeMTGf+t0YtIoYgVH2VCc","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"OVdS9FUBKhgBvOADIL72FP4RB6mi/yQK+Pt7GyGNcDlrZtWqK5a0UgzE4vuXwyckmyWcEy7IQoUDy2hcWVX3Bw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAFk	1783625581144	{"key":"nC8dK6PEbGDsBCplNyjzl8Os2hJayBXyVyK68+RQ9RM","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"vYvSX4I8RkNqe1EgN9xMqSOaj0Y3PyATiz93SiOaBzkzYn45AOX3Trfp4YUpFFI0uw38PQBFjL96IuDhmHOMDw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAFo	1783625581144	{"key":"yYTX/Dbk8FVdBnMqwva+uAcXCLyiWZpRW6wj1osHjHI","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"78xhl+OmEyPBABamlvP5pMEuFH+zFfGLScf/6m+ml946mt1MfrwjQZmVQxepsTz28DzeXhu1sw5DjZZp8LlzCA"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAFs	1783625581144	{"key":"dO2MHur3X8cbyIjy6fNxsVp0QEQzT7lGtlG14Hianlk","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"JW2yG4PbrcTmJKR9IEHo5v8778tWh99W7ctmkfDATqte8SGTZ6mt7dxLgaorxBqX23AERzHYgX+PZMiWhmo1Cg"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAFw	1783625581144	{"key":"fDBQIAsJvp9j0JWgSXdM3qrdL/oPFBnOVj1nC59rmT4","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"DSz8WemRYXk+CnbpVUvi7KUSSUOMu1YJghRolt3pMRDqJzmNw5MjgBJPGQFRzqQdhQvjwnMlo/8D47xH0foPDQ"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAGA	1783625581144	{"key":"SW6JTzKc0SerwgSmV1zKLEIDTdK76X6+7lATQdwC6xc","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"W4RXPu+2aazWH1nPzu6/7T90k7QxkPG9ELu5dhAXDeISld98MsRhv5XnnVoizyAwBJemn/o1wFUpgtVXmJ0UCw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAGE	1783625581144	{"key":"5NYHHZ+dqRPCxR225lbO2XxRQ6o9CWStDJSgVSTgOw0","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"6c6STfaDkbahpfB4RtStQl47LrcNfgy5TlFba7d7FOHdlvMW4pjWpGGb4IAJCb5Wk7C+FPjMIWTrk6q4oAp3Aw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAGI	1783625581144	{"key":"Ebpq0gxrS50sVY1Lw6e2IdLiQ7u7QzXmDKwCCyaLpGY","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"2pPWiZ41sveq4Fk3zPyf/JXNsm/MBvfUU8F1RqMUDU/0yvcqlZ6/8DEyatYjE1XH0FqIEBsQJVby9MFfqoe8Cw"}}}
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	signed_curve25519	AAAAAAAAAGM	1783625581144	{"key":"+rtFPCJmWcbih3uvBQcV7jTphRJa/CuPCdZ0hfREuWI","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:NFLNJMUACW":"nFGHun7yvomRtTli6UnoeMjewhe5nHwFEWf+2r21mU+FLZZKgAt8rdasuxl8sbMptIAgKrPrGOkjYW1EOaEhAw"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAAM	1783627062053	{"key":"oP2AqGyNJpqS4zzah7wsEjZGAevDftjjyJnhO9G0vzs","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"jljyX0+YGdq6yS4Nh7+BhQijWHr3I1TakjxD+46/rDJWUogWOPA0s3bmRyK23Pa1TcvU+XvW/dduwYkp2WgcCg"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAAQ	1783627062053	{"key":"w9wcLP0zwdSmvtkA6FqVMaPoJMigPNF/DvnAppwtrgY","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"HvUuHMNADPRMSAAX4DS0FXj9bf7XJPYgqjpMmUnEL0NAtXhe28YGGqRkKFfqoaaEIGfsbiir8U2qb/ig+SNqDw"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAAU	1783627062053	{"key":"k5A8YkIkarU2CbevO2s5H8/Z+J6tCKUcPbU+c8RLrzw","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"h8ec0kRljOs3cOJyQ/AQH9q3zh+jMFFvlLTBzbW8EV9QWM9tXEplut9k1kbDtKuXfb5NTbNVPkY+Bs8AvWxSCw"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAAY	1783627062053	{"key":"2TnZd1epN2wb9xmnctcu9QADAp7zm1FvkpFy1EgN9Tg","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"a3879FzlAx34Gz+2uItj7OsdEizyypFd9rJ4D3muqU9IiyLEBjVV9D69/W5C968LRg1qcZJ+qRAh8XRoCzwBCw"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAAc	1783627062053	{"key":"N2lNZ/LcnnMYbOuVHzYWPRMalXvbJsUxFUnTdfDl9l8","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"ax+7s1Qrccc+QgJU26kQaukdmHH+a0EOJdaFRG2f7WKl1D0t6+O8e3XE0ypSpXlt4ukJ/pGnXnR4QKvNQQe4CA"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAAg	1783627062053	{"key":"U/bAZIJP+KJ/6aKU/enSUqSZux6Jp7RQ3gvSFz7vc24","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"PVxjo5B0JYn1zUCfodqB06a2hDOQYtRvA2D5oP5tst6dCu894bH9yjB7ufy8M58CpXwlJqzoR6P0FokSuisZCA"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAAk	1783627062053	{"key":"Vo5sS31qRXZeT8BXys7vgzrNImdb/vSUEJfoU8ZrP3A","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"ITL8XZXbAWxgyiiPhA3FCTnUErIz89qWMX/n+u7zOulWYz43XNQeyszTMbkGFS4XpR/NGXvZk4ygUxqqL8OWDg"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAAo	1783627062053	{"key":"alaJA2P2UyGXfMKHP9+IIC3jhNzN0bzmy4oEqsntgCA","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"SXtJ95MaHLKfE2rlVCGLyugPbbclkCuByWT0Df+4AyOZ+nSJmgYlCtKT4mPJTc+Uc4e+tGiSsoAGoz4mEL8NDg"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAAs	1783627062053	{"key":"Ui33xl61TIOGCNluhhrTLpH+DxwO9xul/1veGSRC/yw","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"/r3Am1jjmUwhqwhVwCf1gmnkbT7eQu6OzGuRz18UP267jJbp4Y0ODq8OBfDHczQrGia3sfTcGgMCPfOEiwL9DQ"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAAw	1783627062053	{"key":"LoZHoMb1VNc3JJQ3RUN9iQKz32YLdKFqVvLD4NgMEjA","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"KAefYJT6kTsdpz+4RtxcGxOBJ0PYZ5yA2iT1EnQUXRu2d71TVmmZYsgz5CmPb9qYu+owGsclDHY4B5rl3vsrAQ"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAB0	1783627062053	{"key":"fIANcDSuAmEDu/LbyywYQm05+/f/4peqwZI1kfCGQRs","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"4tD3F1BZhAowQ3p/R3HNsWoGYvYmeP58rGG8p/DIyfZfqryTDyKJWomVTuWhVV3PF+j7taGWt8TFKdM6xLBMCg"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAB4	1783627062053	{"key":"u+02DS7EMSzAp1JbxuEcUHvoCULxcawpl7kh1ICjIio","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"pQ2oHjj0yzROhQV84P7cEAoOrPXdXwd230hBO36JsatDYs1cACk7NOx/fRU25fyLrOCOFGCdzbsm17F055foDQ"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAAB8	1783627062053	{"key":"gI4rxgsclqOQfP8xF5D3iCXVy+jQTj9pS0SDnNUZ5Co","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"Bo2bTXeDbwfnF8XXtiSSXO2XkUOG7l7+yP21XLQnh7w5vqmJg3S7rpi3B7o93OuDQNtnFYSPB9StbHJteDuJDQ"}}}
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	signed_curve25519	AAAAAAAAABA	1783627062053	{"key":"jrM6SmwMM3r5W4MLB2Q/WpKzoR9oRIxIt5nMA7voGEs","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:SPEPVPSHPR":"gMzdS7uSJCWeKogQcmfC8eQBEPJKbXW4ZkKEp/mvh0tjxs90iOwHvfF14r4b/RARjYYVg2npcjJW2z1SxDXtCg"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAAs	1783627509932	{"key":"u1VLPfK8hsIFQ+W2GWZFPcvP1NMvKA5OUoZ0ipvlnXQ","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"hKjqGwSYMeyHU0ePSHFhUwJ4o/P57JfO8NdD/wLk7YOj6zt3qS6FLP6DCLrlaeW66wb8wXBJp+h2Z5af/WqcDg"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAAw	1783627509932	{"key":"YwdeVT4yCut1uwnFtYC3d2k2alfc1501FTBzCOyuWlY","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"dqRAiAd/W52Kuz5qdDhCAa+g+kC6bFn9J33AftP4zAul/qUTV3IcHx1c/B1K/soyuzWKHZrhTks9jBtIvoEgAg"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAB0	1783627509932	{"key":"fEmtuHtPqlaLbW3nFm0UPZewCVmi6rsL9IgjZdiSPFQ","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"fORPjKs/SmOSHInXTptNHmOu9+16RDceD7VNJcLgVqJsZxJfJjRSKzUch1q7cBg7UHUiPmYxm0B/bgcQeaTmAw"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAB4	1783627509932	{"key":"+3onN3ppOZrBxPLKbQYRrlLnTmGPbbbEmrS/0ZXR/xs","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"7XphuFYcUcygOAHIuh6Zz5wQBin0d2e0rzj+IJiT9Ns4NGd3Hj7DKf7rT+s2ghzclIz+XsfIJqj0UWkYCGNuAg"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAB8	1783627509932	{"key":"lnIul45C1vZXTI7pvPQOvIzOhG42DsiFLXFY6kv46Q0","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"hVxPIE6mD4Rdt/0nCDl+xPeiB/hlIUMQL9tPaWuWjLTeJMyIP5HCtK3mKhEhsRffo8eXIf4VF1SqxAptFQedAA"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAABA	1783627509932	{"key":"GKertlJA1ZydD6OLRAeTZx32ByPi4FEEHo+oghkGOGU","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"uKWwfqzhwbMXWyi+2vD63mt75Q3LNcTX6uOM7qhVNFWmp50q/cd9LsK9TDXpl5Ji79fZUhPfSTaMlXR0M003Ag"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAABE	1783627509932	{"key":"vrW594gCRF0wCNj7Ui7iXzI1qZ3SQ/ahCfUbY/I5r28","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"8i9mshuLkRZGr/hZXoll6fmlEm/2j3T8587FOpI0kNMxgkcu5jZBhOJhH66sNi8OlD22oacX0yjJluqCDDh9Dw"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAABI	1783627509932	{"key":"MgGym+Lsqyy9GiGygUReWGCu2JIh/HoMTRRvEbLL8EA","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"bCYCVoTGaBD4GpUmabAFAXiOkpVuP2H+H5An5qRWNdxUVdDN5nEAmaN7OvQuVlT8X/BYPLIXcsKIiLBLjtmfDQ"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAABM	1783627509932	{"key":"TJbQEj6oXLBXjgTYY36ARFylo/qb6gc8/EKFUeCXIV8","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"o8UaqkGDpE0EdIx1ptl/wGJnsWBbQR1SogZE3Te0MIDSAQPMudKTSkFOgdmNmxGEO/tVunTQ7Nuuq0iTKuvqDg"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAABQ	1783627509932	{"key":"c9MEWBMTShwcNoPsI3WoOF6A8tv1602iqNgCHRmd02c","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"gZH9M7ZcPNWYntATbQJVujqBGugVAHzGD+ISmDBmE/GTTvuunYWRkkWrW64jNbbivPNa1Np/pCF7/KRUAKv2AA"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAABU	1783627509932	{"key":"aGAwAC6AksPmtktEp1zXP+rzuPWeNFs7Fe/CPtl7VC0","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"KBQTnFHZ2PgWKoyvPttS02JJOiKR1z0JkGkreY+CxY3UfK2o3FnMTWYtf0vHsnym+y5JZ7hUiK/lcWV9SwsvAA"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAABY	1783627509932	{"key":"g2HIrDTy0U4QsFxWIK6Jc7v0ecI6hFTk5vDNhEhVigA","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"b7bLAdGphuayUOI3lec2OojuFLAfGykBkaB2qwzZ+CYlYunYlcZDXXArcq+QW7QyqNNKRQbeCJXV7a84igvnBw"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAABc	1783627509932	{"key":"j5amkaErP453NeZxIJ8/Dc23PfdATrKNgPb1aRrHx2U","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"G/8xXrO4SGqf844lCCRRm2dBRzYc9UDpaUWQ3TdxrKnfCx1x/HJD219QxRmdrFHoRKhItj+j6Uyy7YlpyQDGCQ"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAABg	1783627509932	{"key":"kLUsz9t02ky7AVOn4t/oJDb2TIOUyQybbyk/whz58mU","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"p0Wo0sXzeOCG9Xly4KSqa4mByEqZsje00GU1sqbsrEwXrdq1FbeRbgtwKnTmZPyrwpe6C+dUyv/qo7P7ST1oDg"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAABk	1783627509932	{"key":"sODvac86EMrzQ9o9c38nwyQbHDyM+7MdScogObrOm3k","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"GD8LgL+f9ac3cm2lhjSJzAlYwQlyS9RRKbvwC4IL2IBL/QqkDOOBoRkJvNHSNyPMJDWbgpPHnwDBksgplYBsBQ"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAABo	1783627509932	{"key":"6w5dlXN0C0ibc18YPLz39fuQbn6ivekvm2kfYgi6+yg","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"I1ixYXENGktIKYF2/ykvcGemGF1GJvqEKpTykkrgANuhFWuvhZsNcnWXsXRXzxyNgyzmiM1gFBvdccgm88LwBA"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAABs	1783627509932	{"key":"n6cGVAg7PfBwfjWjfiQSSVwrt+DcImyXYYcjb8ksgBU","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"3woYas4F3mDrdcTJPyWf+1p/RPolJZI2H01x9MS17ec1nOCNfo2Wqru0mCUrnxOqpL/RKeDz53i3dsHbdacDBQ"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAABw	1783627509932	{"key":"QIP8N/fMpbY+rS/mDerongCMBUyqahLSSOy7U12Y0ng","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"1030d/maA9HoQVd67fbgnky23gsIdoacDKhzUEZdV0NKmnQzvs2/TQyETJs/4QOIH0HgrKqF+sLerEjN4HjxBA"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAC0	1783627509932	{"key":"5ZVaaXx4/iR00BKx3F/DJqy7tihFSUnzIZWK+o1BixM","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"rV+8cPgTGeLVuItznZGguuiichVvTaVjoTVwMpSUpX0vU+vgsEFsf38Zs28N3HlD+iES3H8e6iEAjGwEAsWDBw"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAC4	1783627509932	{"key":"/HMvRLeIrsBWtER0S6Umge7XJKMRb1u2/uVULSkrN38","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"HMgL/LyXkJfzkEhQRoDygDG8nrsX/ha1ng7N2EcW+BCkD4xsES+wzrkLay0dIGKXY4Mdhl3PtSG4AAiRxaLeCg"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAAC8	1783627509932	{"key":"3AiI3FsNZLCLXB0YXFIxPqV9gK4VUzZWLeMN7uDClAs","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"19Fs8p0Axe4RrOHIaz8VRy1kyoMyTLdOM1CI/PO2MhZC1/9b+pLShqAIxtDGn1rSVeUiaPTR6mdfIlZDrc57CA"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAACA	1783627509932	{"key":"NEz7X3a8gGuvPGWORcw1f7X85jvE3v3JVNYk2HYxhlE","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"x4/v34zqVW6eN6ECvm9HnmUXJy1A1fFM9PA2uD5ypifO1NnN5EPgTJ0/zTUnztM471oih2hiX7DUy0uReYuICg"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAACE	1783627509932	{"key":"AQStl7xoWsLMFEAgnF7Nq9U6qh5nWRtgYeSgKmoRlwg","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"q/Tu0EXyBX3qYj16ooC4RxwfzanOWlDSOcHpH/oS+AZprQzWb5RJbRvNmHYK7I3CYGNNt05zT/3dW7BuiQ1WAw"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAACI	1783627509932	{"key":"IjSgWybb1qPdoc1BQ7Uv/SSHyijvDuDNjqkbLHynSx8","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"qsfu7+O6Ye5n3gATuQ4J4UhfGHEydyJ868RHRU9GNF4HUTK84e9k/tW/zFzXc64J2f0dM6Z2DeSGiXL4E1yKCQ"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAACM	1783627509932	{"key":"95zxWBHUXPWjZNJwl47aly2NdgCcu6Wm5wbHaypOdU8","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"FZeQXbKoeemKswMbIOIMr1llSLL88V9nEiy5v7W8Ao7IuR0EofXjNzYwINVo94mks1YDApl2qi7U8+lBkeocBQ"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAACQ	1783627509932	{"key":"6jXIPM9Kl6PQA5vX1E+nYPvRPbwyuSSAn3r8I1RdVhI","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"BvMApL6ZFx35NOmGo1p7JTBvU9e9NskvbTSm4vnKVbUo/0Cb9SCE5x6e4HjdfkUcULD5A4VUrm/DOB1wmEVbDA"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAACU	1783627509932	{"key":"RslsMiVmnFd6CTsV9EX3Bnjk+rLH+FRGX4Oc/tjzO0s","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"ZhZkk2nJcheMWh4xcBUxguHSfsA5VNtaJIAZ3WzFk/Z2W85XEgiyNtMkNn3mHQh+Ahgk4LkPe4wboqdFgSdkBA"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAACY	1783627509932	{"key":"wyrCBuLlytsHunSjSgIdslIYbmg0zgxYewWrV3tIqXg","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"K31nEs1rhijTnBkdN5KJSzs6TY1sl11W4JqnWLP/06i/6B6mSanJME8csjllLhdXk5EPS17PA0QTxA62m/yVBw"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAACc	1783627509932	{"key":"ta7YvWJZ24hInzlqc+CCR5FS26d6Evsn50PKgVWW/Bg","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"PX1wg3+tMAiZSCsmd6gloPUzKe2lJnFx2j+PAxj+dxxliSt3lvdIxNRCxkIbI5eJPh/80MyKVkmsxbx/rnTgDg"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAACg	1783627509932	{"key":"tysgVCodsDgglntjjTFJQAlgiO0SIuJKIHXIkgbpp3g","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"6yyHh16iQju0/anGVK60P1MBfx4v1QIbWmd9xqDi1GzU5OGEMkFJJN5p4ZqoEJYtT5xg10YaRSrg3EqO2RBxCg"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAACk	1783627509932	{"key":"ie/1Q1hjnYdGsVcK9XMY0/bOmmYr4xEK9tDNUFnCnCo","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"kL8S1l79YACV+yMfGsDANbRnqI5875pmaJDTutWUb0UwsrSKOesIYgIwaxuNsMzdD9xo3VCPdjcn8Fl0q4esBw"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAACo	1783627509932	{"key":"ZNncJTowyO+YzPo2xOikZWIfaeDzuQSez21USovst10","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"DuqbTXpl+i27uF1yWvYZY2dXXNgM0bDbkjAukiZJz8WTdx5txQe6AUpDaW+H6IxMFogjYYfqIKIsvln2i6KoCw"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAACs	1783627509932	{"key":"wkuiekQEwO/Yo1MimeEK2xR3yqdn6UylKxpV866sIG8","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"p3/5sDOHR9p4hKIerMG8ksTWKeaG/87tzTKOv/6PSvCHrj8pjN5/WsNRCt8ppBHsS98dWydJlZTDvM4h2mhjDg"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAACw	1783627509932	{"key":"btEPVyE4J5bHc1gXF7++k4/QroZM7+cOl7JmmkezMVM","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"6suUMr9rQgxcfQxnrD7NQcRvzOqHJALUIHqzrYm5d5179B3nk/rCh3yi5iw9BXVeyfqhy4mHm6Nw/DKXR3H3AA"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAADA	1783627509932	{"key":"iEkPw6mnCIGl7D3POAl4IhWnP/8ww0TEybVWDO55CjA","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"cmKGjs5utdE3dGZFNPccyqevm2Baf98uBHfY5pGYBwJtwfmD6OWXDb7zFY15JfEYZklfBo/CIYbNBiqUCjlCCA"}}}
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	signed_curve25519	AAAAAAAAADE	1783627509932	{"key":"cJztG02dVj9BY/v+tAySaKI4PYrzjhDnfpKPh2up/zA","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:WGFMZTWZEK":"94vUw91KbMEw29Ch4b8fzt9CaJV1B/ZUAq/q4XVzaGwEppuc+AIfgiL8JOGFrXO1ktEbSIeT6BLarnxyZT0VDA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAA4	1783667622644	{"key":"ORgYCykm6j17rxB839TmLg8WRFIpm/kY4OHY4JMUBQY","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"tcGJH/lpF8v7xvj+gXGzvFmLW11W9EBwhljQy7Vu3HQ7/AUizNm0/fM7IlYsnrTcIzOX2H1/h44Hpgwii7fKBA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAA8	1783667622644	{"key":"5baAvH9DMIxg4hjRqv92N+lpYeqdH/r60RBmgJsCqnc","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"9IS4B84pExL8yqnR9N4UZicgh2xpeoxKfbAiY/gDFE3neO4f6kimpPwLE+8E03Py/yr/w7tPidUQQnt6arBVCA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAAA	1783667622644	{"key":"kQmmwIgDNJJ80t2uuM+CPGjgQnOFon0Z71Xkf1Iz4kI","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"obIAr9IuDrixnTluODgVAkVf4MCNKYlrK71OUI/ApR2Niu/9JP5H76hQbDQ/lkVS/DTZrdJabl0XPcWaJjhvDg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAAE	1783667622644	{"key":"qFDZu5pX8UuMIkVUnE/hdq5rEAb44rQ37p6ZCaW6p0Q","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"fqyQTWI8frSrgGBu7H5EZ3N2/iXxlDqffoDBIIBjDYq1QZ5CJMqj+JH0VR1hXsL/V1caODt/qFZEroI9mkD7Cw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAAI	1783667622644	{"key":"sWIFZRgqLy62glNyPup8J7SFzq5furEt5y/sM4DhOHg","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"kqvfx7N1OpeC8UQb6hnBlhLsWvNT/uxwI+ICc4VnLkObeWFC6hti91R4I0pcfbuqgTTqFML2JGbsjxnKYUmECw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAAM	1783667622644	{"key":"xLZgJTq44W0Ft2t16HXM2ASMzij+QOFc2l3CIFGcOSU","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"FTebIUDpDjpm9Fd4KBmYz5xAy8bdH+WJune8vhXFmy3nYlOTuxlu4MHtuEZukvuYCwcjGe0TSGkEILs/EH8BDA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAAQ	1783667622644	{"key":"oEA3GvM684XTXVWxA1YMoz9Am7U5diwe5F2Lp1K5mgg","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"atc7jA7m24ODt7fT4zi1QDRWn398AkiDRvlapJhNlo+23vqong9AL1vwzdziwoubhbF83bj+GmdHcejsL7YGBg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAAU	1783667622644	{"key":"4PAN/ckGEG/+v/pxrtQjDDzht0bfN1+BxbQf09aiRTs","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"qrA18yp34J54g+xLXuE7jYG0orBgd7VivKgGf3+JiNTYoQnZqhzNxAahwkM/B30r9Ac5zm0e88H7ZRh3I22BBw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAAY	1783667622644	{"key":"jngflb1R+/R7KXXwYsMMZ4vYo+YpyYbDJfRQ/OWt3Ro","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"3GgfFtbnn8AHGzy7cGET+VJXckLaYomONYkIPJwKKB19eC0NzIoRM5pG+NufrvL80icIbBU0K4Ee43DAY6NcCg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAAc	1783667622644	{"key":"6oYloeKO/3Km3hcjSmrJs3QXZsLKezohvVEzvr2p7k4","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"6mFJh58/urnxXgtoZN4gQaZhc33plccNw2VEycatZeO3FjkDMMIUQdFp8LkCq+qUfm6cv99hXIz3UVck5WVxCA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAAg	1783667622644	{"key":"rcKpkmVTAAEHIc0p4vdl58tfzJCrxLXCzniOrqX9vSw","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"ejBxLzYRlHnfT0IdQumaL4+knt2ftOD1ljGURRLPy4acN7a/SEMeheIYZlZTvIBhErkx3/PWyEWZsbWD6Ck2CA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAAk	1783667622644	{"key":"rlyURiZTo48b/wQZxlNDaXdInlS0TXmFR9dVDT+D9Cc","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"Ac6ogWoi3dsFHOrrf6pQyQSFYQUwF3Yrm4K1bLPb+EQ7dkpCmmPCu9fs/ctIVeVboPdm0AHcKQNsWd3S67fHCQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAAo	1783667622644	{"key":"Jgrr1CsqMkrh/YiAmgRcFUz6exs/YIHpe2kKgOe/x2E","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"slbZz9McmxEr3EvqxxOi4Y/q/wq2MZK+eV4m8Xh0WbpF0d0wDHUigqQyGaUjatGR5Gaq9H2d2h8nwVxVqjuwAQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAAs	1783667622644	{"key":"uEPdy/FMBokOPwbQ/ApHaZ6ISz+ba1hkFseCsQSvIEA","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"v+BwvLv+X+crJqH26fgFW+v4ALwUddMWDJr8kq4nedg5bhRLZkO2LduD4vf55aUzoAa7mMTm0BZnukOd7P0KAg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAAw	1783667622644	{"key":"eeceT3Ux7ZsoIkJxTrXS1gihl5HKgQM97I2hqpRXShM","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"tVQGTIC1eeIX6StS2Wz2gSgpFtCg9Pil3TnE101b1CcCLgHx/Ehu9z3TNrzy504Qaj7dmWZaXxgAVEYQHaR1AA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAB0	1783667622644	{"key":"lsDImqpBEcCq5vGEoXCyAXPOBxqbCwguOgyrNjIGY0c","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"hGBRG4W/BF+ZSVT1OWrjWEXXSjnpPIsQ/n2zsfjDaINI+D9jSHD4ONphurMY2NR3xIrat2WJIm3hJFyNVDqiCg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAB4	1783667622644	{"key":"XoVD/9LmDsrz7HwTuD2xxWxZ8GXmWDi8WUTAHmv0/F4","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"rHnHuOzpHvnaFujKGujOnpkY4dyq2o3DC1qX3aRc6214fh2DPI9DljMjlX8LjgQCdSfo+aEPa9SV0H2xDfwjCQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAB8	1783667622644	{"key":"8JEDUWLVd1EV8baQkGrlytMTaNFzWdkfSvOv7lGBfQQ","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"6kDxDwpicifY5KXUx8wKU/Yt/YoYPPsLKDET1BHz7I8d8VQ9DKKKQKUJpe6CSWFp/iCw3vq6cri/H2q8QOAUDA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAABA	1783667622644	{"key":"QCNlrG+wxeanPn/nopDUDC/veO1TkIrLkGONApnDhUM","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"SMx+hlMLmb7e5v+W2xawQzRmQhjyDe5/qV32jChQ4xCHZgs1RLWIHtx+hwTMMk0OeqGEr8vHxmWwpYJkn0yyBw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAABE	1783667622644	{"key":"t9+ObyTap/2QG59lHCddifF0Wng/50Kp9L4V3oa8lF0","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"owFt1qsnJCfxG8r55tyLKta4hnbab+KCl1K0OwL33YkW3k7cikT1TeR6ckleCnDhcb/+M+qaX3ZIVWzNZaY0CA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAABI	1783667622644	{"key":"/2URXaHFlW+iKcffq0DfLvo1nuO11B/EdlgBFHRF7Sw","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"ZC6ldkWFOE9Hl0b3X7ajEnjjB+2WklkMOSbEvbCJQcMmXGUl+jeZcN9uwPqrpz5xrmq1YMhk/wmRZ1k2M/WEDA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAABM	1783667622644	{"key":"/KXucMShYc8KahWv3UoS5zi7OU/Q0gnny2RlZT51xBo","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"1fqRp2PqPaXVkeIFJrjVZjiYuR0DS8eHZO5NIW19aK+4FUsesOHVpOb71rmxMlejUeakNugqJQmHymZwu2e1AQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAABQ	1783667622644	{"key":"bYoSncRVyUySgIZHkO/HSFgZGZlxRRERuWhTLoG0ym0","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"JDwjHTh54ifOSTHMyueoDoODGa4QDS9l75Ub3WPKQOjiwOP3CHhmhuDYMNiqJrkXeLzPHQ8vlMOd5dXZhmwiAQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAABU	1783667622644	{"key":"cdeZugtkG77O5AZzo0i0UplmHxOjNONqZce4StLO3BE","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"HMPmSJiZD+CJ3udeQOhAFnsLNDhGrnISXPZ5KIbuHl+xZeOp8Iabgh4mm+Nj2y7Ty0Tqh548YnuUL+SECgVgCA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAABY	1783667622644	{"key":"tnCIol8CGODgQlxfxFKUKtXj6z6CH+ujL4X1P7BjzQE","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"diX1Ru4v2xcHlFMBoJEneMPi3gdIAhipdbiKOmfTkTED2udFRYOBqleSqTE2vuvY2U/hYgJiOAw6ynXRwkTGDQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAABc	1783667622644	{"key":"2iqQrlWqXNwX4kG3G61XZDWjd+hqzN/1N15iahzn6EQ","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"g5lVXblIennPa8QpZD7Gks+YcjftoRCgWkWiRkLF/Nk0RWVzq4bbhOEz6rVq29fvkyarrXYZAqqLmqzL7dTzCg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAABg	1783667622644	{"key":"859ouPikRxsa5j/BVyAWUvjzedJG5EDdVE1pAP4AKjQ","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"xmQ1WQc5uTGGGyh4x3Gp7ruz1vqoLBjOKLj58yyQr0RNp04DsdR0sfKaN2gRwHfreyzqrmlrSUC0tq3mbP5ZCg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAABk	1783667622644	{"key":"+jqt9HUhtS90kV0ImLb0ncLIIawqIutBNAS4sUoua24","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"TmgrAOvkRevJG7pWi336bZPJoYlEFEQeL07g8OJXtKVtNeNaCKzL0AJeUcIwqxngTuQ2Oft1gsTTpxC1HKWBAA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAABo	1783667622644	{"key":"RDOJiw1Y/zfkqc8wKHuKZzfCbXmWhnVb5jKU4/PvEHw","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"pkaOK2boHBhDbX4R2xrkljj5rimMBCOTCXo34RZuJo8ul1LOBfbTQ7s5OZIcxJJ8dbVdh/Hl3M5MAdqDpx9PDg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAABs	1783667622644	{"key":"vJo7zatOq0Awl/9mTpSibVZuG4iwXyZzSxvUl1UgPUg","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"Ay9jdfeksnsL5jLIUR0FCr8Cc2DOQ1PQV3Nsl+ieLJCVu99ILXbje23uT5Jd1t0KjvbwWSxeNif5LbApORHmBw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAABw	1783667622644	{"key":"GLVZYDSsXZ07B4zRC1XON/7Kyp0MI9ug3g3I9mBnFBI","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"tZ/NXTnDJM0wza/TKj/STimQOHIeTs/rQSD/ecGNAMPEj/1Aa29HAaePLy8olCQUuXvh7zcq/fsCD1NCGfTJAQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAC0	1783667622644	{"key":"ee8zZbBZz0rv4au/EdaDkP8rMAzjYDxjrzFM1+UWKwk","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"h5PR0xmWRvDl2AF3XqX+u2FqUhGf2AlhMWiOg78udx/HU6taGV+0BrdET6bCiydvmO3CyTU+ALEoBtWCPaE8Cg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAC4	1783667622644	{"key":"001vsOPTshUtomE1DK0ZFxeQa3Bw9I5WCHJU5pKu11o","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"09ablBppSfOiOcos9i6nuUNCC5fWk2rnrmDmG9hF1FWgmYkoY/MOuviPfvG0HKg/5sxEu4hOoAJCYU9/gAqJCw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAC8	1783667622644	{"key":"RghLRSNC8nLsKUQKv1BSk2JxRem8KJMmA1iisUo7jlU","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"dCLpGVbVyivF3oAdzzIzLlbURV/QQyC2SDV7tigtBQsc0yevuxf0LecnX0deLxgOTzZBOY8CeSZcAdX9t7A/Dg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAACA	1783667622644	{"key":"O3F8FJlltc2/oOH20B9cQNAcv/y2asF1PHmqFk7F5yU","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"Yc9XsirsyjSwaqyeOitJkwkKBOvd/ekGuROpD+Ma1a7YnfDSDTb9cUESLHgv5PuZN9HQ9RpI/FCXGn2Z4NUHCw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAACE	1783667622644	{"key":"7b4HoLCiHMQ6Mj/RTcMFBkILdSD0qDN06RFu8SO8Qh0","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"v0qruiid95E2lvA3o3udz0dsgoNhaQgTiyzhcB5geXUu6r++gkOVuTIgcfHn0hDO9iIL22y+b0AxEJKqCdpQBw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAACI	1783667622644	{"key":"Hok+dyA30VNhkvuC/jKDseb+JcXt0ggKupx1MviiDw0","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"U6jAwp/EOhskdpxi64Cxv9DWpSJkJ6YrXkRKK7qyM159plzNw1ZYZCTz1Vs3XHyVgZmbf1FNA8JhZXswYeNIAw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAACM	1783667622644	{"key":"FOyvSdDnISkIsAhZ+ms8+vMePzJb/D6+GI+7IIfJlUs","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"KrokpafShVmfdTdOkNYgttrrrxXugL80k2gIcmeEpM7Q53nBM3Mr4oJ7blR3Bpk8Ao2xizgkzzmTlA4hKy4sDQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAACQ	1783667622644	{"key":"+Z4lxN33fQ4MZXpSxHG1oAgClmHa2EBwBRTKC4ykAiQ","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"M1kNNiEBs18iqwBH6B5H0wpq7i70qTYECnfPUHlbCcWrWTG3w89uHgrFxFqUQu9tZefU3JHo7VzunXXFbjW1DQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAACU	1783667622644	{"key":"bHJKpSIx1TLyHhDo/kZoUMDKy8uJVwovFvuPKL6Uxj8","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"XmuHWwX1xQ4UEB87iGzHWgg9jS7U4SdQgRgKU7rYGTQPDnmz1lob1yPmdXsK68nPW5wkVzB3xeIdx/FwzZ81BQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAACY	1783667622644	{"key":"KzfRMxxLwozVjXVPekYLEFOjjCygdWRxhF53J5bVhTQ","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"cwzWkyyMNar/2UQbap0PinvYHJISxCkgSkp6K5UsDdA6aJbqjHCTmJDOTPk37imdIHs/aOEmKrazUQli10lGDQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAACc	1783667622644	{"key":"SwIUkmpbA+B5srjRO98euEMBi40epTG0fWZ0ayfmJgM","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"/ibJ3sWwYQTPpjxH2SQsr4LZi+VhaBHQd13jT+K2jW5Ea4p22UpfLbTD//31/zLuJZ/xoQjVy9ln7MKP+mt1BA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAACg	1783667622644	{"key":"zuihM9T36rMWgwY9JIQALi65kiCWKt/epVnP0ee/9FU","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"ZhMMWd34wqtGEvWBJ6vSyBFVd/9yW7X0tpynx9y2RT8QTfelIwWadnZIyY22qluWuS8rjWaE6ZmsNnzv9z3iCg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAACk	1783667622644	{"key":"0bb9aSC9Mov2xJy06nHcYG/N2T9+piZV59dutSpKJAI","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"qptGAzxsy2UH2Sb4UY8hcQ2v+CkzEh47c07RgkiAeAzKFqLJ9B32rcM/N5Zl4iUA9jzrafQI8S2ky3lCHQ4NAg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAACo	1783667622644	{"key":"dsH+vuTraQ+1E2MTTPIP6s84j3ONDzejaPqkGRznJmk","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"+3q9SZmckgzKk+gJiBcZ8qNZb6Tywg4J/l5cg84x5gjpue8g6dTX+LPgCG1d3f0qrkrH21RErWIaSfWMSm3UCQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAACs	1783667622644	{"key":"Yp0YEt8q33+2K7VXTGhOC8QVIwot52aEAGcV6tV0dV8","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"6XsBUdZ5Fpv8Xfo2cQljMI1kOkPq/zCGkcTML/2NdbfReYaqliCmBJ8He9SodWqp77pyMy1ejNlS/6tRRFkvDQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAACw	1783667622644	{"key":"9T7IGNernMltSNALUSKjuvDAfH3xzvgY3c9o2XBBAzo","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"SkAvzfqTEUDfmdHJKOjIx+ftOLDFKJWiWKxCzZ/y8uu8UwNFoRKY/BfvsJig53YTnpdZfD471HczEAovhEgaCg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAADA	1783667622644	{"key":"GyDMuhviCPMOOaEgQDItcaAUDA6HYjnmylZs1DQMDW4","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"9dH4op7fFiavNmKZ0ZjmsXt2sF5irB0vTFMOUiTNgoFqd48NX/3mYKXkkQu0KRdQR7Lbz3tS7d+RPWZQpV0cBw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAADE	1783667622644	{"key":"+J+wcSRwbwNIIOjYTqG3Uho3jCzWJNXE1AHtGlae8kU","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"GecZ/LG6+kZZlCf4uT0lD8VdKr3z8HWPJ/LzUksYbwhma9bVI0nHiBw6FRr+JrjJCgvtcI4qhsmy8BmX62x9CQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAD0	1783667624221	{"key":"it605ZwumkzP143ArUVFA6qXRDEwApKbbuQ6+DO1fxA","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"o3WaVAjAusliz/mAxd+stpDr7LyaeJu54toPQ52Z6o/LrQp977GGp7nb4uMTIfUvQiSAIcgM2GgGNNH6uySOAA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAD4	1783667624221	{"key":"tHwZ/BE6wA0sIYUs1mrggxE+dZbf8kGUcHvlaLR5PyM","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"MbjMDbcxw7e0FZ0U7WGqk6rb1S36vAJnj+dqEJpkTjFkfEKtW0TM4lTh/wxQT+qZEt+36Gd0bTJD4mgDVJ08Cg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAD8	1783667624221	{"key":"k7wZlLKWBoGXIX7U/WFXh2iEnPcbVFB6MzOxY7pi+Aw","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"CSLu84M3Fzf4pHPHiIg5rM8Pt644++95IT6uR7ebyauRXNJitFgXtWO/zbVbE0ypCjKQK+oZOUQ1gxGkjlyaCw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAADI	1783667624221	{"key":"JD3h6p4xcB+Qlg1bo+M9SeCgBo+T+DpWGe8fdoRneHI","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"ZT5Lg7NyWiNY3QonYFRISilVlsBI0h9pD+gtDQRTEv2+wyQ4J5bPynWjeCQPaeTMMu831Eve//KqxivDtTvdBQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAADM	1783667624221	{"key":"8qrTJvbISlr1IajFCTivUduF8qJAADf3dc+R1FCrzlU","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"SnoAihi/j+zKktomDt5Ios8SB91Ach6p6SjXH2PCaLuxUlk0X3PFi0tlfR5438rmT8MaEENv0Hl9bXKE8E6QAw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAADQ	1783667624221	{"key":"dktvtIAqCC2mhEQh/saUvG8aq9ltXvj2pBzhSECzHD0","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"PuMrSIduqOJ0LUP1RtHh4pgZWvmCdMtayDSA/N0zCs3MCoKTptz01+dq07X6iRnYu6RTicO2weRw9rSwJ9PxCQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAADU	1783667624221	{"key":"1Ef1b4wuUZNED4BKfluIkaqM0mSPEgfcSXEyL/XSQk4","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"PrbqjjnKFSA5fkYoctSo89kEfXeN4NF+pFoGpR92hYW3bRWtCHdGjVXmExsiWMx3GyDmmiRnY75mezLIMWUmAQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAADY	1783667624221	{"key":"blCEtQd7dZR6j1fGibsm7W22dqNID54nPhozusluLig","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"KV38AD8ftbvFbC8x1GhhHYNA+CsZDau5BUAm9/OPUvIYadeB+YsG5BneqoMd6Id4cEyV/kMllY7wu3/AM3LYCg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAADc	1783667624221	{"key":"9bJzUM7VYqZzxcbqREhK579p64RL98BcildGQuzAjFE","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"N6szAyDtbQQ/mdPqiiBUjbA8gWwOd9GVhXNiH3PEzfLJ5QEvwR+JTp1ka38jZrsLuDr1UMq0WHPqt2qcJDDvAA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAADg	1783667624221	{"key":"2jEH3pxfvsiRiNJQxsWjpAEMk3UbdtPGzNWx7cpMdyY","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"R50ISidw6kPQSHKBnLozcHCvsymgRw08uqa9jaVROLvDCmxZyGz9uVn4yQ61zR9+q+Nbxozgm1ML71OT4H+0Ag"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAADk	1783667624221	{"key":"PXKf7zV63jdCUL7W8rRMHVNMH1CAwxdYDdG6th07JgM","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"8WDBkiaB21V5HemPdytKzPfiCAO372Z21P9YzmOVwb2k6MV72C/B8if9oNLjAaEx3IGfB4o/QGEgpbdd0zFEDg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAADo	1783667624221	{"key":"6BAkMCVhM3ivufnGD7QPR7gztfNeIsUtji4HqqiZBk0","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"bNyB4oTg0k/JUiQ1nu1IZFC/iXCZHyAy7W5BYvXT5IsmA4nfgWRUas2+oLwQNSG6gYMB4bvaN9IatildgjcsBQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAADs	1783667624221	{"key":"oSp9oNdMzqfham+c4EOJsq6ZNeKQvnNAUMBTvJp+4lU","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"QNNEobTEHyvs+XyxUM9qW1606WJKV1KFe7Z8HfzQYVz3XGQ3qgEjg1eOdpsJYYjGCix6tn0XA8vj3lkfKfMaAA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAADw	1783667624221	{"key":"j196tgkPA/eDotpvUk9sTs66Swl/pAL3o99TJ9YB/nA","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"lnegQK7vzoLVnaXJ967ALnE28oAhzRqBx1NOLoH6eF+Ld6Ae3dvun+t0/Yg0ZJUP6mUnaoU0ebXlthKsIIxaCg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAE0	1783667624221	{"key":"wa0UfLeN6LBjPyDC+jtqB6tDwqF6SHHno6D/ZdP+SA4","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"7kgrpFJlVKyll6r8mHJlLgXr/UU0ezQlt4J9Y1cY8dRjnX8IdW5qA8sRHt2AEB0qbaZJZ8OGuSQukL06wRBzBw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAE4	1783667624221	{"key":"bSJXtLp3IxqyByPPtvirx21AM1ZNd8cd3wrZr83/oVU","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"c42Np9sPhe3mtWtRblpVacFURfwIXP0l10HEpbn4WY/XGrgLHAiitnHAVUR84y9FJi4n8+3LqOFif9sFeCKHCw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAE8	1783667624221	{"key":"roMMZI3QPZP8jjcAgAr+R3/inOnlhCA7Aoz4za3Hx28","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"FvwNCypSIcVIOBwYOkDWUVPVg/0x07P+XiymvCvxasWE4YmV4wuUeEw9wmyx5xs22sH17rqnm0BinebGbOgQCg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAEA	1783667624221	{"key":"isRCPODH1QVdREPjIg//L0B7VQDWdOe3ltZt+jpRQEE","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"RuC+rzg5Qj9yDQIBEdkWZpwms2HqLZKqSjtM5vvzQwi8Bcded0uSH86jrzQADzXgFp2/NwrOtv6tiLIQlIhyAA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAEE	1783667624221	{"key":"/iPzStTfVkFZYls8mie6D004VMPx1VEM0P0msUzjRis","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"Fd3G/0RYM9mNzgn0NdwDRuVWQTie1jtvZ/RCgYaBFTGmeAXT+HRZeb1tT0u8WKMUMYqicy33anisUpi8TW/SBg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAEI	1783667624221	{"key":"idcmMlSA7pzbvNhaskU89/uiTBjBf7MOp09TeggmcyI","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"IzlmDvH+2JrQYhf/HryNQEcEmVHMYG0KxESo/Bk6IynI3vlDxRS5EiHrxXIsK/UvL7/Lnfua1kajJdwZhHLcBA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAEM	1783667624221	{"key":"As68nIwK2T+OD4jRoAN0GcKY7vgL3u7jXJLuN6kukSg","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"QUQZNJBXYR1FRhMlvgAbawMZ1Je6qpg1dhehKy9gnQrdo0sc2W+9Jnf/oVbmKBMD/WduvOuZ9vDtxhg303ZTCA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAEQ	1783667624221	{"key":"08Cj/oysr7ap/FwU1y6VCknRuGQKD0eOBaS26g/As2s","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"1xA7RRMZczgeUX5pe2h2UMcxAF69Hdy+lo1j54oMRjQLz0+4FrFasEpPHyW7IQjCvuooyjZV1Sw5jcYjFhNDBQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAEU	1783667624221	{"key":"QGHts3ib0PqZeSpF2I18Agrw5Po7yLr2pXGRTD3EiF8","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"7MT6xsU3HEuBUNxpQC8Rn2QFtYKTUjaz0+AMrYag+0CnW8xXLXuYJazj786JLr6DU8ZdtAX9BpI1x18pikeAAQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAEY	1783667624221	{"key":"1OTUEzEDO0O5sGR04JjDPZCBIWtU7qotIbq6B6aW2x4","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"TtKjSL7HV/X85KLCX7vOvYtiepnU+ebxoHecHAHPvGZBLKvbQu7VyU4gbG89rdcejihfsmm6QCwBHsYuw7PBBg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAEc	1783667624221	{"key":"n8twedxRHd233LfnmS0bHwMtYXV4ht903EUWVeF0rAU","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"YxaDyovH4L6C03VwioP7m7UQKVdR0TciooKmil4Rs2MdMP9cT4G2vraU/IlUjNs0VW2rK/ttoLyF4xxQHRp/CQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAEg	1783667624221	{"key":"kEb57SKa2XvNISCxEjGKyu4FKsZnJ8nBatKIddqPRHA","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"GSEsHft1sZxqaiPG6LkD8qIZEqL8+NAbmUjKJW/iSFijzZ2CvBh4k2CaLI3ZDh8ELdi2mXNhVJw35MwillQEDA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAEk	1783667624221	{"key":"IcoXUbcTvlJF3v5IK3R3kqaEWm2Cevski6dh/ICFWC4","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"c25t0KCampH/7/BPd2KWR683hFDqTMYxDD9O8rXTEKwbb+gkIZOubnVpoisqFsmA3wk58lhd47VED2ZUSIxTAw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAEo	1783667624221	{"key":"5Z57voSdAZ+5TG/sI8KsmArYvbxZExTmjUiQ1js4YGs","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"cVPsLZKKurYH67OpPiK52I6WnLPoNLIVeIq/ZgS8nIOhAUabMXgPjJE191LQRg4ei9Ckd9WtvoVLmhWNDRSNBg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAEs	1783667624221	{"key":"QAIxlKohkFPdvMkcGnJbO4rY30wOGcQ6GzLJHRupBVs","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"7uS6oJklIbrkgbx9mI+Wh/e1JluRRv9tcETX4qlsyR6QIMLoJgCQ3zXw6UQH6zas7ZspJN/FAVV4T89UkDehAA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAEw	1783667624221	{"key":"BAynOvOzPbdetsszWsnpmLnDFELEdpUEeRzZxwrcqhM","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"IAg4P1u5mF8JiH5gvMVSAy9HcrYcmqFekHKi5k2jy8NTd/Gy8f8adQ85LkFsZPa/hBEmReiNDxpf3HFA/i/NCg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAF0	1783667624221	{"key":"1fdnjBmq1SopMktHollxtKCdE0+nb8W8VKWRMp2hmVM","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"jY4A3hM8zwTsrVhNocbbxbd7iS1DktxRTwX50rPe8/MslHlkB77nystBinBzo+iTQJ1P/sbFkkdIS9iqm15vAw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAF4	1783667624221	{"key":"1dsphUkbiP6qLW8IuEraYyW4UnUrOQhcQAUKlMN07nE","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"UuVkz2okAwhZXm+V9xnyZmaiBbIGqprDOJEgiHMm+9cmbt2OeDk0apUkCiLcwVlXxctJ0p8z0k+ShOuZqAb6Cg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAF8	1783667624221	{"key":"GM/rxQoVj4jgN80tZXLg16Yo2m+UbLS7Qj+m+puSLEQ","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"mfbnIRf5KHDZ7LexYz9tIl5DAPN90Nj3j+v4Zovq+zi2lEcnNtQKlQL4Stp5D4IcQh/3jVDOnor1xn1FCf1PAw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAFA	1783667624221	{"key":"g/99U5HZ4VQJY0gRtdW1gXjnpI44ML0Ozz4RRtw/MgY","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"S/SZa5x3kVMetFIYbmzHdWJOzvZ2ghQkNDDvdruRRiDEeHYdls+g6JgfkZax6H8T2sKvJSH1C4O0d3p0sL5yCw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAFE	1783667624221	{"key":"bkjKNhT3fSzdWKbFhMEMaxsSs1MYJjh+1jE8oNxW4nA","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"rkz2sbDpyeakvJ5OJ8qXCjrMW6uCL/dDwmEtmxfcw+YyXuNUREPAOrk3zf4fB40riHfjC7F4IkYStVElEq0HAQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAFI	1783667624221	{"key":"aR+Kaj22ynSEB8M/2ta4EfDESK+cC24SxnXhXPEUH2U","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"03xPOkndPGG4NSOS2q8a23EfqTZF+gM6bfcgc7Ytk7BmGAM1hNnDdMvgMfCw36PkQZmX9CI2C6rCi3G9ZaR1BQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAFM	1783667624221	{"key":"K3/I2y9VWYoGa2zPUYPqJx3+ms79wTH53O0cKIhnjkI","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"vcYONZDgEK7YENlQsY+pzPQCFbif/5BrRI/+eJnjxzWRWdgvjcJIc2lf1FXnR6w+4VQA+RdhbwzrWmBKNL6uAw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAFQ	1783667624221	{"key":"H+pppdZUdlDf51RsEeNOdyLOfyCz1Xjz+qc/8xtdwHk","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"qXG8xpEakTgyofcWuIIBzf19o0kWRM0OzbGStms8A5rY66lvyXhZ0D81WCSjS+eoQbNVbp3jn/UCe3TW6F/tAw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAFU	1783667624221	{"key":"CUodpgsbdHjtkIUsGImIdZR7f7tJravIv+ctgpzngVs","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"jyrRuGp4ZjVr6lZpR1YzcexQA/8MMT3zd0qPoAMvKGQwNttkeT1c7Qb5/4WXdXIDc5ncjd/+EanaPmeKBYmPDQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAFY	1783667624221	{"key":"8+xYotKz39Gl6SttGxU4s24VrOb2vlg3z/WWAnMUcWU","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"3mBvxNq186L6bc3dAvjT6ZOM9JmHLLvi9CCJLgh7RNba/xfHKEGTI2XQ2B+UuJA4V0SVGZw8tvry0o5KD6TIBA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAFc	1783667624221	{"key":"KqUlRskpaOWAKirybm1jaRascKNhJ1MU3ILy+UEvNmA","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"IgqfpN/hGmIkCL58Dkg6ecq80tbP8LR7G3NTzQGWmLo9deNF/B7H6Qvye4vF9EX1bVUdk69czGrQYsMYlFqkCw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAFg	1783667624221	{"key":"ozqwHaw11KiudIvgYVsmQpI+B/dGb8kfqDm5kURzWS8","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"wdTwIsvTsopkzblA7nd5wcrChMo1nHOOVXczQsgTpIBoadIlQVFkHV0MpPvaZ9iqk+71GIiyITiOfbhrJvigDw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAFk	1783667624221	{"key":"0fcJ+MhGTyFVMkPMNOHsG9yVDOV3MCWR8cnIVf9sPBs","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"cvmNYi4IFh74omww+LdlN4q4iz2EPeSOrRJvb7meHxh1Orxe51/GbvAEbpXhiMp4LPV3y4EhsLkhdZ9aAfJqCA"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAFo	1783667624221	{"key":"Daz12COIS6LQPQXCrFzHYotr2zeXmePra7rbRUT3MwM","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"IQh1w/c5rYjxITq/2Nc7gQa77DTDB6kCgokMD1pyBWjFFLqCIfIoejdBOgKHVdW6HWcwVNwgRWiP3DfCFgraAg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAFs	1783667624221	{"key":"4jOBmGs++x/4L579iAxlnZh+T7RxKuxeQq7+EzCUmTI","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"Mqa6I8o09Y4XpICLu07nG9jIcIar81epW2ewauY8s2JfhAStKLiGvuc47Wz67SS3hSPQNjAMI7mhFtBq0LRFAQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAFw	1783667624221	{"key":"rovGsUDaGbTnszO68SMy7bBoq62dDenOFbN1tW1Mf1k","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"H4IQAUbwdTZ5kw/snBvjd8/Tox7ouqp9sjmbcIl0Il2rJVBLCAX5Vk9DHt+sSSVNy03uRX8iKmCBD+XNiw9RAw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAGA	1783667624221	{"key":"VL9cfG1zmVLFLzQJrTTh/csNoKyAzqxwZ+HKav7NGHY","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"ikWYT/1J5jLgBq6L0fRrstLcYxSgq/65b1JiXQ1zxZKuIrVLrVwe+Ozn7A0JSyzDqbfEixuiJgMxLYqlIfjYAw"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAGE	1783667624221	{"key":"x1neX/NEHZ4miFXfKjbk3fCSFF95zPr739KoPIyOUjo","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"5/Z6OSxC++4AQakP9W4JyrgF6STIKu0x80X/dvFcX3txq3sPIZL9dBpiNB8u6TUEASqbt6E45dsaseJQd3xkBQ"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAGI	1783667624221	{"key":"fBejELaQjKwFG0bPEMm0MJkdJ/OQ1aLiBnQWfLSpr3g","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"sm8/qXC6KfWR4KYdaH9hftehYlPSqxeYXoSXpr8N3k/Z9gpwlz8eD0W6UBduoc83l9ACqYDLF0dkW3QwsT7oDg"}}}
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	signed_curve25519	AAAAAAAAAGM	1783667624221	{"key":"276f928c1m/BGicM2TIQTkT0xkgOIc4cx1SqX0HHD0c","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:CHFTPUHNYF":"vD2XaFl9e7YRWcqehgkSuIupV6Q4l+fymeb2TMdKE3RjluS7o4In9cnFocX3ndVKH3nzb68BmgpevY4wq+9YBg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAABw	1783672186104	{"key":"cTABRIGRiL5n7GlQ6x2xPSO+VDyQwJ5bMQ4kQQxiElg","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"TJA8NypYtHeqSYkxh+gEDbG8sXW26lNq5HzuinrHiQd1xer0vNpzY3xcJJ6jurDTgOg4hTuHwww+GoH61pYUCA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAC0	1783672186104	{"key":"ICT+4t9EYvOAdSZF0KbDZv2PENbzkn2y0xzrqDnmCVI","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"p9n5n3uAZlfpx4/wcyj1l4gFZpoCovcs1gsjmtGJOT8skGI2GHFiFmH9zTTYwNPOOaj8ZbWXm/fKejRPRFlsCA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAC4	1783672186104	{"key":"mAClttrmNYFajzJ0NW02Fy0ws6891oMapgDjOVa6BXI","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"ZrpsrCWjsFYCTwx3ia16cZn7qb44c1vNtbi3s5eezdOgPoiv62veQ/KgKMLw2G3s1+G5YSHQJhPV0pfqJGwVAg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAC8	1783672186104	{"key":"qHSNL70sR6PTgFb5QSvCxjW5QmaMNHutB4xBSyTv7i4","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"ktDtahhiWiTjR3GgFh5xYPfASKYFniTVAx46X6c/winVCgHAXEqV8/IRarBeE7torAcGl3OgWIbqmLOHNB+KBA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAACA	1783672186104	{"key":"nYQPLdJA4Cf8F8N/Iaw9y0n5XTCGAyFnmT+1ECwjzmI","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"zJcs928BupaEgkKbYJThE8JrqBjo/fApGywuOhorLI+3tkIgrHWNgX6fUwKxld6chPApH7XnFsmw+6lA4ob5DA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAACE	1783672186104	{"key":"ZJ/GN9Xubob63xnviVINoWJonxQ5mabvfmw3XnddNxo","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"0OuWrR1ZECk7y/4PWBUPbk/ySj63VxxgmmJjmKv2feZtjlxbwYehJts3u3K239fRCYAJaTjHRhtI7psBh7WyBQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAACI	1783672186104	{"key":"Up1qLTz/iu8cRp5p8yPKsjizBNdMlFe+VfonlYkCbQM","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"L8pL1eAuyRHOeUSz/Wl2/h0eWUE1rKRS3mf8rSf83QIcivqmfJrVVxhS8yHCelyZtA7vtImBKqzS7GrDD9RZCg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAACM	1783672186104	{"key":"+2hozGHPq6nzfE/nWf6YlFEFRcPk7Jac0Bm/bAfkLhQ","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"kc0ztMAISfuizfGcFbJUSiZ4BM3JJPjI7ebzSTGCUe2vP0Z37gVbqQyDyhuVheUeb8Zn+lf/kiqzaH2EiheSAA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAACQ	1783672186104	{"key":"CGImZEk1rmjw8RZKrISnixTNYIjJrSlJwHEg6M8YzlA","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"E+HY4SLeq/YAVfWBzhvky6DF2Tghu3/bws3zSdMOkYhF/0t9QoA4kC3l0hJKmHn+9dGBywmJBO7WnMDvztiJCw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAACU	1783672186104	{"key":"szAHztpeXRG16sAG08ILs192lgjK7qtPPGs8gWdEdSU","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"3DOR+DBbkOYh1l+1uuvVjzT06Arx1Zd0BBlLagkAQsILS2nG9p8yc+EOaZ2MWkFMOkUd9LYhpNfh+REODMV6DQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAACY	1783672186104	{"key":"oEQVFLIHxB0hfBQeDuoMA3sGn4GPGLhgUH64HIRR/js","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"hnOXSP/VxPv7OqHZj7cR4E50Jyk19bcv3f/Gu8EUU5laF86MzQT61p2t2W2L0VHRS9aU8EaoKJ926r3JL12uCg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAACc	1783672186104	{"key":"d7bZNqc5hSKXz6iCD3Ofo9bE4KVrHYClg3YHl3sW2Ww","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"CqVlS/Ssc048DDqO6ToPyKwMOtP99N4AQgYATiVm8T7K/HT9OS2JUnis3ailhGEM2lPYvqjPsHjzJj4jdw7dCg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAACg	1783672186104	{"key":"KkApe1pd43b2d1/OSBv5fw4qeOMrN5jDfTmT7xfmkiM","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"5BAgVNQkuG6Y3zSPDZeuI6z5dz+VKcwpN3L8s9Rm89J3UJBgXTozMCrDtSGhSoGG5RUGj5o8Pgd/lYSobMLRBA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAACk	1783672186104	{"key":"tTFp59NzahYyP4LYoNzZvd5IuIdHSroIkAOf+ipfHU4","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"qgJe+TZsPyWA3nu+WcMor9iB4rg3RLoHwGn4oLesuTEuuV73k5Ih0DqNqmDFjVsxiuKF1xJ8rhTTha/bj4IkDw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAACo	1783672186104	{"key":"35UtZ8gxj8/RzyAcRbfoCabjfEDKydoChD8zTJ9cXl4","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"FugLngSlOefDW0M9ZWKUouC3G5Au4nfLAQ667XnDw8q2n4x7w7drWZDET9FhXSrLSE8YV1LX7GCa3S0nl9ZPAw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAACs	1783672186104	{"key":"D74AK8s6MtXLJt1S8puM+lR6YAvYqnAk69W2RWswqEk","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"3ovAEZvTu48OYpfHH1TRwHaVPjHJNyrNhsHey3k8NfucY92tEsyFlu26JU5aAEVcTA89juFGvStK574Gx/nQCw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAACw	1783672186104	{"key":"Ky9uezMQAOed5n6ixAOkHNBkIZFRZUq/PpoSrHEgLlY","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"2lbez+WNZMdZVel/04GpUviIVm/DLhUdikE6LCcK/FWsiirx+8wMxXi01S4cQULgaY2qXu7O2Gts4W6hoZSZCw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAADA	1783672186104	{"key":"VOs3nSrlxR/++CF1U/cSppAL/1j1gnexM6VUb939v2k","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"Viv/U4cHboYxE/YZuh8FEIlpSYXaMYmv5KiXLGSWg7F3BjwWlhl1o/ahaGKNqlWYxWcNIALDncuQZzy3zrZODg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAADE	1783672186104	{"key":"56oFBAouHabA7amAHg1m4/1vFzRS+dkIFNu5xNeQOD4","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"NGwSa83M9UA2q5immjAl5izE/Gc+FWKxXRXhPSTzjMyprLH1DMlnapk6QqHNQsHNJ0p4jjAPdnGZ0mgx+yPSBg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAD0	1783672187324	{"key":"4OnXJzmknSsTeTJFXUJ9YTg3ysK9O4omtRnxjF/jzUk","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"Zn1c33qrO31aPLQvu9cZyox7uBzRhMr1RUHJyafwrUNz3aHkSM+6b0EvuMKJyFeMRKROl6LmjpV9MzYuIeZkDQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAD4	1783672187324	{"key":"Dzw5qSaMcN3yOvLnoH68TWQJAK0Cj3TZgxQhvhKPAWU","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"AQQM/vDnNCszx1VNi2tCZwkyoqsT5BSUeQIq5VFkKiDAdzRaw5VDdkMnAAc/3wzpnoVkuHIT2wvuzmxTj0D6Cg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAD8	1783672187324	{"key":"IfZUZghD9ML3VlOPC+4SwIcwNPvv+r8immRJhShJCxU","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"Bj/LTPJfol3Zfl3dju84rRVz0dDC/Iv6ipczSOh72/46j+cFHutiam9vmZhh/ce/6FqS6uIQkru9Fu0OoXYFDA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAADI	1783672187324	{"key":"ltTjWLx6H0m2zWFX6arok1TljLwtOcuV7+fNoIX/RH4","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"QW8pRSU36lS8MwHJGtPivchkVNEK7cHC5fUThO9chEgh9ortVQu4w6T7MVsMkA/OMjwMi47gjiPNkyJfamrrDg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAADM	1783672187324	{"key":"NH2Z8AWcsavo+WHAagdEckY1G2mb1FMFUIz4DrjDonU","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"6sJ3dpvTaOzV8cy8cFgNQ+E7oBLK5AndmfF9vzq4xj9BG+YFpi7Fvr4ibGgJl76ArOvtDoLbJ/I1DYN1DK7XBg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAADQ	1783672187324	{"key":"EdKlIZTaJCr5YMibNugnMbhxEN2zdlHDLE45Y0iDJ0o","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"J1D0plJg+s6xiusTFGuoPt9jWiGrQ0WtOGmUzR/EaqHKMhcU0NmJ7uXzdVBW9y86TrgjLnu9ZUdNf6zHH7I5BA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAADU	1783672187324	{"key":"pdJLSEr6WRinPXXpGIcJIHqsbkCeFfQw6meHENPWux4","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"0hJdG112J4+rDHvEJUWwlsRwXn3aUSfMxdWBAddPWzFWFGDqPhmHoOKu2Re5MYUFKF+Qqs0763MNkKTtXaGEBg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAADY	1783672187324	{"key":"pAnTyuOFoHdDVnwqqZBSMlYuBTBnYIjkGHs1b0AU7k8","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"r97BRY5P0Mfgsx+ZuNutivu0dUoNUjJkqy295KVCqEygIzITPwfU2bySRX1hgh0bYrMkiiRUH7fHy/1lqQLEAg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAADc	1783672187324	{"key":"kKseVvkOzAXfAgtpT09Z8qfRTlEpf34m3Zu8JERs7RM","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"/hcB+DenyzPrmoKG1vgCKzmIp2rf7A6cBQP7TB3c+bIXgyRuUWrKdReHY/tyNVy12Lh3fiJ9UM1Fffr/t8GQAg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAADg	1783672187324	{"key":"TK5tSipK3/fhV+erhJs/eYAH4jW1UO0N5aCsdhv+XxA","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"l/cgo2yYZ1vx5+5dG2nEMzfzOdPAZJanVU3SlHKVY6Hy1IzQOyyGbvLFunclNCGUGnsWgLijjOxGV9PMuUwFDw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAADk	1783672187324	{"key":"N5XQFcGQMYZYzm4+caTEsMAtqcowXTkEbUtLUlMG3B4","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"pRYYngcoX9Jk0j/Ir0T0PdOPe2BT54coHTqShSi/yzKFQc9soGnh/Rs3XM+ryETrvGB3K8LBxMps2QsADPasDw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAADo	1783672187324	{"key":"NAFcfCRV70ePSE3QZfMPeLapGOCgzfTC8G2utDkWKgo","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"d+a/PcGb/fzXsLZWO8CHtRQ1nqw5veWZ28VsdSmeXrAedTBZRstIPj+SFeTxrgF4pjD9yTVPIFUDnTvYJ0nxBQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAADs	1783672187324	{"key":"DiL5fbURxq3LbUqRg+fSHrX0s/XfNiS6KE7xi4xA9yU","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"F+WOWmYs0qOuahdRc2+AN92NfTrXZjilLZDaCnynyXS3NTYr2yIlJiBqrmD0qGATbyUwis/hzhYSdo/aqSlSDw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAADw	1783672187324	{"key":"aUX8M9Q9Qk+R7jiQqcPOLm0yjQ7ahCNRjdwlwfls/V8","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"b54Q5L++yCvxgsJ7lemxResnmAYLmmTBSynSxW/jKnr50nx1vBliV5GXO85lHFb9fDxy5psIWo9u4EmYQ2E+AA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAE0	1783672187324	{"key":"Oq7/X68SecUBw2qWF71TXraefRjeyUkEZp/z4Vu8Iz4","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"LIvnbSQjr6CiiFp1OASEXvqq7L5zW7x7O6XUizGvv6/Wlu/dl9Y+IZoj/+fTDiWcwfCsYmoJ0p60ssZWwZF0Ag"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAE4	1783672187324	{"key":"vQ72mI4a6NPzMVPMksBaveP7c/owzgre3pnFv9ClpSI","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"Ie0fAxctwYY6iN7tV/zUpz+Eue9DhYS4aGY3ImGWo5ZfbZTQlr1xKfTE0sXIPiqh7ek2o9FMUMmZRrRo0cTSCw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAE8	1783672187324	{"key":"gxI4r64VCh3EcXTqKpXgpXiW1eFvBbBvXXvW1TI6eA0","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"lHVJa4+KgVJWwvBHGZdYnPIPmlG7bV8qCivuuyGAOwHILITrdj47mrTtrnl67y8X/tD2dmVMEUyVrgRWIiCpDw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAEA	1783672187324	{"key":"hy3ZSkzCWCyRMzoGgHHHrIVSTr4ebpdP/F5FttHZMxo","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"zNAASqFgNeM1xO0DxSLWMMcNMpqJCvnIPZ9RhJN7e1XYG9YSNgNOM8FarNMPK3wDqab25isqgEUuDtYDZMEYBA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAEE	1783672187324	{"key":"jzeYYcFLgGZGj2hPUjpcJgOIj34+JfVf9gImDE91dGc","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"r61HvGTxvB6fNsb23R7h/X0GfFsNph7Euhn4Q2oHOUssv6O6vsKPuy8yBfGH8LkxvTpshpSdtywDtrOy0hHfDg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAEI	1783672187324	{"key":"VWWP0VomnCfd7hSCsNcPnxqcGo0uSq+p6sHWgQIT1VI","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"QsokcuGvssr19fYJEhQ7i08ty9JrPlgCgKRdMd/WDxw4STWrlyNAWm8JbtB9AirgtRbAXryxyT5GOpUs4+/5Aw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAEM	1783672187324	{"key":"hcJfbfWWAxR7Zhhgu0TiVaGvO/Esahkkm9pL0kx1GAk","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"DNHiIfqCov6qLMEcE6JHMD9Vju/3hKu82r/s/LMGTPFD9MuhOt7H+y53IfCLxjNhznA0I552AdqXxL0GuELHCA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAEQ	1783672187324	{"key":"9jrHq8RX4oCQ5QtGYGIaAThAjIF9bO13imLvJlUzrwI","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"PBrfVvKznorwQJT6KWQ0UF7dDXquEoV5CANrPs1CqXYbQHMZfIMs2oPShXpmzJc8nYRGyws8NqcztRxJnisYBg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAEU	1783672187324	{"key":"Gk3b9tgzET0Dr1RLokTg19SbkWrIrdkR72d/uPsy+hs","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"l8MMnGaKWKNxOgTPxCViqUCSe3bihYLhyiXxupTN145eQcW82JorlT9xNvvnOsHK08YhcwG0379+lbUlgIhOAA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAEY	1783672187324	{"key":"q25AUie+1Teg363JN5DFrVWzI9UlWaVg85VWk+u8Tho","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"OyTa2X9CBnpS24gWVoZOegAHQ78JadyoA/V0ipolMMt4ng9AlBEcMkYEMh/gMmdM5xgb4z/sAotCyy4bscEOBw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAEc	1783672187324	{"key":"zeYxnx2C/l9NkszJqY53eo8OBTU5UzzA8ykyoZRn2iQ","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"dlKtuxiARsLVZ4b7/+tFRLc6Xfjgcp2UBgxlG4eNcDm4D89MweStR6dRPurSi9cE0ZWBjfKBBEZmQwHE7troDw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAEg	1783672187324	{"key":"cIopWKMKRSjcA8gR8NRGDAN2cl6IrGtjOtilqGFoPG0","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"wvweYvNqYWDos9xPF+FU1RusGL+Owk060lbhFU+BVU4E4cQoMosHaIDLrBHPzkaCxhaelxM52nw6vbcMv0muBA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAEk	1783672187324	{"key":"h5pI5c78raT5pkOKNysS1xr7djoroi7fnsM7MZdCOG4","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"WKRiTiSMZZt9tpwlNpTwtwFdyXo67K7epKYp2tg7Q4PvrjqvNrdXdJWfoiH3PczhuxLvJ3JlZydRXOC3IZpNAQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAEo	1783672187324	{"key":"kgTv5jgM7dg+25BrEGBQyT6HUICAITwWW0SSbrr13HY","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"Yd7Xxl2dz0G4XDYotcDAlAuc+eiB+Y2nnWV3iMQi4mRNe1ngroTLndCZsp1RBVDHBC8COHnVsrdLYHXlVC3EDg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAEs	1783672187324	{"key":"P1nGY8iuYYkzzjCEO9LBdaUPjDMf0dlz33v066PdUTw","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"83XdX/uAfttjpWZXHbTlmbbwr1ux6PHR23iTPPHBMQlaiv9i19uJfKcipx/j+/0oBIk+iLc7v49PBCex7tH9BQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAEw	1783672187324	{"key":"25lqXlqj3pjGRsyhQS63z4REQ95HiaSaReua48+GiCs","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"psW38g9GEZBvtdqDcCOC8RtmFXwxanmFX9x6gQs8CU7YIwyetwOO/Q1OniHhQHUBDgXKNrQlRvxUklUMPQAxDw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAF0	1783672187324	{"key":"f/UoMu6n3ZIgAjTBEkjiGuIVlwHmbviZLennW971oXY","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"hfSbYlVsmA/F8dioLlh8JGEi0zIoC0CFpaDBJ+BF86OgW2MrUDr9OvEpM9ayT8V+pZfhXgcE9YDF/CXnj/HLAg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAF4	1783672187324	{"key":"APNGmV+XFvwnptLtkWMhcbgmbIKSiHP+95vuxQ/DSEc","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"xhT+DjWfpNsEwGXcS9X7q8MthMjcvCHJBm+IEBHogt7s0wUdTnCjmywBi74hxuRoqKElZ5313tbnN/sPJh2EAA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAF8	1783672187324	{"key":"j2P68cGwns18MDX74VcepmcCFUb1gpUS5Mb9LLjHY2g","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"LSh9JY3tS1Pk7wg0BdF9YW32aMo2Y6GfRHMLJJ7O5HJlOgfSDRYh9+Exn1r5y4KiIYvj+IUAevMlpAYcw7hLAA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAFA	1783672187324	{"key":"laYJb8YjO5XyBHGIuu7i+hI6wv7y3LFcn3F3HUr/+y4","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"/FHJRbVLDhz/0s8vXwgcGrAiM7UJHHbyPmVOIg2rjlDHuEKK5xlNMJjp1wmfJ1LYwlf81LIM0lhnU7UjoTYhCw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAFE	1783672187324	{"key":"7/NYz5rdwwlIJHOo611qD587nC9rx+J+7QpuxyJwRhI","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"RdLYWssMTn4zXrEQg2tTMQhLswZozNsqD/auFGfSCblHbSq/1JFg0KHJ9YP+TpWQlEJGsWW+m5ox8suIXAGhBg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAFI	1783672187324	{"key":"/Mx8VVm/jGynOwhtRbN545FjNNdIXEroRYmNyg534gI","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"65PU0VxdDVMRCJbwW/cbJJtiYyORtJWGLePYAYrgAczYjzNRAXRA3T14eFzmu8AF2oTZSPhevm3CacuGOJjSDw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAFM	1783672187324	{"key":"hyGUSLgSCvxHmFefD36naPZ1Abm47UMlm8PCG2fT3m4","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"SHHPmFONBz2MvJlRpvxIhuLNKlcNSyaxY3aKQC19ACeHFSw8xkrdG0C/ZIT3SBx+7AQKdvw8wbgF9AW/N+5zCg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAFQ	1783672187324	{"key":"XO1JsGTdUxqzbJytLzXC8/jU8Ccr9PkZquzmfjdtWGE","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"r/qFuyWd7jJy7qjsFfhz4eOWTRMAiaTCKXky8ikj4cwiuUtznwSlvQn44OPItriUKOK/JNxgEY/lWBglfZDACA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAFU	1783672187324	{"key":"ih22nSmNe6K3SAwacbSvKpnJALvWcqBAu0LItH8VrRA","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"KaUIi9mgWAegbsgYr+JO5OxacWMdByj+4Ygt0kBlcITz9ZqlNEUeCaqJLNLh7uQhC2gylBgefe6DUjNMGZZ8BA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAFY	1783672187324	{"key":"n5QMp7UUkZI2bhoPyyuojP9qxGU/ez85Lai80+g7tX4","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"bQyIeXh09srireMtTbav6caQhZo8RMrtbd87yvU/nr8qLJ6hZ1rFxxrJV0uAZEBQMIxXgOEmMMiu2c6fP54rBA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAFc	1783672187324	{"key":"5yOz8b2xEpwxg//IlM7zBado0iiPhPOjU76Et4jCHW4","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"55eV//ibQDafFUcbvMp8veriHUFeD3zmnLvtYnGVDugaYtY+kvpZclDwpFyObSl8DVHnXGPbFs4qWrSiMsrhCg"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAFg	1783672187324	{"key":"lFaFo3RArInNH8sHf/dMWk3e9Gs+SWNXQNYjTf1tNXI","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"56lvCczNKN6uIpeQzb7lijsl28wPdGCgLerv8118A/Wq22eaKsv/T6Ahdb3Qec2XWem8Z385jauivVCdkCN7BA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAFk	1783672187324	{"key":"YdnU+W3d715diMLYFRHv8x+nblXJWZXDzU9TQ6P+rFI","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"CyFJq2k+xzFBckDOO/Z03CpEW32XNViCqt/NyJOQTsNKshTLjV/MddSCJ5tH82aIBx+UgFCRXXUTw5oAnK88Cw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAFo	1783672187324	{"key":"HpjEwrZSHGA2D2VJtmWbDNOOnBNYAO1xESMUpdst11c","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"aVnwJ6Qi10bFHwOAjf0/mKz4QCOOj2yHYkQ1ToITiTpygHMMJIr+M4kPARvjOrFm9p/H96gFHeCy2nRWICFWDw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAFs	1783672187324	{"key":"sapMgu0NADNjVf5dzFPZ/D2+41+2eXhi6mWmqpvXD3s","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"lzeZgMwhedQIUuISo9irlMrizOI70t0O0aPTNMMjwhm4iBhTHWouwN6e/2Xgc+ZV6yoZDwIvdUf3hWmcHXOLBQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAFw	1783672187324	{"key":"63aKspOG/xJhc4qOPG+l2Fujz5lXwtFLK2X4/8V5SHo","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"ujP5C8RAH0/13U60QChhl0kJ3/rsRNQpt/KhPXupDLkFkhELXpMVaT5Ye9FGpSKQz04tAH0ZPsf34pNpwzwQBA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAGA	1783672187324	{"key":"extAdBMWstJ257JEnfz6xA9KXOmHC+iwlefYfjfM82Y","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"yFSY729T9cQouJbDF//XOv7dx3yPrO1FAI2V+AlH02Z98b8Jsg35il/iQpClP1u81YJVsgWkZyhBHku/A/6PBA"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAGE	1783672187324	{"key":"Z514zJ2/zFdBl6Kv0enjjqRQO9EzYZgThIzkI+nvDRg","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"yn0W/PVmlzmrINrcxzuZi6FW2Dx00kKAdbQpBg5H+WkimTA+LBDDBKF/GkwOJXcoS257Zcw9CES2GZWFCoNBBQ"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAGI	1783672187324	{"key":"BBK7N6wnWFskm43CEugmJaJBddpiPYXtdGEimPI/Gmg","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"31LXu2sXE5NWoCXzU8e8oInEcvv5DL2XZorK7f1IO/lHqJO0DbKodFMzYpUaGL7w2pFrZcusXCtcg6sQoCgUBw"}}}
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	signed_curve25519	AAAAAAAAAGM	1783672187324	{"key":"lQzXrS9bEgbjVchBAqQ5tGlzuY2g0gz94VcLJtwxAxY","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"hxhdvyUFzAQYmDw4fx9O7yYiHUrL1f6/M+wPN+bPHeEFfrgcwZmgsbQJaWwp6H/TQhzQUPdy2SjQKFE3g4EhAg"}}}
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	signed_curve25519	AAAAAAAAADM	1783672423842	{"key":"AgtlKXBvIcuJzFyQugKZIgo0wkH7FrhBxMxtL9wqCS8","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"7W99w8/9ZtjhvX1jWqsznTax125KREw/2xbd5/+eGP2c3ODIE1V/i1pZ9VXqIB302fb7WPPiIgpJhlWRbblHAQ"}}}
\.


--
-- Data for Name: e2e_room_keys; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.e2e_room_keys (user_id, room_id, session_id, version, first_message_index, forwarded_count, is_verified, session_data) FROM stdin;
@brianrockwell:matrix.shikpooshaan.ir	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	s8LU3T6qjB2MaG0+jQgHd/F+MNfkn3CQ7Q2O4FX+H8w	1	0	0	f	{"ephemeral":"EgY4ukAEI16cy8EPElh6wtqEOPqjh2Okmp9Pg5ogG1Q","ciphertext":"uWQq5Q5NWN0hzU5cCVMlkfvDOv6r4+sr66uCC12+2GYp0hMhyFYpo73NGfdeHVvExDvYq2UF2g11yegUrkngTFejKmIm/RmIshcir0K6svxWgubdLTFSyan8hkjA45oAlMCtcbnc8fzSgGL2ZAvZTmGYOmIoG9JZe91vgW9spyg4W0OCFN8BflP7lPW3XKo9RuMoBLlJ24m0/bJJC5tbmaVcTWHOb+uxgyJe4u79OByzdLPLTrCXJH/NL11YzjShdKc6BILJ/Pns1riin211/StYPN5+YMWQxQpQPBP8w/j/TWCQLnKlEEy3oLgaNZ6Q0/zZE5FIT7Qri/sKC5HhXn2FANlQbKgTAF3MDUe1vpmM+bs3mxys1KKOjgmuFm8HeIPoFO/BlY48b85FjOSlyBvZV9ac+FoTRqEqJcmHQCOwlFRHCInclChHREzkmjlQHvj6FK0QrhEzfts4Z2m1OduZv1yAR2oCyfX/9o3Sp/eL6NDeMRCyYSwIW+O6hERhD3SU84hLgcy16tpPN3a4uZIEc4xw07YJbCm7PqmVDgFF5lOkwjkl5DBuVn0s67aFSTK/EvhLvb6shF4AEIwcbWS+ewTyzlJ9LxJtyIbO/QiUFCz0joVFbkDqvZq5fg9y","mac":"NpjnYEryCdk"}
@ali:matrix.shikpooshaan.ir	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	s8LU3T6qjB2MaG0+jQgHd/F+MNfkn3CQ7Q2O4FX+H8w	1	0	0	f	{"ciphertext":"m3QaCKmt6zVtQmXyxEacDYbdp1Q20Js4gCmhA6OGv1W1hxEUOvHXuwHNPda5sZ7CU5yqPGhYMzYbHGoxhFNfndU6jCmEj3UN9mwrS5zzJm/xXv7kZdMwgzE8kNLNHQ7LuE50LgINsqXtd6o6qD2LW33ucbaP6u7eNFCeCNjuW6LlCqA+ySeSdDN1OKZtINKVg7CAPDHseBHWSkUE+5O24E0xfDQI/PS+U9ZhpCyRY0iz/bKRu3A7wfuEtPz52OxBVrX8PcqcePg/8rlZaDbrALVA+8ouMtpBZs5XZ/dhrHwqC7s3KOxRCzQsDrH1E5kurhO/PVqLzMnlwk8xv+GGirDtQf9w3O7lq3br/IdIcaYBc+zcL3v1aN3m/TTrKEv61eGkcFBdlwpCUE6V8/q/GGiuaDLGM70E9kvAhiIH8IU8SADj7mUiuYvPbrQgefCDerNziOGOizovyUlzpyPrO+Kuj2g2gZ8u2dJ4hqVLrPUU9t0Z8G1UYZ+zz0SUsQBQyVstO9PQfO14Exwa2G/Bo0+hVcsrsKTUpr2Ip9TI2HXCFVfNsBZyBS6hRwXWamCqffa4hD8t8H8w2Nx7a1qiDTZwZA1LW6+Ka8s1tf9B/88sd2oNQLuPZe6I7eZ24oGY","ephemeral":"XdB2Ajzn1V2wVoi0Iju6MmE5n/V2ROciuc6saHtrtQ4","mac":"zLqVwAh84po"}
@brianrockwell:matrix.shikpooshaan.ir	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	Zb/DDBAInmrP5eELfi+I9Wk6/w708BumrPMSBy8L1cM	1	0	0	f	{"ephemeral":"YioDrwWR2/LRy1gngLzQtLQwpW4Ugj/00Hqj99txuWk","ciphertext":"egZkJL3cmOro4lQFB5pehor5QMz/g/k6BnRoV7r+CeW2xECbqcd0A5PcYBKHFbKPiADgGWfyQQQewqJx7plbY4HBrkayCs4fJLnZ+zPgEd6k+pEwQk4Aedt4GE8w06P9KKOSPDlhDjAogSiv5wtP7P82eDaR3kT/BxFCAbTdSLVVvSjx09UvCWD226KCrlufCQTY3wLcroPtkEkRtU7cI7q0ASOGcTUc4T85U0suESE6vOMMBV24m2t6wj4a/Qq6KnUMG/3b6iiKuhVIDM/4rfreWDrUE1vyr/6MujpcFKawUO2hAT8gBkE0dkqMOHvwdnxRBQw+9v7g3VYfgPH/pkHcU/SQrc5/tOn5Vkkg/n/FR+SsTqMoEcFn16hwwKQono054No6M7Rt7ehvR8n6H4N/+d/9QpyO62koXTg58F92FGSGare3SCqT8H39Iokuzn+zmaaR8ivj86TqSZZQO6S1PxL4ZHRwy+KV3nMOCGCqavYz5EODNPtbftto4hfMjyxYE9B3ucLiFKHZ0J4Q4fL7xVQeu3xvCq3M8B6sNkhAozVtbXzo+BmBczhzqLZokQC9n2XLWkJdIQlTlwRcJoxNNg2jZT1bGTzUNQG3vd7jYvvhkPFb3uKWGs5ea7Aw","mac":"20+hh7Eqjks"}
@brianrockwell:matrix.shikpooshaan.ir	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	vWRYp1WXj+N89r+Rtpd/f+f0Qf8ULvh5BSOrFB9GMjw	1	0	0	f	{"ephemeral":"OWzrim5sLk9sTh9Bsn0KFuI53siBgGSiJrXrqR82bAM","ciphertext":"c7/2jH9bHHk2quFzrMvzjPjs4cGILSGFhT0TYCyyEZ0HdKer2PK75Vo1b9mWmbtpY5ASHeUUycY+SrPjNiOY3E7HCQ/8rG+Qm6vZHxCiILEiR+1yWSoMu3Tk11wo3KJ3iM+t4czG1kTbUMJ+qXdxNNYlVV1uHO1B5Xc9dUDbCm7xXESzv1AWdj9ENOUhlsabZJaE/MyjYC9PdhOO2oB8I17t69P9PvwCn0JGSdPUjKyjmyrXDHwLIRie23PTsDPCIkrR4UKnVxQtDiX/KlP+yuiBTUGMgHrdq8u7z7d2fE63Qsw9O/YskxedKVrtChqQrdLLXFvLcCzhuTwC81EY36u7xi/58/TBYyq6HvEgo9aSIxCdpLzWJoP/AIJAVCLIvwu6Bx9L2c4e4GvAmLigZWkU94DGadK4DMXR8IKbFbxq7VkEmXIl3lx8HfijMtyr5sL22lRKxxAkYgYl9TJ2G25FyiENcFQbkdgKzBMBFfufcEnSIcyVfOFmdB9uXd3dtIFroAN8npnvsQ5rIoCa3/fhankDIzzNXqJQ3U3mERY2lYlQrfJVCPbMty5UFQJVLCSxM1uxLDJ117z7RJDWVb0kv9ST06/xeoX6+LjFZygLPpWMgjoMtRcAXJ5mMMfL","mac":"zxBa7nFQ9aI"}
@ali:matrix.shikpooshaan.ir	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	Zb/DDBAInmrP5eELfi+I9Wk6/w708BumrPMSBy8L1cM	1	0	0	f	{"ciphertext":"dRE+lx+OKII60ENJUdR/HerJ022vNevLYewO/VLbCvrEwq2sv28mHLBunsy8YHgZDKCbXWkkggx87PpNscJPVd9iLGinngSReO/K/lPpre7+Oc+QAzuNMZ0TEdJk6sUFHmy1HXCl6bk3Vtw1OaAL/zkz0EZzTHvWnmWKgn0PK5UmlFDFBFDkGQ9/c0JAcra+PnYzJ9OL3vXK3Eujp2aWMopFD+inmSRWukP+g5NoLjG3xmaUizdkqdFWSSKPg5BheehbQe8nfyyHLNaK923UV/4B3gXfjpKotJMVk067olvSHegE2x5oqiEW3mGPkVxTY52D+Tt/Dy+6hm+B+GBpJOgMM4H+0ejjjFR1DuayqbF2V02o/RlWM2JFjaReZ5DykELtSkrVJSNHNyHnNr1LSZC4BskInUxy6hWLhHJa0I1/l5vIqpSPDpC86TOJp/hbeeektIakH2yH0M4H4r0SJ2Jx3LmnSJyTLmT9JuEDcv6yKbTJOkxU9sAjaE13X/ZddH4OxhqONi5WTy4gVPEGQTXSyp4yOHpMDoXgRv1TvFiSHXviYy0uZyiBrCA1Ds9uuTXZAwYAVir7hucq6D9z/VAYlOlqqn6o5Uni2H57hK20GZf7Ji3nOnesRkWVlJnv","ephemeral":"PVbl288/me6Dx9B5kcZZ3esHO8AXr7flUnaKcVpwGSQ","mac":"xvtHE7dM0OU"}
@ali:matrix.shikpooshaan.ir	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	vWRYp1WXj+N89r+Rtpd/f+f0Qf8ULvh5BSOrFB9GMjw	1	0	0	f	{"ciphertext":"Dy20zhB1NHI1lEL7m91JxhlcIMKgKjRtoFUhJhn2j5U4fcM6YK8Ur+9V8TuGijHJhJ5IQFs1iZGwcFODdXqHy1/LwZlTZONL/sNfy4hms266PkMZHapQ36JIZMgTXxX+FRsD3l1HHkB8s0ePugBp1rLLlyZpsITEd6t0tdQfTsE1zO93B0cFKnbMWlsRdoEkx54OZFej9xICkJ1DXI+RBQNin0oFWDpylC8Q/I6eWT9CLZNae7+gofgq9KSqJh7tT71WLxVb3K6cyIfhQKcubPJW0OcK4hSN8na8OnyxJ7pUFoGR/zz4UdDCioPh5OklyI8FUjFN8qlbXwlUZ6gVSIS+ZwuDLkW419zbgDlRDGrgRktjZQwsANrvU5akD0Z0e6/9VTQ20RKdI6t/1FNyF+qqGHztNdLKUG6prFjBYw4t+PaAMHh5sVmtXkTifpg5+BGP32GcFQy5EYjxHMXDNihcgCh3C1q+HkVQE8VPdyT1LYskLYaIZpZiRCpf3eGj/BdMLRFp0OA6Poq8KbMyo+3M9jtdSIi782aJuIoqhmjK9el3HgJNy7RSCSAxq0XAdNR1RZGY4OGPBNUfF0Cc1WpcAfyC+1IebI+wmgQ1lw/sgh0O8rrtbSdi4O+ylxW3","ephemeral":"panjvbu2SV9M6Rt1iFA2anWZfzAii9dpv/gA9Xm8Fhw","mac":"mnE4iPDRqno"}
@alex-taylor:matrix.shikpooshaan.ir	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	4q0hpaOVi+zaa34pNBtOm+GwYOLf5xjhGkuPZO9UQwo	2	0	0	f	{"ephemeral":"W29criocbXlq2A/uifzw1i0CNbqcJS5IAovOwPxZWm8","ciphertext":"iaLEVC2sxXCflWMyddlo30Hj4dbPWfP7iMGr9a5lyfULVlSQIjh6ARxUop1KkBEuGgv3vXLM+nzbAyym7SPTgeg32+pDRSQNhrSolkTM86KX5j6t3W5nUMNAe0VF/pYlz6VBOR2KtukLVZXZP96rGS5sgZMkILg/QR9vbIEGRqDjtNbKby+uo2dRS0zLbEVP2ILdYRuSpolhpP3OwushmK9zehEMhmH5vQwhw/Gzx6mNzWsHDImEkjugIvyFwtm/YAdu4goiTMe5imFrCCjrCszJOnYiOBmcA1uQDTAwMWzIz6yt+VUpgPClz33BcnIvuLzzbN8oExGLsTTMt8vWNr7NfMPU8tGE+9stAS/g0r6RmSRpAUvgset0oikul3GpjIIQx2dA7y9Fnt/Tip0vngXgtJKbiga9l9peJJhIgHfLrGGAwhuUaJl4EARZA5n3QW5UxjSxp0ZLE6/fsNL+DOJ8+le+0+w9qPnXdPBjnOH0zUO0s3s+O/EJm1nxGTohcppbs/Zs4OO9jA/pcOPd5h7VwdxXdafMFRvNVJ6gcnLfOmSCe/uoR8IG9MKb5X7+gCnU0g2IHeSlyc3NDmZjjvdyguM+QMAV9ujG8jXzV7D5LWT/rnUZvc5z2sMP/FO5","mac":"6ITYH4Qv6sA"}
@alipaz:matrix.shikpooshaan.ir	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	4q0hpaOVi+zaa34pNBtOm+GwYOLf5xjhGkuPZO9UQwo	1	0	0	f	{"ciphertext":"lVn1xNr4KcLKTKwIdUyyUrcSS5rpOQ7s0SgnTCVCMN8rPfGnbhyKTu+bl/pWEDQwm8E3CalVZZgLQvfz+125Th8oyR0tqttiEdxCfmVTQjs8k241xdmH0HNc8kgNTudaG5qWwU2TBKkM7J0ATuzIv7NqaWSN4b1gGVl4KF9gsKJiv3MEWjeg7wLkgMRoN9uSkmbywnPoWg9U5V20IB3+DiOAVR7WEntyGk63yAGoh+PrIYMHUJ3rMGr+AngsHZcIUOIsKkFf6+4q1DXsSNbcOZdNlG7W7dutPQNv1uhxC4krjVOq2ACzX4TsygDQsU06Vh8YVFFuNUKCvH6NJzd5AzURAKm8xK+bv6T8Tb6+HyuOq1HmN75ujMcluB/dT7pz7UbQG40bJUUekqdl6w8AdQ2JW3pWOEI1GFzz42dnQHVaqy3efwO2/e61JxAK/NNtn1BWi/kP06qjHUSnyrfuXrilHZtLpiO1pkn3kz+QHeYxmyuu0rrNmVpDhlLeOt2Z683Qvkwt5uLyjR9eprW7IT2cWFEW8bYL930Gwww2jMEp7HO0h1N9yf6KBxNiXrwYJOZdkGwnOwEAekzdbzqHM9x5DBYfuW1zuDU/XVQEHJ7KZ5ja3jb/4DkM4sWcG6PI","ephemeral":"Gq/M8ORYo4b7x2g94gcMSlN28PJPERB1k/KtzBmC9Qo","mac":"Msa6NJSUpFY"}
@alex-taylor:matrix.shikpooshaan.ir	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	L1YLj/45zaFTl8Au9b4uXWsp1q8J+0hZj7GWa+xiulc	2	0	0	f	{"ephemeral":"kMTGG3RArXPWG6iCMOUI3H4WZgDTgMb8fSliG1MhejU","ciphertext":"gXpP49lgIVwJLf19RapKRyc+Fa6hsVPghnnOLxG+0VbUl6aYRRVx4FwOcmHYOqpA4WhVNwUGfsjgDT6qE+QCLVI9aLG+g0CF7epyqFXsPB/Hj6kgnjkFCO3jvenaMYVPnU8hdoY8vnM7ivMoFkBDcBiT/UYmZJQnpZwDefbNWZj0kL40N+pvSHy2Erh6cGoCEUv1CL6vWq8bomfAnJxejJGg72wsc7qYy2HxUZerJqGFIdQGAYiXeNYtj78N1yBo/6/Ae5mIsSgsrb/MGNa+IOmoGEmshWcB9GtZxv1oZvNC11xw7qIVILheElZtjXWoSbLTCv5mMf74hKPUq+nhTOE6DvAo2YIUNFYRoX9ZwxwHXBkizGHCDn5dBvM0HGpeNktJ3rntp6WvEqtDY0N31dcBrLC3ZW/3a8K+4YTkcQtrYzurU//3tRfHNDc8WMAm6JtcKf/vblyorBt+aXSoG4190hRtiW7K/CaCfz0JZhtXC0waRl9ZRXLiyEaCzxOQY8fgoeydwfQhj60x42Oct+8Qs2sv5qpHy02qgGBDZUSuly49+pZyyLwvVdSWp0PncmS8mRDFg/fe9TQjizudIN1vt8KXxUYxkyno2RcGLhOQavH3mrCPCRCg43evUdEA","mac":"rO1+ZuEP9tw"}
@alextaylor98:matrix.shikpooshaan.ir	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	G/7rbkp/q1FQo7EHM+ghVl8dMKjTlfDlzdvKE7FX5ms	2	0	0	f	{"ephemeral":"ZUBsFbHrbq8dlVBrHu2XfGMYjZ+S0R6pRWqw2m8NBzk","ciphertext":"oZQZPMkUwGjx9L1deENcMKs45sUG2SPFYtDOgbU4wVqBycUZBoqK54MrPWx/Nh1RiC933px5G3OAqPnVHCoW7EusfK4wh52o2HsD36O7bOlTthS8skIanuRp5/g7xMT7aL4rwLahcwRGUUCxZOiTxrdDF4ClquAkF6YaD+V7Hk4i2D9jtlmTgjt17FawTLAKnFFEAINr40VsNHF8IWprOamqudXYIBfeWOokVcqmHWEss/hY510sQAD0XvQnBP8KhDvXNxfkYAy2tmcHi+gbVJ/CaStvK8jEH+ZNvfjNaAyN7iErzar3sG3uKJMLuJTgCX9bf0nkwSr3JC2mycRlT8RnOTAb8nKubJdjbiDVrGU52LUIeX28W0ECjM/4AIitT5QqvJmfdEnVdfBBN25dEn8t53eOcUFEy2qZULcWXLEtF4VDLxSrH8VCeQXONPrFvUD5l/UCo/Syha7XTIYmsDgGuBxpKgWA9nAFiGFUFDeORLxQRX2vPPHCGI49q/f2lAGXlHB/EG+NLoWMGrOqHhimBv0J8CeFfH86CaGbG6sZ4aLw0kKW5h3CSnsPFqK5hRfXJjm5vkV9EXdsWQZG5gCEbRiTrV1I7MGEjt/4vWdy2boLvkGcxZ9K4+ejNG3r","mac":"KuFk/nt6FKo"}
@alex-taylor:matrix.shikpooshaan.ir	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	IaIyZp/8K6Q2w5b7ZgXg6IXm7Q8GDWgb4BmUlpNp7Is	2	0	0	f	{"ephemeral":"zwMlZ74guK33dKwg+ndcC9QPWI+eKmP5Ibz3Oo7mcDM","ciphertext":"tyQ7eax+OpWAiQjOy13BEuvqkFARW/aTTKx2ZRJIZwHxR8xIuX5kCyi6O1tECionsP76xil/4lMIMcGOm5eLw7W9/jfNINsAfB4iyO/v4d77yCej0JI9RK84BWHxHujcQXzaxxaXcEAN9J0GkM/ohrgR3iWJljoja8W1WsY1j/hL3LzFnRXYVB6EYT1fPzymou9RYTDQirL5jTcEpyTcFPSs/tsleVjGtwurO2KjuJMhzmdfbhiFN6iN0tKKLbWofGojEIJtvN5uV4Cnz8sq+tdavGoqL98RCIYDj/Yjhak+NZqNIbGoRwttpG5+B1LbwbV81DLpnE/PlvryQcXeMewJGSf4sOUJ1FR+IQIjMVM5AwcGaftAESeQeIC5b97nej3Om0QXWA9vM9PkMIZeI6jIFkbPQZJH3PRYgZOlGx+ANno18rr08PdxsoaU2RpGaNjdVEUlB1MF76JYfoaFh3pcQaytELjovbV/GB4VxGsE7rzdaFFdThswX6ra91db6LG2ljlscN8aZXlkp5xxxj5CSvqL6XQEGKx2qxtf7yDues40uikyOXgqzE3jvjyUbI163uEVFQQmmvoTpoEhRJVdHjWMwQhAI8970d7mQ0aYk7OU0nwAPq04Xwa+j08B","mac":"pqCYzKX4PG4"}
@alextaylor98:matrix.shikpooshaan.ir	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	IaIyZp/8K6Q2w5b7ZgXg6IXm7Q8GDWgb4BmUlpNp7Is	2	0	0	f	{"ephemeral":"iPQEnwQ38rO+lG25BN9mFws0qqIDKL5PObIf2U/+Yj0","ciphertext":"Rk7Ki5YYCZ14ouaKf8WSWmiJ45/G4+q86kgdIFr0C1hTJUMGWLJzj8XaEE9rBhdcwmJPtje0ksgxwjwnZx65sAuAS7Jmz5DDnnfMcdtQyghbkE8/0iIG+jh9LiBXsXiFwcSZDooroS68Xuoe0eIOvFhcVkfd0SpcZ8ZbeWMLZIjGnYUhwWjqEgM7/cltDaEEIOEImk9KFcUHtEjMJYIF4SCoiKF5ZapZbty7qI2gJDDtVf5+3B+YM+LW2muhn3g9y/PiFdbUH8qHhCAT/4v2OG/BMbKblcrCCijy1zj6P48r+vSOfMLd1O2f5j426FcE49LhD0r9SJgPRfzgFtLxv5XFOBK1m0Zve2gbaFrArOmcgmDr/+VqNuso1Qm41vNnIeUREyv4cv+FmnklFUyRkGAEvW5kMQ6QTgNi1BtvvLEjVuoOBmcWZmZG2TL+eJcOsoOJZ/ZtJI8HOZJZbAvihnr2rvgNPeXHFJAVI/Wf1f7zKL6e0GyNFRPPwsxznYqxUNgksbzsFLn1UcLhF1xmn7vL1WHLQosWN0KiS9zcTY5MhxCihwoGdKbKT4jNPWDN7n8xpIkxFmeEmwjuitZKZGPYGqiwUY9ndNNeaMEQgMANZYEyiqPkFK4YHWCzjuNF","mac":"sEi0uEzz/uE"}
@alextaylor98:matrix.shikpooshaan.ir	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	L1YLj/45zaFTl8Au9b4uXWsp1q8J+0hZj7GWa+xiulc	2	0	0	f	{"ephemeral":"qGv5+9hQNO/LkIY/en82qRN4SwE3iywh2c76F0L5kkc","ciphertext":"/sPgHealVPJMm9RPtvPqv5z6pnEnmLfCHf/sPsR0TIfxi3a3y7wRnfF6TrvKo1ZkkIqd/MxfNrWaIJLw7UyWKecALlDffs66NFPYcS1di3HUrJvIBdT207NxPdCO0wm863rAKT6rGsFqXZMdtOYH6DgmtmTGK0OKLVEEqqVRPFqhEfLjGrVUU51h29YM1ifqmf3Yiyc/3mZmrI5YLNsdHf7+KnApSlblnzcnFT92jV/Z706kkps/wlyLPUk5LWw4ifrwpVtTcdHV3uNXb+IXroUWZk4PLXTjK+6xqPA1YfTrdQohV2H4jPsXwYw/HQ7YhbAUQaj4ZmMeO9fJ5arRMPCjT1wb3AcqjlXizPQHIhIreHIw+tuqpGVXE+rUrOE6kdxvjNpZoueIN0xwYRx/w3Bpi55MilQ2w9NCrz3ZN7XlzyQhQI05JlXFHlv4zg93ruAeOVWwgjXqJ6w6Uz9/Yrabwen1sJ3KjW5/bUoPLeSpEOZlopD4WQfgLlRhyfM02tzpUBcKgIIpjZHbPRneP9DatbRgcaR0p0YRhrYL/DcDiD5ZfMuFw+FO2vi2JgYnBAooTlz5dN2fqXtoM/srFIzdaxWY0GpiEN2O9ZcgYQlVkp2wVnOpc5uVK+QIxNLY","mac":"BcAlCq++e20"}
@brian:matrix.shikpooshaan.ir	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	yAyQ21rcBzLXk5D5369WGOm7T5fvyYkjCI/KwyFdjqo	1	0	0	f	{"ephemeral":"Zb+tpLomKPnLOc+iTFZzfqnsGuOs7zwqpanr/NPunDs","ciphertext":"Mc5TRshwicDmUOHrBcb3pAq1/11xjnxlA6NqJp8w3dFjKEl66rfL/tPiXoJg2ZRWDYVPFmQtH18eWohqXZlLNlK5t0PUUfcQhQc19k7E5vTDsn9aJN7WcjQwXpTciy9n3NJFeem2l3QgoPCK2Hpx8vlPIGCllEmRw1IYQMspOwR5b8qnYQwlYvd2KuWrkP306oQP7NJQmTOosyvFIBoNb4JKgYDTH9DCwwqXCI8gg74d3obFCcJQ/+rmPcrktymUQtdv+hsLBjhaj7t8b7wzhPBx5AYvbbkA3OO7Zb1l5vbRFIlySVW2IhrThud0eCd53fbyQL1eBMFQa93iKIFDMRP5sE+qb4z98Io0+bEyWsoYj85kE0G7oMLr5dIdXnaXDsYdJxoF6V1yUzyROFusTj7CtK9EmM/zqX3TzJmY9VHE7NXzucz9zF6h4T3D7496RdSjjsaNxYkrkZD7LcxHL62tXc5RX7pa64DdZBdhBmHDpEPAP43/WYm6NOLFGcQsP5WS7atdgjefHaZ6D9sFhCwU17misALjEuDdFXyu778c63Pecofxb846ngENARxx1qY6006xRO647XzpHDQnYmsOuuJJgoID5zDiJWbOnLEl4dXtpyYCaxsFzuWx5jSC","mac":"mP+W4ut02HI"}
@brian:matrix.shikpooshaan.ir	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	G/7rbkp/q1FQo7EHM+ghVl8dMKjTlfDlzdvKE7FX5ms	1	0	0	f	{"ephemeral":"cKlIGYtKBYBax/K8BkxoFGvyYUq2huvQoUXuPQXTkGU","ciphertext":"cm+P5RtJZ1ZZB/eZnARXIYnf51iBStdy2BxxITu3PMMaKuPFqakn4D+F+vJ9UBeQA1n2kPZk6GKIjE7vEXRljicV/6pG4YcwEkYWhE3+RG4rK2rFkRQVEIO0hCvYFfzoYTOcklW5Lfb4ySxqFORPowib8EP+tJQYHYWr+GMX76P6EcpyTFBVexqWIIJwVrS+y4hn9reTKmdacYHJXOZKETYQtuqvQBkH4qDgS1v7kCnGknjv6Qp8nDHzgS6X6lvUe8vZZZp8pQXQKRb9MYchiu8WOtYM+YgthJUq/ZuSs16i9h5wFyFyBHu8cQxEsqe9THEqjRIyhVpdgQU20N2t9KTv3qIzTOozY1gM5tYIyIHuJ79gvrK/o2dZJG7E6wTeyneWGLruqGnQAOKdV67lpQJw4L4C/yuSzdRLrCfW891PoDvrLf7Alw0Xfxs1TRr5mgnsR72ccFSRIl0oLIVo6ORE8jG+HXd/PhnRHflBKJC1EuvkxPTtlMAHgc70q7ljocwBIhoaM3rgbGbM9ATFdo6BxoAXs/KNDfcadyxGfkXYbP7679Ga7J3ADl+8txpeQegJUgsJjtLKj+fKd7jOcxy8rHbe5UdC1uOE8VOGNyYn1M2dTrmS+GgF0dJtxuLN","mac":"6efbWdslaow"}
@brian:matrix.shikpooshaan.ir	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	7vhvzni8iU4fwPub9cwbMJFZHa6uM85wWQR1RSJkZKA	1	0	0	f	{"ephemeral":"1wmyl5YrUinwwAxCeFjA2aPdrWKe51SWsuGj/uwOpz4","ciphertext":"AgMK+GvxlYm/aMkyExn7sxBNkgUU6wtTz47cFwAdCAizUPcfazUWdR7UwE62MrxfnDRQ+NrL9oS5PYRq1yZuA0f00UyNl4VNSW3GQW2oj3k40/p1ZY3UqqDr4r8QoOvw47ioWppkaH+OsXBRT6EpjFsiZMj7qqi8UJc9E8Iwts+pbkWI7YIdxefnuN6ocMLwFDjS4je/7c0XHbfp8TiCOSbos96acaA2ear9jFxo6c3ltDVNfVOe8XALMegc9oH/XIVHszyftc1RWPhdcK+zVDsJ9Wp7DWGt8V8Kk9Vkfb5gtMXFU4kIaCJil2O7MrAePgCcSAQKA3uP2jBpy3VdOea8m8BcL/XMmjp0T3rGepn3RlMptvdkp4NOfWljAUUHVItIGmwM1pOAnNL9pNnbUbROEgEuHIPYjp1oS2R3TklwM/zLBTM+unUJrLHJW5Ow7SEC8k9rHejj4CKbj3Tf1hFi2o+yiuOOev6EnfFV9tvHRIMhdq0wUYqA9WWcgD1rU8nRLlMNrTW/QK9fcnFQvKOEIDAP2ayAQsQ+XJYXoTlLKyAIfuvktJ//XlokrDAoQAbSBUPPcmnCUXjG/XXfvpgkgSe8nD1c9LJn5qsgmd4IMWWlTjCAEy5S4hRSB2+h","mac":"ObevPrV7i9E"}
@alextaylor98:matrix.shikpooshaan.ir	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	7vhvzni8iU4fwPub9cwbMJFZHa6uM85wWQR1RSJkZKA	2	0	0	f	{"ephemeral":"a2/8EbYppGp1Q/r/QCT6r4QPKjyeDtVAVdnWNBehlU0","ciphertext":"rbALnRn918BJVKep7eqJ8+GRgk9fXnvfS3c8PcG6K3KK2XSljKHz/QIuNF78N6E22RG242uDfd3Y7vC5twT1i2r7q7CxrG4glPw2gih/ksXzY9nfMuQjUAXb/3gYjNnPDLR/XYa94lkE3heiAJn3sysZt70YYC08HsLOLI+EtPpkxNq97niPJRlyKlVP3NVGlWRVZyhqA5Jt3nLOJMFmaoVY9CQIUSSee5WBgb3CwjpgsBJHbXXCI0GTk2qd8xYbR4Xs1MsZGVoekGN6bOa0KpCIyMidab989jrCIsiOmbx5MdQXCHa0rcyzkseYDjxSEdxV6tHDg76byRPQRrQj4cBT+9R6lBBcdbhiDJG1UPE6dK9wFZgB7Z40qc9XjwnZ2mDWAjItkfSMRmIetG2XIjMC2NXLkj0COL5hxpf+bSpCl/0Q7wUN/YcilYp2TXyNiAOWt4EqIiVp0GmCN+OLF7oqF2sLRkKM7G/B3hqxSdsGYwbTsDt0p2gyAkhOzZhRDFHtQErc95Wh+cXUmhlTZ2xEg4hQVDIZgutaZzNHFuwZJ1jC09etCdmcUAD/Rl2e47pFt59+D8xUiz3C4LWfq7jyyr21UOB1S/jUYR9QELf86n3+hfYFL8hoxGK0NMjL","mac":"7Who5zXI9n8"}
@alextaylor98:matrix.shikpooshaan.ir	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	yAyQ21rcBzLXk5D5369WGOm7T5fvyYkjCI/KwyFdjqo	2	0	0	f	{"ephemeral":"JOHDQjFlOX1YhknNdxXb62LtMHMi8Leumxxf7uW7g00","ciphertext":"lwkMrpIn9q7xFAxRlLvz0fsk6KTvv5YcePD/l02mCo7dkhBUvIC/zOL+yVTP7ydRgXenVOo82I4S/VlP+O+UGvx87EWR8tAFTvDHxmyn7l9vInULPhti4BlnoMZE1mABN7sy4qmz+pxifCYiZo9F6L4+sM648r/Hd4b25Jrg4PA5QTDnP+zcWBvFqS7oFj+Sqy5Iq/VGjPqh5im4NY/o//1EkZQgROX8it2PnZ0zt/ssOxdh54jnvz3AuT8ECF0lnSQnPR8A7jmB7ZTsUCPGH+RR/xIK/4f8FH4AFDVx0THzT6V8dqqC2MJVNHOwhgKnkeWxOb4xF3f9gKBG5FwCaX9hcbR5EQlj2gt4w1ksNQ0TBnL18PrKglheY3IKqptCht2I2geze7ilrt3vZmI9FqUTlxjWvAdI1pHzyXdD4/R2kK2eL6EOR/sy1xjMwpVPHkDbPrr8JzgChfGjrzW6TC4ydzREeqNCrpS4fY1w5+8SRchx6Er7WrtQ9AaIz41ZIoHGJBpnZQmkFtKqfaW8++XPjHWd4mpdnWW0MlK0riwpBNHdb5NDuvTMH5R7F7/ufNrECeiLcavXfP39Ct3oj7YWkf3PQb+9s/8RRJxo8rUv9foyJ5lRjzSuhUUJxOcN","mac":"22zJ07GZKbs"}
\.


--
-- Data for Name: e2e_room_keys_versions; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.e2e_room_keys_versions (user_id, version, algorithm, auth_data, deleted, etag) FROM stdin;
@alex-taylor:matrix.shikpooshaan.ir	2	m.megolm_backup.v1.curve25519-aes-sha2	{"public_key":"YSPN9b6fKryiN4bIIxoPtJFLWgcrytRpiEuDvDkE0RQ","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:9rBlDG6qTbTubxNp3++LEV1m/Z4nww7OA8SMeIJzRkk":"qXE/zkOaSlTaoKkI+JX63VlPsT6BLt7GQHEYtt9ZrtwmdBWczSU+HRMLqllizF4cdhohNg+fFvd04rINgr7QBg","ed25519:OFUSOVXTZJ":"z4ePKrL1ty8WU/flAz9E+DnauxCBmD8/aVdWc2aceJjclTLGA9PRxUFyxi8Ute4SYkmq316UmddYLTMTDKTSBw"}}}	0	3
@brianrockwell:matrix.shikpooshaan.ir	1	m.megolm_backup.v1.curve25519-aes-sha2	{"public_key":"fwijXV2iKNn3RFuqJW5auZ6YUxOIovZo81UVnX73u34","signatures":{"@brianrockwell:matrix.shikpooshaan.ir":{"ed25519:KYQHVGSULI":"ZCFYrDJc6P+j9MHzPkXmyp63nVRuXQHTlIMHbkdRlMYveNFIuScxQkiNKcodd9ZyD55R/8KLQI97fRqo7QwxAA","ed25519:w63RBZ0TOEnArMjlVYeB4pYUFbA0U3uX5/2bKizFQFM":"56tLsncgQAw1tUB+95xA+lTq4JiPe9A/rkaedJlk+wPnT3YIhHeAzOQ2IEaWEc82Oz9a8esZplnvrMcIArAGAQ"}}}	0	2
@ali:matrix.shikpooshaan.ir	1	m.megolm_backup.v1.curve25519-aes-sha2	{"public_key":"gJd5wyt8Y/S54FdkAJVg8nF+pO4Rb8oEwyqx4PJPBGw","signatures":{"@ali:matrix.shikpooshaan.ir":{"ed25519:5+ArUwizcScHeHQxyQqSnvma0Ul/IdEcsjbP8C+BAfs":"egNzjhCQbGJFE/KGsGb3RHzoZ4cztXyz4gXxslzz6BKF1lLQ7iLz0D+1iK8e86cY5wneITzBr7e8sekUjfAxAg","ed25519:WGYBGBWZQI":"w2Xm2ETgjGy71tltoy59Z/yXdr0k2k2gHUXz6oP7p8Sy5DW8kv21O3Ydadrkc/ju+K4wAx0MQ7qogfMfMa42Bg"}}}	0	2
@alex-taylor:matrix.shikpooshaan.ir	1	m.megolm_backup.v1.curve25519-aes-sha2	{"public_key":"RS++VwW+VH18qhSdhKjyFOYNmJBJBMsp/sUOtbtv6RQ","signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:HPQGRDHEVK":"W3+EexVIFDqYJpLhovCUB/hSW2lm5fgdQlfthVAzcVor/fZeN19UxflNT2Ve26gtamUsnxy7ztH2isyZZEZ8AA","ed25519:Mw70aYuCoCmYXLZ2UKd4oI3PRHgs+++SO6XA55t02E8":"qk39cnP7lHA7U+AP31GfuU0xN39Sovj6epxtXkKRg+KqSGQ0/GOztAgItSdSVgH0XkaklkmVzVOU16saKtcWDw"}}}	1	\N
@alipaz:matrix.shikpooshaan.ir	1	m.megolm_backup.v1.curve25519-aes-sha2	{"public_key":"rdVkG50nm6AE07eu486CEbFFlRzDnvLsqvniJkPwIGE","signatures":{"@alipaz:matrix.shikpooshaan.ir":{"ed25519:Dk409XoilPTlLlWveqoUgBEPII6npHC1C657tmHP2VQ":"alCHcvW35MP/oGprwuhuPECO+pw5AtcCkWQ83Kz96NeVEltoM+WfUhb6CPJpDMUZO4rNJTB0vg4/9oRNFycTAg","ed25519:SPEPVPSHPR":"j36FFXvCkVfNhwOS4G/uDX+53BiMCM9iOEUI9SJIes3JO1Yw9LGC/WZOlctVyL4sxJ33Q0/RCd217MMl2yZBDw"}}}	0	1
@monir:matrix.shikpooshaan.ir	1	m.megolm_backup.v1.curve25519-aes-sha2	{"public_key":"UivJH3HWPbTUiaa5SOA6U1VEjxEsa57usxGjL1qa+UA","signatures":{"@monir:matrix.shikpooshaan.ir":{"ed25519:Hy/5/dagWfQI6psqnjJrzeYpLs7/t/EIynf3tYQeocE":"jpzrROUm/PFH+I5CR40QBgOmbA1AlDbMzmhvlNT3QDu/hIJ2V6fMojDu+1cRF9EDFcELH39fhzx2ZjEw/XX8AA","ed25519:WGFMZTWZEK":"WYHnWn9zFIy6OeHpWjK7v0+Lpu/cfjcLKd6lKkVlhDbGdmu09yi09CN1e56VFb5hGzvrT2mKcokJdXiFxCz7DQ"}}}	0	\N
@alextaylor98:matrix.shikpooshaan.ir	2	m.megolm_backup.v1.curve25519-aes-sha2	{"public_key":"VGAZsqfYK299riGkxn5njPuTMjJOCGYtGIwG/joFTBI","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"PSDGXyd0TDcuJ0XEpCQou2AE7gG4bhBi7nJ8vt9YxNPZaD8YMCuZCZ6cebb16G2huRJDGmGFTB07/jhAFbdXBQ","ed25519:a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY":"FREk/8w/kGF52Kwg5lBEvoyMlzcG+hHC9H8eoFZy30ZIeHnIgSz2BLRXdlyeQcp/ZbsCerzJYk8+i6aZqCydDw"}}}	0	3
@alextaylor98:matrix.shikpooshaan.ir	1	m.megolm_backup.v1.curve25519-aes-sha2	{"public_key":"9IPloujYReAY7Tcw4abRHDAsBSA1GUMhHk9oXr7PW2I","signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:ATHMCRr8Wd/Gvx8HUYoSHZZzjqWdwjSl8IbWwoVaQrE":"sqHVnOaMce29For0BDICX3a9oyTkGD7AlSgT+FjW2swbOiKgxQdoCMEmduJ/n+HPmzd44O0l44ayGq8BFiOmAg","ed25519:NFLNJMUACW":"wLhsDu90WNVAqsWMjMV9uZtxwZoWGqLk1z9VTYl6T43Qnyryp2ClTJgxFrsQfbutv+QGgfz5sNKHoVHG651JBg"}}}	1	2
@brian:matrix.shikpooshaan.ir	1	m.megolm_backup.v1.curve25519-aes-sha2	{"public_key":"PCLdJ24H2EOsABZERL4METYl0chR0hB3lMXlx4AhpiI","signatures":{"@brian:matrix.shikpooshaan.ir":{"ed25519:YOCYFXUGYQ":"M5WQy2BvcoWfkecJC6qhO1cWZDWUH0hAv2sgs1TpnjUaSCiw7QN2RAL6WSK4ncvxS1CmtNzF7dh3IOusfWktCQ","ed25519:ee2Crc4cHA1rBL7A1enR4V+p3l6vvHFLTajf01Afkmg":"+o3AtgW1H8lUsOW6iIAAcfh/5gEoH76uV9lOTvcQwgv87Y/6/0IsXwNKnhJ0Iavn5ypsYDJNJKll0RTkkc4LBA"}}}	0	3
\.


--
-- Data for Name: erased_users; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.erased_users (user_id) FROM stdin;
\.


--
-- Data for Name: event_auth; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_auth (event_id, auth_id, room_id) FROM stdin;
$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag	$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4	$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4	$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00	$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00	$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00	$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$prihY7_PFyGlMWv4ENxfD2iizqJyMNoQbig1eNbs7UY	$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$prihY7_PFyGlMWv4ENxfD2iizqJyMNoQbig1eNbs7UY	$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$prihY7_PFyGlMWv4ENxfD2iizqJyMNoQbig1eNbs7UY	$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$A960r4luhjM4-N8ZlQT_oZvugpHLDMyoL7N8LsvnnlI	$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$A960r4luhjM4-N8ZlQT_oZvugpHLDMyoL7N8LsvnnlI	$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$A960r4luhjM4-N8ZlQT_oZvugpHLDMyoL7N8LsvnnlI	$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$-Yvs0xYmtCB-d_v2Z7zGwQj8jvY11ZDzzMQaPKj3DHw	$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$-Yvs0xYmtCB-d_v2Z7zGwQj8jvY11ZDzzMQaPKj3DHw	$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$-Yvs0xYmtCB-d_v2Z7zGwQj8jvY11ZDzzMQaPKj3DHw	$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA	$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA	$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA	$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA	$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI	$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI	$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI	$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI	$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU	$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU	$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU	$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY	$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M	$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M	$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M	$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$pR2OnVDcJjiIYWrhS9nEoocIiQESVvpdsQfYu64Jhp4	$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$pR2OnVDcJjiIYWrhS9nEoocIiQESVvpdsQfYu64Jhp4	$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$pR2OnVDcJjiIYWrhS9nEoocIiQESVvpdsQfYu64Jhp4	$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$uPRJ79eQQkEtz9GsgfXr0y-f3JPTNkvLdecu65l13Eo	$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$uPRJ79eQQkEtz9GsgfXr0y-f3JPTNkvLdecu65l13Eo	$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$uPRJ79eQQkEtz9GsgfXr0y-f3JPTNkvLdecu65l13Eo	$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$h_Aewnb-d3kjnDHdRL1B_3KhQvXaRyb0xNw9N0ctEUM	$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$h_Aewnb-d3kjnDHdRL1B_3KhQvXaRyb0xNw9N0ctEUM	$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$h_Aewnb-d3kjnDHdRL1B_3KhQvXaRyb0xNw9N0ctEUM	$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU	$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU	$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU	$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU	$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg	$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg	$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg	$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg	$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM	$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM	$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0	$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0	$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0	$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$VWhXTrJ895IdYCilHYuIInhbeUE8rsIzTWUjb7gSL1M	$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$VWhXTrJ895IdYCilHYuIInhbeUE8rsIzTWUjb7gSL1M	$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$VWhXTrJ895IdYCilHYuIInhbeUE8rsIzTWUjb7gSL1M	$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$egxiNGcQc850qQa01Ox8mP5yoEj1Q5Ex-bzUWtN4W5c	$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$egxiNGcQc850qQa01Ox8mP5yoEj1Q5Ex-bzUWtN4W5c	$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$egxiNGcQc850qQa01Ox8mP5yoEj1Q5Ex-bzUWtN4W5c	$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$JrVCAJ9f2DtGYEV120F1HrAvVIjWumvsdBmenypJvNY	$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$JrVCAJ9f2DtGYEV120F1HrAvVIjWumvsdBmenypJvNY	$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$JrVCAJ9f2DtGYEV120F1HrAvVIjWumvsdBmenypJvNY	$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I	$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I	$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I	$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I	$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg	$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg	$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg	$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg	$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY	$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI	$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI	$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI	$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$14g0e4tQc-4i_Vdo1U2pNGwl-QbxmmrnRRA2DOZjnYs	$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$14g0e4tQc-4i_Vdo1U2pNGwl-QbxmmrnRRA2DOZjnYs	$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$14g0e4tQc-4i_Vdo1U2pNGwl-QbxmmrnRRA2DOZjnYs	$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$_VnHK-C5uJEI_LtZ6Edmfv4J6T35_tYN-Em2qO-sRyU	$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$_VnHK-C5uJEI_LtZ6Edmfv4J6T35_tYN-Em2qO-sRyU	$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$_VnHK-C5uJEI_LtZ6Edmfv4J6T35_tYN-Em2qO-sRyU	$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$NFsUH4yHF1VWTTF3R7erS73-88ifZ3r1Lk1lrp7s5rI	$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$NFsUH4yHF1VWTTF3R7erS73-88ifZ3r1Lk1lrp7s5rI	$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$NFsUH4yHF1VWTTF3R7erS73-88ifZ3r1Lk1lrp7s5rI	$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA	$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA	$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA	$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA	$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA	$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA	$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA	$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA	$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE	$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE	$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE	$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$Z2e6JO81o3A3wHKKBJSTB-q68xOeUakOBJi-6H0er2I	$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$Z2e6JO81o3A3wHKKBJSTB-q68xOeUakOBJi-6H0er2I	$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$Z2e6JO81o3A3wHKKBJSTB-q68xOeUakOBJi-6H0er2I	$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$oUHPDjqakCWglPegHTY6TC8e_Qaqub-Yoh_XfUKTjjc	$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$oUHPDjqakCWglPegHTY6TC8e_Qaqub-Yoh_XfUKTjjc	$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$oUHPDjqakCWglPegHTY6TC8e_Qaqub-Yoh_XfUKTjjc	$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$ZaaKYiCE_n9AzqSGJntdPRcRM7BRhym69EHSrFwgdac	$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$ZaaKYiCE_n9AzqSGJntdPRcRM7BRhym69EHSrFwgdac	$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$ZaaKYiCE_n9AzqSGJntdPRcRM7BRhym69EHSrFwgdac	$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA	$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA	$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA	$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA	$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s	$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s	$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s	$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s	$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo	$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo	$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo	$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo	$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg	$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg	$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg	$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg	$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A	$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A	$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A	$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A	$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k	$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k	$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k	$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k	$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY	$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY	$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$ekFlSyfMDYeG34nr1qqB9Bi-AbjdiJ_J9bLNNsHuLKs	$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$ekFlSyfMDYeG34nr1qqB9Bi-AbjdiJ_J9bLNNsHuLKs	$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$ekFlSyfMDYeG34nr1qqB9Bi-AbjdiJ_J9bLNNsHuLKs	$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$zc8tOpOdwrt2LhO6ZIPa8Tv1PyclAu-E3cFNvQTB_rw	$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$zc8tOpOdwrt2LhO6ZIPa8Tv1PyclAu-E3cFNvQTB_rw	$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$zc8tOpOdwrt2LhO6ZIPa8Tv1PyclAu-E3cFNvQTB_rw	$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$KTjmV6JHWFiwg8JXvrYWGjeMxJtAvzZoRDulWpsNaSw	$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$KTjmV6JHWFiwg8JXvrYWGjeMxJtAvzZoRDulWpsNaSw	$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$KTjmV6JHWFiwg8JXvrYWGjeMxJtAvzZoRDulWpsNaSw	$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$Dc3jotNRZdjzDW_y7eg_fRWeyXs382gqm43HSX5lbOI	$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$Dc3jotNRZdjzDW_y7eg_fRWeyXs382gqm43HSX5lbOI	$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$Dc3jotNRZdjzDW_y7eg_fRWeyXs382gqm43HSX5lbOI	$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE	$ekFlSyfMDYeG34nr1qqB9Bi-AbjdiJ_J9bLNNsHuLKs	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE	$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE	$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE	$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo	$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo	$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw	$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw	$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw	$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$xRkldK4rXGoVy6SNEazvj_642j0z4vnhDKSsno94oMs	$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$xRkldK4rXGoVy6SNEazvj_642j0z4vnhDKSsno94oMs	$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$xRkldK4rXGoVy6SNEazvj_642j0z4vnhDKSsno94oMs	$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$RDmQ4EMxY-FgFox84X5UWejaA1ImHNYssM_nyAlLSbs	$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$RDmQ4EMxY-FgFox84X5UWejaA1ImHNYssM_nyAlLSbs	$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$RDmQ4EMxY-FgFox84X5UWejaA1ImHNYssM_nyAlLSbs	$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$YP8LBjVbUpZKdDbx8B7q46a8-CJwDp3EK1qyDJCSoio	$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$YP8LBjVbUpZKdDbx8B7q46a8-CJwDp3EK1qyDJCSoio	$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$YP8LBjVbUpZKdDbx8B7q46a8-CJwDp3EK1qyDJCSoio	$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg	$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg	$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg	$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg	$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY	$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY	$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY	$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY	$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk	$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk	$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk	$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk	$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk	$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk	$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk	$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk	$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is	$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is	$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is	$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is	$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$4X_PjJl7QiE3U7c8UuRUw5-rEt6S9u2f1fEzR5tiWso	$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$4X_PjJl7QiE3U7c8UuRUw5-rEt6S9u2f1fEzR5tiWso	$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$4X_PjJl7QiE3U7c8UuRUw5-rEt6S9u2f1fEzR5tiWso	$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk	$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk	$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ	$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ	$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ	$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$lzdi23BC1bOIDnNJnuoZzfFYBb3iv4PDZ1pw9Tg4z1M	$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$lzdi23BC1bOIDnNJnuoZzfFYBb3iv4PDZ1pw9Tg4z1M	$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$lzdi23BC1bOIDnNJnuoZzfFYBb3iv4PDZ1pw9Tg4z1M	$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$d-DLbKD_o_R1rzHrZD8hyXWTZsKArLYnNTv9_1HRatE	$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$d-DLbKD_o_R1rzHrZD8hyXWTZsKArLYnNTv9_1HRatE	$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$d-DLbKD_o_R1rzHrZD8hyXWTZsKArLYnNTv9_1HRatE	$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$6UQ-qIZULcBYRTpiEHtIjLH-lHfTx1ipANQeBo3ldw0	$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$6UQ-qIZULcBYRTpiEHtIjLH-lHfTx1ipANQeBo3ldw0	$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$6UQ-qIZULcBYRTpiEHtIjLH-lHfTx1ipANQeBo3ldw0	$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg	$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg	$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg	$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg	$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
\.


--
-- Data for Name: event_auth_chain_links; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_auth_chain_links (origin_chain_id, origin_sequence_number, target_chain_id, target_sequence_number) FROM stdin;
2	1	1	1
7	1	2	1
3	1	7	1
6	1	7	1
5	1	7	1
4	1	7	1
8	1	5	1
2	2	7	1
10	1	9	1
12	1	10	1
14	1	12	1
15	1	12	1
13	1	12	1
11	1	12	1
16	1	14	1
18	1	17	1
20	1	18	1
22	1	20	1
23	1	20	1
21	1	20	1
19	1	20	1
24	1	22	1
26	1	25	1
31	1	26	1
29	1	31	1
28	1	31	1
27	1	31	1
30	1	31	1
32	1	30	1
34	1	33	1
35	1	34	1
37	1	35	1
38	1	35	1
39	1	35	1
36	1	35	1
40	1	37	1
26	2	30	1
42	1	41	1
45	1	42	1
47	1	45	1
43	1	45	1
46	1	45	1
44	1	45	1
48	1	46	1
50	1	49	1
52	1	50	1
55	1	52	1
51	1	52	1
54	1	52	1
53	1	52	1
56	1	51	1
10	2	14	1
58	1	57	1
61	1	58	1
60	1	61	1
63	1	61	1
62	1	61	1
59	1	61	1
64	1	63	1
\.


--
-- Data for Name: event_auth_chain_to_calculate; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_auth_chain_to_calculate (event_id, room_id, type, state_key) FROM stdin;
\.


--
-- Data for Name: event_auth_chains; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_auth_chains (event_id, chain_id, sequence_number) FROM stdin;
$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE	1	1
$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag	2	1
$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4	7	1
$-Yvs0xYmtCB-d_v2Z7zGwQj8jvY11ZDzzMQaPKj3DHw	3	1
$A960r4luhjM4-N8ZlQT_oZvugpHLDMyoL7N8LsvnnlI	6	1
$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00	5	1
$prihY7_PFyGlMWv4ENxfD2iizqJyMNoQbig1eNbs7UY	4	1
$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA	8	1
$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI	8	2
$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU	2	2
$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU	9	1
$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY	10	1
$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	12	1
$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M	14	1
$h_Aewnb-d3kjnDHdRL1B_3KhQvXaRyb0xNw9N0ctEUM	15	1
$pR2OnVDcJjiIYWrhS9nEoocIiQESVvpdsQfYu64Jhp4	13	1
$uPRJ79eQQkEtz9GsgfXr0y-f3JPTNkvLdecu65l13Eo	11	1
$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU	16	1
$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg	16	2
$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY	17	1
$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	18	1
$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM	20	1
$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0	22	1
$JrVCAJ9f2DtGYEV120F1HrAvVIjWumvsdBmenypJvNY	23	1
$VWhXTrJ895IdYCilHYuIInhbeUE8rsIzTWUjb7gSL1M	21	1
$egxiNGcQc850qQa01Ox8mP5yoEj1Q5Ex-bzUWtN4W5c	19	1
$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I	24	1
$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg	24	2
$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg	25	1
$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY	26	1
$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	31	1
$14g0e4tQc-4i_Vdo1U2pNGwl-QbxmmrnRRA2DOZjnYs	29	1
$NFsUH4yHF1VWTTF3R7erS73-88ifZ3r1Lk1lrp7s5rI	28	1
$_VnHK-C5uJEI_LtZ6Edmfv4J6T35_tYN-Em2qO-sRyU	27	1
$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI	30	1
$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA	32	1
$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA	32	2
$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg	33	1
$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	34	1
$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	35	1
$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE	37	1
$Z2e6JO81o3A3wHKKBJSTB-q68xOeUakOBJi-6H0er2I	38	1
$ZaaKYiCE_n9AzqSGJntdPRcRM7BRhym69EHSrFwgdac	39	1
$oUHPDjqakCWglPegHTY6TC8e_Qaqub-Yoh_XfUKTjjc	36	1
$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA	40	1
$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s	40	2
$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg	26	2
$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A	40	3
$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo	26	3
$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k	40	4
$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4	41	1
$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	42	1
$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY	45	1
$Dc3jotNRZdjzDW_y7eg_fRWeyXs382gqm43HSX5lbOI	47	1
$KTjmV6JHWFiwg8JXvrYWGjeMxJtAvzZoRDulWpsNaSw	43	1
$ekFlSyfMDYeG34nr1qqB9Bi-AbjdiJ_J9bLNNsHuLKs	46	1
$zc8tOpOdwrt2LhO6ZIPa8Tv1PyclAu-E3cFNvQTB_rw	44	1
$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE	48	1
$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U	49	1
$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	50	1
$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo	52	1
$RDmQ4EMxY-FgFox84X5UWejaA1ImHNYssM_nyAlLSbs	55	1
$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw	51	1
$YP8LBjVbUpZKdDbx8B7q46a8-CJwDp3EK1qyDJCSoio	54	1
$xRkldK4rXGoVy6SNEazvj_642j0z4vnhDKSsno94oMs	53	1
$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg	56	1
$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk	56	2
$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is	10	2
$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY	56	3
$4X_PjJl7QiE3U7c8UuRUw5-rEt6S9u2f1fEzR5tiWso	10	3
$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs	57	1
$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	58	1
$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk	61	1
$6UQ-qIZULcBYRTpiEHtIjLH-lHfTx1ipANQeBo3ldw0	60	1
$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ	63	1
$d-DLbKD_o_R1rzHrZD8hyXWTZsKArLYnNTv9_1HRatE	62	1
$lzdi23BC1bOIDnNJnuoZzfFYBb3iv4PDZ1pw9Tg4z1M	59	1
$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg	64	1
$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk	64	2
\.


--
-- Data for Name: event_backward_extremities; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_backward_extremities (event_id, room_id) FROM stdin;
\.


--
-- Data for Name: event_edges; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_edges (event_id, prev_event_id, room_id, is_state) FROM stdin;
$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag	$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE	\N	f
$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4	$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag	\N	f
$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00	$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4	\N	f
$prihY7_PFyGlMWv4ENxfD2iizqJyMNoQbig1eNbs7UY	$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00	\N	f
$A960r4luhjM4-N8ZlQT_oZvugpHLDMyoL7N8LsvnnlI	$prihY7_PFyGlMWv4ENxfD2iizqJyMNoQbig1eNbs7UY	\N	f
$-Yvs0xYmtCB-d_v2Z7zGwQj8jvY11ZDzzMQaPKj3DHw	$A960r4luhjM4-N8ZlQT_oZvugpHLDMyoL7N8LsvnnlI	\N	f
$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA	$-Yvs0xYmtCB-d_v2Z7zGwQj8jvY11ZDzzMQaPKj3DHw	\N	f
$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI	$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA	\N	f
$X8K_VFEiQvuPoOUsEKgfuQVwB45D2aU4Otzgi42XIKA	$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI	\N	f
$M3CKOhgprwuo0MJ8t87vLcopCe-GbCoKg7i0182GwRY	$X8K_VFEiQvuPoOUsEKgfuQVwB45D2aU4Otzgi42XIKA	\N	f
$QRnyjHg7tbmZzQ96yfYxKL3mWswOmQhqDX8uf-mQqZY	$M3CKOhgprwuo0MJ8t87vLcopCe-GbCoKg7i0182GwRY	\N	f
$VDxFUMtILxytmO-s2kFHdkmCGyfSuMGfvtuZK6zZf3Q	$QRnyjHg7tbmZzQ96yfYxKL3mWswOmQhqDX8uf-mQqZY	\N	f
$ZzByIqF4yAyhZDP-bd2SHZXxQ5OlHpoF1y4i0fQps0A	$VDxFUMtILxytmO-s2kFHdkmCGyfSuMGfvtuZK6zZf3Q	\N	f
$O8ybWunHmG8woUBjshPybaeo067xS8r1LX3jsFYbF_M	$ZzByIqF4yAyhZDP-bd2SHZXxQ5OlHpoF1y4i0fQps0A	\N	f
$OYsK4JS05N5L1dz1HFkKo5nIk3YnZZbM5RB4ZkCos6Q	$O8ybWunHmG8woUBjshPybaeo067xS8r1LX3jsFYbF_M	\N	f
$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU	$OYsK4JS05N5L1dz1HFkKo5nIk3YnZZbM5RB4ZkCos6Q	\N	f
$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY	$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU	\N	f
$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY	\N	f
$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M	$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	\N	f
$pR2OnVDcJjiIYWrhS9nEoocIiQESVvpdsQfYu64Jhp4	$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M	\N	f
$uPRJ79eQQkEtz9GsgfXr0y-f3JPTNkvLdecu65l13Eo	$pR2OnVDcJjiIYWrhS9nEoocIiQESVvpdsQfYu64Jhp4	\N	f
$h_Aewnb-d3kjnDHdRL1B_3KhQvXaRyb0xNw9N0ctEUM	$uPRJ79eQQkEtz9GsgfXr0y-f3JPTNkvLdecu65l13Eo	\N	f
$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU	$h_Aewnb-d3kjnDHdRL1B_3KhQvXaRyb0xNw9N0ctEUM	\N	f
$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg	$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU	\N	f
$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY	\N	f
$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM	$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	\N	f
$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0	$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM	\N	f
$VWhXTrJ895IdYCilHYuIInhbeUE8rsIzTWUjb7gSL1M	$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0	\N	f
$egxiNGcQc850qQa01Ox8mP5yoEj1Q5Ex-bzUWtN4W5c	$VWhXTrJ895IdYCilHYuIInhbeUE8rsIzTWUjb7gSL1M	\N	f
$JrVCAJ9f2DtGYEV120F1HrAvVIjWumvsdBmenypJvNY	$egxiNGcQc850qQa01Ox8mP5yoEj1Q5Ex-bzUWtN4W5c	\N	f
$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I	$JrVCAJ9f2DtGYEV120F1HrAvVIjWumvsdBmenypJvNY	\N	f
$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg	$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I	\N	f
$38B-Weejbpnil6mQvy5fn8Vc0qGoDasfdZ5t3hdt-u4	$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg	\N	f
$uMZ-ZidlxCHhXanXLN1-ytrhTVb9h1j1K2u-ZEvFmLI	$38B-Weejbpnil6mQvy5fn8Vc0qGoDasfdZ5t3hdt-u4	\N	f
$5P00VdpT2xziYLl8SJGwC9nL-vpZPERv25JcU1tQEy4	$uMZ-ZidlxCHhXanXLN1-ytrhTVb9h1j1K2u-ZEvFmLI	\N	f
$bJp5268AbMlSvGSOLwL1QuROb-6Q8w3--hz5R4shhsE	$5P00VdpT2xziYLl8SJGwC9nL-vpZPERv25JcU1tQEy4	\N	f
$nX0BIvxzfiMjoGPKmnp3zaDJ_Lwe4buCfaVfv4wKHAA	$bJp5268AbMlSvGSOLwL1QuROb-6Q8w3--hz5R4shhsE	\N	f
$MKIG_xPNWt7pAeRQie1-ff8u79mcVuNrOYFINP7GYb8	$nX0BIvxzfiMjoGPKmnp3zaDJ_Lwe4buCfaVfv4wKHAA	\N	f
$C3PYkudwbc1C1vhjMWGEuUhQS2SwdWK2dFzNgexrfug	$MKIG_xPNWt7pAeRQie1-ff8u79mcVuNrOYFINP7GYb8	\N	f
$7683AfvdvVGbujZUglQ3dOVMhLfC5n8sd4USeya9_9A	$C3PYkudwbc1C1vhjMWGEuUhQS2SwdWK2dFzNgexrfug	\N	f
$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY	$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg	\N	f
$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY	\N	f
$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI	$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	\N	f
$14g0e4tQc-4i_Vdo1U2pNGwl-QbxmmrnRRA2DOZjnYs	$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI	\N	f
$_VnHK-C5uJEI_LtZ6Edmfv4J6T35_tYN-Em2qO-sRyU	$14g0e4tQc-4i_Vdo1U2pNGwl-QbxmmrnRRA2DOZjnYs	\N	f
$NFsUH4yHF1VWTTF3R7erS73-88ifZ3r1Lk1lrp7s5rI	$_VnHK-C5uJEI_LtZ6Edmfv4J6T35_tYN-Em2qO-sRyU	\N	f
$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA	$NFsUH4yHF1VWTTF3R7erS73-88ifZ3r1Lk1lrp7s5rI	\N	f
$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA	$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA	\N	f
$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg	\N	f
$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	\N	f
$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE	$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	\N	f
$Z2e6JO81o3A3wHKKBJSTB-q68xOeUakOBJi-6H0er2I	$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE	\N	f
$oUHPDjqakCWglPegHTY6TC8e_Qaqub-Yoh_XfUKTjjc	$Z2e6JO81o3A3wHKKBJSTB-q68xOeUakOBJi-6H0er2I	\N	f
$ZaaKYiCE_n9AzqSGJntdPRcRM7BRhym69EHSrFwgdac	$oUHPDjqakCWglPegHTY6TC8e_Qaqub-Yoh_XfUKTjjc	\N	f
$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA	$ZaaKYiCE_n9AzqSGJntdPRcRM7BRhym69EHSrFwgdac	\N	f
$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s	$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA	\N	f
$ExyXltZ8XVgCS4zv7cy-lT_wdLHC4I6gFOEe9WIXLxo	$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s	\N	f
$afVsFJEIQ2l3SduwcVGDn3fVRxWpwp6Z294e_VvMTFc	$ExyXltZ8XVgCS4zv7cy-lT_wdLHC4I6gFOEe9WIXLxo	\N	f
$2F_r1QYHaObawQDNr91dUNyPG7vMIy94v6I6KmYFAYk	$afVsFJEIQ2l3SduwcVGDn3fVRxWpwp6Z294e_VvMTFc	\N	f
$_H2DZoM2QWFOqEQG70J87qAZM3H467C9Jlh4_5gWzzI	$2F_r1QYHaObawQDNr91dUNyPG7vMIy94v6I6KmYFAYk	\N	f
$nOti7xJQKHyROEyoGtsBKtap-hocvso_bgZ53R7EE8U	$_H2DZoM2QWFOqEQG70J87qAZM3H467C9Jlh4_5gWzzI	\N	f
$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg	$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA	\N	f
$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A	$nOti7xJQKHyROEyoGtsBKtap-hocvso_bgZ53R7EE8U	\N	f
$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo	$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg	\N	f
$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k	$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A	\N	f
$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4	\N	f
$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY	$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	\N	f
$ekFlSyfMDYeG34nr1qqB9Bi-AbjdiJ_J9bLNNsHuLKs	$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY	\N	f
$zc8tOpOdwrt2LhO6ZIPa8Tv1PyclAu-E3cFNvQTB_rw	$ekFlSyfMDYeG34nr1qqB9Bi-AbjdiJ_J9bLNNsHuLKs	\N	f
$KTjmV6JHWFiwg8JXvrYWGjeMxJtAvzZoRDulWpsNaSw	$zc8tOpOdwrt2LhO6ZIPa8Tv1PyclAu-E3cFNvQTB_rw	\N	f
$Dc3jotNRZdjzDW_y7eg_fRWeyXs382gqm43HSX5lbOI	$KTjmV6JHWFiwg8JXvrYWGjeMxJtAvzZoRDulWpsNaSw	\N	f
$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE	$Dc3jotNRZdjzDW_y7eg_fRWeyXs382gqm43HSX5lbOI	\N	f
$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U	\N	f
$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo	$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	\N	f
$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw	$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo	\N	f
$xRkldK4rXGoVy6SNEazvj_642j0z4vnhDKSsno94oMs	$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw	\N	f
$RDmQ4EMxY-FgFox84X5UWejaA1ImHNYssM_nyAlLSbs	$xRkldK4rXGoVy6SNEazvj_642j0z4vnhDKSsno94oMs	\N	f
$YP8LBjVbUpZKdDbx8B7q46a8-CJwDp3EK1qyDJCSoio	$RDmQ4EMxY-FgFox84X5UWejaA1ImHNYssM_nyAlLSbs	\N	f
$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk	$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg	\N	f
$4FmnE3et4KlX8gqLLuDjSYLUFKZG8CgNq8_OPh3TWYY	$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY	\N	f
$4X_PjJl7QiE3U7c8UuRUw5-rEt6S9u2f1fEzR5tiWso	$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is	\N	f
$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs	\N	f
$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk	$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	\N	f
$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ	$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk	\N	f
$lzdi23BC1bOIDnNJnuoZzfFYBb3iv4PDZ1pw9Tg4z1M	$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ	\N	f
$d-DLbKD_o_R1rzHrZD8hyXWTZsKArLYnNTv9_1HRatE	$lzdi23BC1bOIDnNJnuoZzfFYBb3iv4PDZ1pw9Tg4z1M	\N	f
$6UQ-qIZULcBYRTpiEHtIjLH-lHfTx1ipANQeBo3ldw0	$d-DLbKD_o_R1rzHrZD8hyXWTZsKArLYnNTv9_1HRatE	\N	f
$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg	$6UQ-qIZULcBYRTpiEHtIjLH-lHfTx1ipANQeBo3ldw0	\N	f
$oZTAqRbttOiPuTLHUN_H2ptq2VqGzcx4o8urdtkZR9A	$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk	\N	f
$x-laZQjLN_ybbNbLzACqCd1-j4uqjJ9UBDzWYpYGv54	$oZTAqRbttOiPuTLHUN_H2ptq2VqGzcx4o8urdtkZR9A	\N	f
$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg	$YP8LBjVbUpZKdDbx8B7q46a8-CJwDp3EK1qyDJCSoio	\N	f
$Np7L2UpX2tMrmcWkrhqTkIPPQf2JHPiRI9eGpZCUi9k	$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk	\N	f
$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY	$Ax7Nf2f62jFM6Iukww-bvFvDhxGkhcDQHJOA8GGe3pg	\N	f
$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk	$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg	\N	f
$Ax7Nf2f62jFM6Iukww-bvFvDhxGkhcDQHJOA8GGe3pg	$Np7L2UpX2tMrmcWkrhqTkIPPQf2JHPiRI9eGpZCUi9k	\N	f
$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is	$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg	\N	f
$zM6vJpoUtsXTUex3viHLPy-oiEKdsGSx6OqizILlFdI	$4FmnE3et4KlX8gqLLuDjSYLUFKZG8CgNq8_OPh3TWYY	\N	f
$Er7aPlzKizvAozxf620HpDa-P3Uqu59Re3mkzFi9s8w	$6kTTzdJWNwDbZB4BZt4uyMdlAegiGE1HtQPgLUpZBbs	\N	f
$1MLqlvYR1hYyOHAgVVxyOygzdyCxZYc0iLQZrXia5Ls	$Er7aPlzKizvAozxf620HpDa-P3Uqu59Re3mkzFi9s8w	\N	f
$6kTTzdJWNwDbZB4BZt4uyMdlAegiGE1HtQPgLUpZBbs	$x-laZQjLN_ybbNbLzACqCd1-j4uqjJ9UBDzWYpYGv54	\N	f
\.


--
-- Data for Name: event_expiry; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_expiry (event_id, expiry_ts) FROM stdin;
\.


--
-- Data for Name: event_failed_pull_attempts; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_failed_pull_attempts (room_id, event_id, num_attempts, last_attempt_ts, last_cause) FROM stdin;
\.


--
-- Data for Name: event_forward_extremities; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_forward_extremities (event_id, room_id) FROM stdin;
$zM6vJpoUtsXTUex3viHLPy-oiEKdsGSx6OqizILlFdI	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
$4X_PjJl7QiE3U7c8UuRUw5-rEt6S9u2f1fEzR5tiWso	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir
$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir
$1MLqlvYR1hYyOHAgVVxyOygzdyCxZYc0iLQZrXia5Ls	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
$7683AfvdvVGbujZUglQ3dOVMhLfC5n8sd4USeya9_9A	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir
\.


--
-- Data for Name: event_json; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_json (event_id, room_id, internal_metadata, json, format_version) FROM stdin;
$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"d6VJPzZuuSNSgKWy6axJ4Uzi3T5gRMBXUAvx5huUA9jFtjZwV48Crqz3L/YzJKZYsEiWnBqQk7j0X80ELBkFBQ"}},"unsigned":{"age_ts":1783625247853},"room_id":"!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","auth_events":[],"prev_events":[],"content":{"creator":"@brianrockwell:matrix.shikpooshaan.ir","room_version":"10"},"depth":1,"hashes":{"sha256":"nLEHtCnDSRfcokUNU5U2Md22lVKK2YdmXuAd8xknMnA"},"origin_server_ts":1783625247853,"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"","type":"m.room.create"}	3
$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"C2CBAszUjaodRT+UdEA5o7D70PQOrKL6zmb+EOyf5PE+hY5uTYiXgE6si+03B5e+kaogmrF+eXZ15KU1HUpjAQ"}},"unsigned":{"age_ts":1783625248099},"room_id":"!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","auth_events":["$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE"],"prev_events":["$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE"],"content":{"displayname":"brianrockwell","membership":"join"},"depth":2,"hashes":{"sha256":"emtskwnx3uJZIY/+MExrcvicIY4UutumHuCNBGGB5/s"},"origin_server_ts":1783625248099,"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"@brianrockwell:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"1zS54TFRZFe9+yQtXQqEt7BHAw/9X5fcQm465Eqyrla5Y3eyjt3xO6qRpsxFR/S70rksA2UTFoVnP6/BStdvCw"}},"unsigned":{"age_ts":1783625248330},"room_id":"!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","auth_events":["$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag","$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE"],"prev_events":["$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag"],"content":{"ban":50,"events":{"org.matrix.msc3401.call.member":0},"events_default":0,"historical":100,"invite":50,"kick":50,"redact":50,"state_default":50,"users":{"@ali:matrix.shikpooshaan.ir":100,"@brianrockwell:matrix.shikpooshaan.ir":100},"users_default":0},"depth":3,"hashes":{"sha256":"X6+XIYAAzBA5iM5RNzWuE0MYwEllete+MsWULIkESbc"},"origin_server_ts":1783625248330,"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"","type":"m.room.power_levels"}	3
$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"k3oaH/MmtuwKDf3C9aBBYHN4PR09J8ukVKVVnXUreEM1WqRoKc55ZQm/15CSKyjqzhse8CddIZXpvkfFYzBNBQ"}},"unsigned":{"age_ts":1783625248374},"room_id":"!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","auth_events":["$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag","$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4","$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE"],"prev_events":["$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4"],"content":{"join_rule":"invite"},"depth":4,"hashes":{"sha256":"zz7lvyy/K70MoEQhB23fVjUqDtPcxdoo77v5nyLlhpU"},"origin_server_ts":1783625248374,"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"","type":"m.room.join_rules"}	3
$prihY7_PFyGlMWv4ENxfD2iizqJyMNoQbig1eNbs7UY	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"vNyHfZm/DYV3Ccxhjz08BNDM1y+2n5OBQjSIyZKwUfoxfUGA6NqZZdqEzyDPazoVKBc75YKSGlV6EyO7fPX2DQ"}},"unsigned":{"age_ts":1783625248376},"room_id":"!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","auth_events":["$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag","$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4","$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE"],"prev_events":["$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00"],"content":{"guest_access":"can_join"},"depth":5,"hashes":{"sha256":"vSSmYa5P204cG6tzFL6BGJOR1r83PftzkOnefnacgds"},"origin_server_ts":1783625248376,"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"","type":"m.room.guest_access"}	3
$A960r4luhjM4-N8ZlQT_oZvugpHLDMyoL7N8LsvnnlI	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"jKz+rt1OBdvltHSHMJGmSG9OY1Wt2rCH75qGDFznA1lcCsNqHrktqNpG+2RsmTYT55W7lx0SG/qkRh6Z1lHHBg"}},"unsigned":{"age_ts":1783625248378},"room_id":"!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","auth_events":["$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag","$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4","$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE"],"prev_events":["$prihY7_PFyGlMWv4ENxfD2iizqJyMNoQbig1eNbs7UY"],"content":{"algorithm":"m.megolm.v1.aes-sha2"},"depth":6,"hashes":{"sha256":"LIOtqHT8Zht8g0WoRyIDMEi/LqT6OoZYhtfQYruye/Y"},"origin_server_ts":1783625248378,"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"","type":"m.room.encryption"}	3
$-Yvs0xYmtCB-d_v2Z7zGwQj8jvY11ZDzzMQaPKj3DHw	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"9rMfsW8DsC2Ebd+S6dZTESIAVEhW60r1IJ15u97M/6XhfIKyvhq8fB+uhN/kbMY8Nxf+xgCz2C4nHp4W+ULkAw"}},"unsigned":{"age_ts":1783625248380},"room_id":"!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","auth_events":["$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag","$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4","$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE"],"prev_events":["$A960r4luhjM4-N8ZlQT_oZvugpHLDMyoL7N8LsvnnlI"],"content":{"history_visibility":"invited"},"depth":7,"hashes":{"sha256":"nsu6O3O4z1Fl5brs09Ro5rzhMm8A5kLdmqylL+dJ1xo"},"origin_server_ts":1783625248380,"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"","type":"m.room.history_visibility"}	3
$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"CIrp9UAyeAvGslVXQQ01CctVOmzi8nCgJuJ46EuQNJBFjy5YNjWbEvVIkIcw2L3qLY/OhhBhXZqyLq6p41MQAA"}},"unsigned":{"age_ts":1783625248705,"invite_room_state":[{"content":{"creator":"@brianrockwell:matrix.shikpooshaan.ir","room_version":"10"},"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"","type":"m.room.create"},{"content":{"join_rule":"invite"},"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"","type":"m.room.join_rules"},{"content":{"algorithm":"m.megolm.v1.aes-sha2"},"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"","type":"m.room.encryption"},{"content":{"displayname":"brianrockwell","membership":"join"},"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"@brianrockwell:matrix.shikpooshaan.ir","type":"m.room.member"}]},"room_id":"!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","auth_events":["$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag","$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4","$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE","$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00"],"prev_events":["$-Yvs0xYmtCB-d_v2Z7zGwQj8jvY11ZDzzMQaPKj3DHw"],"content":{"displayname":"ali","is_direct":true,"membership":"invite"},"depth":8,"hashes":{"sha256":"OBeFssl44jtECpsfa1zqLZRGREkPauLTLJNcWC/eUP8"},"origin_server_ts":1783625248705,"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"@ali:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	{"device_id":"WGYBGBWZQI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"nA4YUwEfqSCh1c59cjwtuNqd5GIatm1jMtTAIZl6NYVCVZiv+1Y7UmLQ95iqX8AoTFYYQUdOBjrUv/5hsCgpDQ"}},"unsigned":{"age_ts":1783625265280,"replaces_state":"$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA"},"room_id":"!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","auth_events":["$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA","$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4","$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00","$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE"],"prev_events":["$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA"],"content":{"displayname":"ali","membership":"join"},"depth":9,"hashes":{"sha256":"haXviDEZMJrQScZUwm9R61Js2qOOPMPDyCViRMZycy8"},"origin_server_ts":1783625265280,"sender":"@ali:matrix.shikpooshaan.ir","state_key":"@ali:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$X8K_VFEiQvuPoOUsEKgfuQVwB45D2aU4Otzgi42XIKA	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	{"device_id":"WGYBGBWZQI","txn_id":"m1783625441100.0"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"GoiuIy/8NseU0EzAY+NVcQPeVXUnmgm8hS1vnLvTgPTjScbrz2lt32waBNSySmW6PJgUZcYu6rVliT7AeDhiCA"}},"unsigned":{"age_ts":1783625444076},"room_id":"!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","auth_events":["$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE","$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4","$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI"],"prev_events":["$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgAEoAO7jMGf691R3VnFwpsFzpM+G8jLLxBDb5ujN+wdcf26JW5/l2cZSyKNNHMpZNtUxO4MKsg43dU1bBtv1+nyIMMaEezZR2pgJAcfYfUD/HHKH8lhzPaGlo4uN8IlLsGJLZ9PquSCMs6kfC6QsA6wFcd6a0/kLhtmX5HXJo8U7dhvuhE/QN5oNT9738BlJ2vehK/QcCzkksMj+51wENnurSCPyho2xJm7hJ/uP0IphspZlKzzX3lMRZITdtOXnwU/HBOtp2Hb5MZ7GqFuYHYjyJ3FWoPgdfz8zPO6lMHLtWH98VlPYP0ab/8Z0jHPOVGD1vwPbyfRPo+z8gqGlsVd84NnArZb+Tj4OXLsiCCZDTcRZ7zobN3Z6pEU3p53UgIXLIwSS9qkY8ZdahKuagw1Vk8LkPHcAWX/LhoezcAvcXRc0XhOgyJaFViq4FXdQ7AvYvK9hvACpzPkywXUlq1UVFhDrbh6Pj0KbyPymlyNi2PPj/479xsnVJvpm4UMQL5Yr2yzhvpzmrwm9VZE5HuiIj1T+wT+sHoCSzyZmop/GAI/yziEPyU8MD6JQ4kxiYOz2a4UFsQNXdp5c+ZX4W1LGguFHn+M1S9NycU7AAhSwx+w6qr/TA5thIPc8jPqms9I+E+5tJhHbnoURUc7/IKQ+DIawvwuI7gknWJYBXVsKwbXVY0+axyEUMxNC/9vVpLdEeAKSGCvL7p4eVnvoM+OI4EdifZzc5QiwGje9LLLm53OMArQopzANUBwsjCBFOe27+hrReCNMboIQ1dZ2RIvZchF8n180D/6QqS0HDfSw88ybQHoZid7NY70t8a7uGN8nq0x4H09J+JDRWXdRQWYVXF/rdMYgeZriJLEFANeE4lvl49nsfJF6cIL4xROUVoxgL/wgk0BN4Qn0iiiwi25qR1v92KhtWDnTL8X54aZlZFKIfSY2qQMnBgyTPkvGOd28IJ1oyM7o/9WBJ2y16ZtLQNoyASWP00vSU9v/M3/r3bpAE0KWvIOnydyUHdXiH0xDirhuBkUP5Km6QQbZdZ2uPQUASt21sHXGwsXM9gFVlyhYru9wwttnsXh4IalqaMDZQg7dLkUDBveMSXkE+a1Fj6bRtKpbyl8880LKe+4vIob+uTQVB9+WCaMNbI74jeMIPQyPdsvvFW/QutK7prGtXD0MHaqpcA6xGmN9Pwi8HjCaNeWcTe4gHIgYEl4coHFHSOdi2HPIrLQW6hMHN/UFR7odR7XHqeEvv7V8LRbW/eHFswjgBCYwRGXsS8mTAjWBfIzEbMqoZFSckxBywFTnQbhSCZ1qCSsCLGzaZeh2GnWK9qBJgbZk0DOUP+vE+RlN0oagf4WHsOhJMBvRu0jBCQmOQo7ntxq2mD0MgXqiHdN0RjprmGgfeaQJaBNG967juipNE1oUqknj1KLfTJ5d2nSvb4QFdWR+BP0xcj+hSDdX/t0Qi6bIPGbh0wjPgQsiXFSEefrG0IkravTfiFmh87gPY3tqLRBs5THnz/thkHNBkZm/PQIp78zBk9RPKqdEwHGntKcBamCQftk88nn3DlmDlBU3I2+rPD5MHw3D5JnmNSWTsZ31UKGhZffIOQBgWV/MQFSox6MEIMOXYzpM7YMakrbnwGZEW8TN886Hmu7kfFFcIa3jA0TBvRNmtOEAddXk6DlAKzg5m1b4OV1azGUaPPgAQrTPnwfm6lWnYu7vlbmVWMv4nkXxVohgNQjROG99r5c0yvLT1ZQbGrcgeKZ8UP49idmExTpandGXXyXeyIh6shzShbLUdxMxs1PKZUgsSHvkf83LHicq3Pc1OWL+43lSx9htzkYkpG8cmfWon2P2EDwE0dgNa+DChMcijUwAvgWWNYzekWoNOZQ4l3kDzh7oQtZZ2LCZYMC0zK5BdjG2nSS1pUbvwtCFhBhLJEobhbDV5eM5v7/YuW3LSy50mui1ML640jFhzWza4x9mVaC+8v+AzFdTzAzZM2o/pAD57ZssNb7zZKNI7dkTXcPk3eogv3zcQh9pOUhsdyPZuYfZ5l6PeCqtjEMlwKa6NdSfDqjmdUvXNn508pq+py+fqQilWrjlZOEs59rpapk0K4JsJ8y6xhNL8cTcjyzz5WTQFcW4h5bkXM25/dkUHwlTQRTernDtBLZ5mOXzfJy1HMoARsIJ59yRQTWoZZXykJZVQCuTc2O8sdvZB1KOmfZoXkCZ7mBsybFBdwvTaGlmFFgBxXDUi6pMqmjpLrGeDF3QGhsMBF0wsw8Uv+4nfi/rw3HkXtQsALSUh6Ns9LKKvYnvonkFwLKdI5pfFuoERYqrS4w27h/BoaUF7LJhMOxRDZRpF7V64zQhr7WLSG7f2nFvB3QzI5rjCi/HBYPDBCvhidIyvJFh8cMjS5zt//ea66Sis8DCVf+zoAGt8UXaebrH9TedxEBWVuT1xNqCTsOVYzNEoUMa9J3ro33vgwxsh44igHbDsns1FUPsLVLYnxxqP4BhdGAg","device_id":"WGYBGBWZQI","sender_key":"Ujw/8UwhbJL/MqP2S8YMS/PID8kyzPOPUZ/gIbLXoSg","session_id":"s8LU3T6qjB2MaG0+jQgHd/F+MNfkn3CQ7Q2O4FX+H8w"},"depth":10,"hashes":{"sha256":"BhqGh5hRisrLmliNa8jhUxdkdzxhhipqy1PExrwRo/c"},"origin_server_ts":1783625444076,"sender":"@ali:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$M3CKOhgprwuo0MJ8t87vLcopCe-GbCoKg7i0182GwRY	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	{"device_id":"WGYBGBWZQI","txn_id":"m1783625446618.1"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"8k+hG7338QRijGVg7fSulUbrwACao5OGXFxAZhjPMXVs7lheO0+GghRA0pGPvOvkszyiXwvLD2pgKi45GOIUBA"}},"unsigned":{"age_ts":1783625446240},"room_id":"!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","auth_events":["$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE","$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4","$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI"],"prev_events":["$X8K_VFEiQvuPoOUsEKgfuQVwB45D2aU4Otzgi42XIKA"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgBEtASmnJ5uSdFYg2AACVcTyZh3E5xCnxnDoBAls4na6OKp96jGdC1YeFD9h7OgakU+sOwBNO0TfpRpjfomGkcIChI0CfMcqpZGfQNKnoZsLkjLxtA/qnfGSY/8fel8570BhhfP/P+2shub5EGzuJr8XeTV5jCtemIID2UCFlq+OLT+rUagg/RXbdby7RhyMqRUBtx4Pn789tCDy8WaNiZzpj8FntAm80UqUiS24PmtZkuoqqi/0/NQFQ63YsgE69Bhl1K3vIZhIcKgnOH9IExIx/xvV7pbSlKj2I+xQFcIvVn7UlzN17ceWNzUxovqsktNY0bBng/Kh/P/GWve9RnvkThG9mrEw3s0hFlOywgKx68TNOiigr3mFGCasLJwxThPtq+fxBvwHmliTQB1a9bAUCExwEVjPadVqH3TZyYYwLtKwqnp2Br0+tVU/SEBwReeIZkyfZRckoe0y11rXJi+MDonvjIBVzBdL2yYBUgZwQ6Z3gBlFBr9uf/WK4FWz6pELOscX4hN0jVjfNsd9cAbF/SzQ+rbaaYil7Pp01h23wwGQzGrvip1uzzUXWBxfhZlegbCwvnxNzCtCeCdXOkLS3nIy6hUNzk0ggrlrpzT+8ei8KFoDe7jZc1t1n6MeJTdN4BvNxn2fRKUouRecidi1OzUzd74hfZfsiSeMg7ZNHsaINfBLtv5rkeEfq273a61qqWNSVSQDXdICq/CnzaJwkNnVyKBk0L/H+ptzjFOoaZYtSMR4N52F7sSaChMFJLMSD6Z28HtGRReMGxVwXyXZ8tNAgnh0SAgPA472NND2YCdaxdVrpY3PjyuUzlmpbX/krnVrIrsmNV0jL1pv1aIuaBt0nnv6gIwQLjgK+udMPw4jP5xMpA3Bvy/5N6IPr+kqJ+dzcpCxBZeS+b6hzYxnh0xcWqa/jo5/+sqTAIDkQajqugsT4RRfMQ5nqVDythtl2uns/sxpXiH816Yqx2Smb6kjlZAOR9EGXtp+GNOyuvMLGPyIiNl36j3R/2FksjQgl+bGa8IXHcgqEfwKzFZ8ewPpg0KpjDQPlZK4Yk4BUwgFDrmaXNrdTfl6Bzd3aCJuH5Pw4tiq2YC1oIenaUG2KZwTdzYuYqvr8ULKRGtLyoaq22zEKSaEVhj4rqw0Tidph+u3FCQ1MWAo5OLlnP4R07HUsuCIV2w+TVnFUb/ExlqFkwzJ42AfTOwAWOT/kWnGkYUjrL65aFCV0eUEdxFfNM7EAU6apAn0OXyM4QRi7Pp3qGJz5BWmOKG2weGMcyRiXD5SI/Ufa/bossYzMZkargta8sCohUKZMkW9yOaAMUsSK69csJiWIvIvwCQ9U73kttmdPQjOmL0cJl6LUCU5+OQL+IMoJVL8aCtyIZn16Y5Msyv4ZyDFe9PJwzbaXoBu3ojo5uPdD7ull5rdKxpG0/thxXOtJES73fqVDQE/rQoFvCldNCTP6fhDqIuHe0enZ4dO+Q/E1/i6o/ZP6iL9pMfmoOxR1V2O/LYyFc8dhikVUEBudUmGGLql4FpJr47HuFMOql3GviDGv50UeWYgggyMwuia2SZsjC7KYzOK2S2qBWl41H/HLAk85dCUOU4wXlpk74QodJJ+pli8IBNJ5TFM4fQmJ+R2zU+9hPZVtmE4DH6/2otrLHrVoZuSzjzt0Dd6SGkyMM3kywPsfSaI7buQyzzhH126WHu8vDRJ2NnJbP+6EIDjGyGr+5Ou9TizK+tP1fox9k+nOR3bOuylt/GmBeuwphilRptMV7FYeUeLnrgziAjG/bo0S6ZuvSP8RhPx7veQNHgkaiof4daXcs1/7Cn9jCiJOc2Zp0kogObNtY76K2Z+8LQijSi+tkQQH2RLHyAtCG96TNA3xuYJHz8yaiwUdiPGFoNMqxWf6o/rgt2/kDT5pMOf3+mXSVnSwr4ATQHK9MQB6+pRvpsxbhHsbETGFhdJaJUFvB0mvinkDi3LT2zKIyt4jcv9S8ISUAJrFARgJZMTlxj+qdIDDfsFll3bqR9w/rFUoH5WV9X8E8RNJglKye19HSrzWBkVD0OyW408KtrstYf8RCU1ufruSEpJVagNLO/JvEz3ws+kMmfzIbMgy2BBSp42tdXqFuGCixwVEzhnYneoHsWCmSgZQnyX/o7/i5S9ZucpfP2k/54zz4bTOKMSkHyst+eC6TrlficqIMj6b/hhMV7cAl2JJx7TOYVH2FMTrMC4v2m1RQE1A95MVsmjc1GlQ8LvRY1fssURmEukICu+hRGYH5xap/LwOxdBOxY2rkro5k9O2SIfsBRb6KJB1rwixe9VvDcBJzqPrRIufjwjUUsDKUmJcRV9wvZBoyZyCji4x8dQAglsWKXagDx0s9jN/ercJfFmHG+no4gWRt2thGc8WlxvmvOa0QurAhxiPEkfPsEraOS9NHaKdxhxM7YyJA4wMDNDPnLgHVi3kci8otHE/GqUpAxG5NOn26O9XSpcMiCZ+QXPBBWrtTDmyztyv+lvCRwqcNZgOQPiocvVqhPiM9LjlpYT04rnqf4EsfGM7Lgjpr/LID91atQII0to/L5m8b37J3r3BYV/i5QlhcYmByxtcYUvBU1m1R4tHhWavpgUSKh8QWdjIUQGRAM7Tvwhj55Z6REpROyF7SVYUbPPJYnVXJFEm8ase38Pq8E68LXjAzM+QOPLCk6HYPRAB9qdOIttOdM1o0kON6MTrwO4aLjpGTJzxPfoWoAUwR4CRe2rhYVIQ/GdLttKdX2HPENN0RVpj5Dl6a0o5ZkoGzqdvXub6WMXjBMcOZjKJISTpcI8KISYj8PCjEWXm1psw+WsNqsvCTftP8WoJaj9mvKi1aWjMeBNJPWPMwHFIcWJHWqTHBnGkpQLp8kyQUpVFlP9c9iirZ2tsDHeC8VmNKFwImb///NAT4tnF13XSoFzKxEULtgqupt4f9l3/rbeD+qE2HpR5lAiL+UG/We5fcs/ycsbf7aDc53iEiFFZ3nBVeC1yYItPNWNazkEg0B5QMu+HtJ6QTttDvk9XJuDa9WMQVi9LYvU9YMgLXfVmrl1iff0lBg20v9r2xH36tReINzdGQZRhgYX9pyhSmGWl4GmN3dHLl451dS+qEQB0z4jAvLaeo+2l35/5ff0bZaurqIFIdNOqaIWaP03HIJzyQ9rwmgWDVGLFloxj89NBfRgNvzsWR5jO7QJJKkRnI1x1HppJsFF6UfKr18YqoklLbUVEVdbZPyquaIP9TBuFbyGmhOIRzMvRZ9VMdhcou4QAK3etiS2t/EDbargo","device_id":"WGYBGBWZQI","sender_key":"Ujw/8UwhbJL/MqP2S8YMS/PID8kyzPOPUZ/gIbLXoSg","session_id":"s8LU3T6qjB2MaG0+jQgHd/F+MNfkn3CQ7Q2O4FX+H8w"},"depth":11,"hashes":{"sha256":"7cF1QhUg7jA2loW6szBhB6jlqLRdnXCAARM4nupiRtY"},"origin_server_ts":1783625446240,"sender":"@ali:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$QRnyjHg7tbmZzQ96yfYxKL3mWswOmQhqDX8uf-mQqZY	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	{"device_id":"WGYBGBWZQI","txn_id":"m1783625458542.2"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"RI8HkQJRidZJWhOyCpgdf3L5MkdwGsw9KbtcNOe8ErRYhOoBwFACRDqY6/AtKcxV6nm7/TjBUpnRMMfwbbAhCQ"}},"unsigned":{"age_ts":1783625457313},"room_id":"!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","auth_events":["$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE","$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4","$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI"],"prev_events":["$M3CKOhgprwuo0MJ8t87vLcopCe-GbCoKg7i0182GwRY"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgCErABzYeTz37cFn9/ih4dsz2OE1brdxOHqpJcAR03lZaqEzqGeGzM3UPYcY+mSf29Hj9r9EGtSW+YQ6Xvl9oSOE1KFsRI7tUJzqQxIJKg6609ENKkYJ5sb6Y6ayBD0uc0oTKZESlfp1l/7Xyvse/dKgjeL5zgSuMf+EDz+o0N+5iJ5d1z1eM8RwKl7WVTz7kzigCmzqdtkcQPmPo+FVlP5GU8+ZlT7M4/fUUjIt9bApkliQ9oZ+PpH5fbQ6P9b9KEHWKpYSMtqtUZ2zoKqgO18UxBrqQe7m7ofL0hMDfZIBW5F2UMha6Ry042aaeE3kBqZ8bIbRzG8tUM5gE","device_id":"WGYBGBWZQI","sender_key":"Ujw/8UwhbJL/MqP2S8YMS/PID8kyzPOPUZ/gIbLXoSg","session_id":"s8LU3T6qjB2MaG0+jQgHd/F+MNfkn3CQ7Q2O4FX+H8w"},"depth":12,"hashes":{"sha256":"QnOiFwBdmlkMSjShLoRU6B0+pbGFdjg/aP04D6AlXpo"},"origin_server_ts":1783625457313,"sender":"@ali:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$VDxFUMtILxytmO-s2kFHdkmCGyfSuMGfvtuZK6zZf3Q	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	{"device_id":"WGYBGBWZQI","txn_id":"m1783625470170.3"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"poAwIdTGXUXYjKI0dbFwY0b8uMbs/g6PZcx1ns7OQhwwhJ4g1QR8aWuD34gHszO43ugnDjHjz/SO+O9jEX5HAA"}},"unsigned":{"age_ts":1783625469594},"room_id":"!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","auth_events":["$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE","$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4","$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI"],"prev_events":["$QRnyjHg7tbmZzQ96yfYxKL3mWswOmQhqDX8uf-mQqZY"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgDEoAOnWNGhxCap1vMuaifqGL634CRM/OjWdrBbtegx+/C2U/rqMgA3FgUt7vBVZjCg31pW90n69z7U0d23MQ9fuLpJ5rHQb678oys4vYULljKqLomSwr8wHGR7ylqQiiLjQU/7wWDIvx1IKbVFpYZBbmrO6AwXK8GGCNIWTzMsrtvaZHorj7CzdV4zbjRanLvhb4wAp0UybXxQGeeAJJplF8q3E+Mo7zQZNvy3jQsSR7rByP1Ne4DkmE1/VKLJhnMqrU9SEusNJTbCubgYRVhJokZldiMrEbZf+zYznjbcbUB8VG+2SGFzmNbaEZ8BOX/Q2H94MrUdT+npH1Qt5VCyqkhshy3b0VhNk2UKigh/e9rNqhc05Exx8/SeuEBIcklf8cqfcJiwD4w2VvMzMItvzHMoZ9sg7OrlshlnD20S2dqf6OkvU+zDCNcT9kh4QQxkdA5gZi0HfbIlihlBDzWRvAEP7YGl4UqvcemuVWCdnS8rUMQ1ofhE3F4euK4NBBUb8AQ2Yg6husUzZ84nut+FoxA/D5mT3UYiSdrRXeZj+Ii7II95iH0lIaBySFDKB5yKaOT3UYTCVUmCfqJVVCj+AbXMpwO8Hqt9B29BFVgHMr4i0lB8UqeEFS40kOAdlxsu/AWwosEvNfz0GluetZqFjx1cPsuEtmPZy+sBpzWIRJjQS56GagcZWbchilYGMFfQTczwY6VdYwbaTpsMZe7MvqzXfxLBh98KsxQyd9ikgTCnTY0+dZBUa94S1TAqWM6tXT4eZ2ABSgW4Rj2zjCkmhmMzXy4VKKzDa6Sljqnaq1epgu2fVUOGP25fLCgAWh7HRLOHG0k+l2N3+jP0TFYqDwOJHNrly/OFrHwV4BgREgWn4OACetU0A8uXH/v7GHOME8/u0rfJRuwfdHE7szkJfrsw+oXByxH+F/OK7lBELeoGvKlMdlms+JKwo1+1czER0uAE1GfnmgWrs7O7wAkaVG1e8JCpBoM/NWPnruVit8mgn4nvr1yJeDi8P+sGpNZkTVke/XYY4Odn9KQLO2IdE2hMTdCPJSeDXRthTmmSvLKCVzwp/FHKRyoZ2RQEjwQYdWDXOR9KVkUYRtEBywdGuUxDE73khYuPt1UJYSQ/Pd4hhLUXb697oteNL3aaHVLjeOeIROWTqQyUBuC6RrgOsQ7FUH2OMe5DnBPfYNgVCxSE8879S0AevpwB4ZF0SLx9PQR0zhUDc14fYQ4hNZDRiROTt1DNOAzp0Juv8pYmKgz/ADb1W7KtQLxLrw/X/DsdwBWnOQu8czyhb+IaulCfnyUKsRvai/WVggn7iKHfDiUcR2O287WqiqLkuGb8hn5awWcAELRbLBsnnkDJ7LDB8SK/4k7MtitqopSy8gsnxp0gVxNKtSvYmpOsnXyWRvEhPIz7r5pHyei4me4jAShOL5TIcUay683ZHYA9Xem9CIDH7bzGB+cKPnu4M9Hapg7tgmAlrZs9RY0+r9QmET2c2S6oz7grLmCr3WjtK7N2rcRfzPewyPcR+AcXQQKaXPdTQQ4/0yiAxmC+7Q08lvy6m6ywELQexYd+k+4jlk9NDdRl8kCqjyVEqZm6y2yvczjTkvCNuuZtgWIin3bAIm3yHiWnHpfe40MWPPhzQewVyFIqJitEirRq8RruOWLeHlTRrfnZTIlxWwdKHDA/s1IQUtgrxeex+vww7BQDcHbWNXHXiTS/E2j2xw7C9nxDieDxmPl8b516zyfgQAz4E+tNA5IsQZ3dXMAx44MLGZWsltcpFYnBPf5FivGBR/DaB0dxynoAJmy2IZu1Mh6vJIC9dJOIh3crSqaJ1GYx49Od9siB/pCXRfac2vWI9yPpli+mSFw9aywhm2KPynV+u2z284I9mV1nGj4+R+kSh8MICumJYrVIFLkrJ30Cjvf0hqKuH4k8se2B5Pax6nVcPhPm9A5V+WmLHasz5shY2K/eylZCg+qyAE8ej2LbAmnqF5IuNKSkdXlo3MHrsmO2I3SdQLvAhaAaBLafhnoCvRVoV9uHHwHQEGrH/IaHHC45opp8PKRKtN/2WgPG/ke7pd0LNg5mocHhK0eDlgcJU+CEuPGzLCTDUMCP92a+oVg65YZulRbnzUBx/tEfOgrW+ihlcvCDeC67k5bPw/s5VN7EnGQNNCq7XC7wf0ljQn3Ckl0oFG6CiwEVaCrxAgZPcQO0u3GCy+781vYB7bRzmQiR7P3/rB+GaPaHvS0o4XVAkqYkHp3aDv3e7lyS5RasyMSKOUJTOe6Ryr5lWT9qsPWq1UdqYCVUejR52k24bODJiUTeKhY7XdImMEbh/H7zUgrNcqMxzHNQTYdLrK0pjUzWuIjb1/inSQpM2RUEHxOW4X7YiPWR1nAg7O4TXAePX8AKAFLiBMR+X+f43tuFxaJeNvEthEnkHWsvSoD908bN8RZHkM1MVF2M+TkiUgi7v84T1NrkF4htlaBCKL1WEUJiG2LWY6TTwSl+lqgCg","device_id":"WGYBGBWZQI","sender_key":"Ujw/8UwhbJL/MqP2S8YMS/PID8kyzPOPUZ/gIbLXoSg","session_id":"s8LU3T6qjB2MaG0+jQgHd/F+MNfkn3CQ7Q2O4FX+H8w"},"depth":13,"hashes":{"sha256":"XpcO9VXNJMN1PkSb/cy3CxpEuInBTu/H/vMc2NQOAYI"},"origin_server_ts":1783625469594,"sender":"@ali:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$ZzByIqF4yAyhZDP-bd2SHZXxQ5OlHpoF1y4i0fQps0A	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	{"device_id":"WGYBGBWZQI","txn_id":"m1783625472175.4"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"ZZzj1pfrRd65fVmWrIOxE1ou+i56PnThQ1YDrTApMyBlUEW5PPng0hOFMWKue7oQogpZ8IvrA+AJsXJu1E6ABw"}},"unsigned":{"age_ts":1783625471083},"room_id":"!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","auth_events":["$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE","$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4","$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI"],"prev_events":["$VDxFUMtILxytmO-s2kFHdkmCGyfSuMGfvtuZK6zZf3Q"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgEEoAR0L6TaJDuZLxIOYZ2axrvjPhWl1kUNOGwBGdJNjoElQ299w6iTA9fna1tcqu59RmfLHfhAe2q0RFys15VCNXVL5qC3sDJwtPm9DSR5ui1kNKCH37aKU42NMuS0xeh0NGGqHz1zWTHEL0KiqLATpAoUUPny7QlApd3utFjeAUqXEv3/u+iiZv018tmQQZqrjKyOzXl25KnRja/lup6udMd7hNtMeiLU5FUTppzMWXI6/rX8eM4S7AzQqkn9Y1Vz+qRXiXoAAterde2S7LNO3ZAoDPS6ouPFueob50i7sD7AyXjsQ9lmftcjAaVIUodkSArq/7sBK2ZqYaVTxUdkHx0w7ne5Wwp3yD2VFVGso6Us63eWCV3/faqGs3HHDqfz3AX2LyZ/5r/9m50pc4fFwWwgHxedrghDPBKskmBweGigZtqT6zXNXKeXNzzM1OPd1p6PF3XQR+VhkR/bx9T7bv7WHCNJtGkbwOHLeSNniqHq/y1JJ8ch7TlKEGHi1/Tur7UnDGd4tlyfpL34VnAxegVJl9av1WKIg/vdGfGJLX1X8ZJF59LW1hMhRdy6Z7j1UCBSC3TOup3pxBSDS5DLwjasDnRlq5RDrkW3gK1umhmOepkS2Gb2IZHgOOhN+iEbNCt8UXeX1kfTGLhyX0DaiRqFXrIIXFGILLjYmGrGp6eJog7OSYr03/YBlwNTD8f8EFxEeL0mTqnm9j6flBZ4ykWs3lzo0HWEUSNvtWWgMrhQ2nkJThg3gIlHxfSiUNHjENxoDS1kYWMb7DIM9rRO6I+XXWBus/HO0vf5eIH8B8kgxd+tuQVWUrwOpOQ55BLOwlsDn/F0IiukOInwPJTnGUFUsVIgJZ4q/eKPb23PgsjsnD9hTHOOj05bdjbhl2YYRA54vuI4mMhl8L+uTItqq+0EBEvQXpFx1+M8oC1IY5DSpWwcUdqVscil+i5Anv5PnKL2vEllRiaIyIkn7euafg45QSK/d054JA4mzvoToZGBQoqKFjAMCgvUX2zHEPXZ6U6yHDX84QB6Z8mX+E1h4QS0Np7mqOdfKnT1510zmcFsIy0+1QZ09UhqeMfNvbLKojcYLAX2w/ilvuzC+EHX4+3K39x3pKX22zHGrX7j3ykKwKBhBqV35EJhtmkzRQEIBZRLxD5xDkfx4kUoM+T6HtQISAfh1HAzw4fLox8lln38xpDBdfQnSZ2bo/iiASyf8rpZwxOMVrZz2LTPYnHr0ifWjWKRjQ3bOAg3LAAg32Gj1BrrhjF/Uzp6bAjHvGeslHwEuOTPOoARMCS3ntGDkAyvk7X76pOgE5RtpAQFskP/dXofaf20/fNW/TgUqyNcj1hTyKR3Wicju1g6kV8SiWRppw3GJ20QTJ83RnA/12t07keeECtKjWitrEUrkWtF0NmL7gvWVLPNyl995ZW9q11kXCuLKiD75YjrpkD5wl9ag24omx+TqbzXDpWtqsn9rip5rapqSX6b9UgpbCNrAOO5sZ7kdNkodLyvFhbG8H9EgU9T6GVGMhma0RFZf3j61TFJn/3c0omi706krzBOuvS+rSYrXf+Ad7cXIDpDGCW4YYjkPlWMOwpz4pt3O84wo8oCZ+3nv/i3aXdbv+/XnGnHHEgoygCG4In4HoPsBTYY/xWfvGE1dmYyNp2lC8mVaS0P/xgeM1DpoEIH1Hw3yeICTwUeEMaMRZg+Tj5LGJGRJ/4OaikIALsckolgvriXheD+1maonLxfgYokuBAF+YFdbJdA0yc2S96IWuddknZkTuYJaj5K4vnBiwMDHUF4JkrWTOIv5xSNuwEgGNR1l5x79zbA2FjKMV2U1ORXowfwEuZoaVtQ7kbbzo0nQ1HX+v/KCGV+RPyOcdWSjIBf9v5kjS9hbNoZLEwffCeGmkIl6a0N95glrikEGzQAJnhfVm8a5bgA9f2Med3XSAqexh2vx+kbGKG15inciXwKRVMS44f8CDmhoFxwHZChax9sjb/+MzZ4MSKp0x1BR9+5mxEkHMyM7zo8zsJOiAkngrEOBdRA7F9FkFaER3lz52EhNviaRUFlZwoX3slt4KcQyAtI6+nLo3hGv2JbUYUFhKgvuwAXlX6TUkY3TA7DIuy/4FFGynY0mfLWeSiyM5RyOvycNuqS8a4bCxQDzhOwI0lJolQHysPM2KX5jKY7sEBB63PDlmxwoIXtqzAWUQwSbJsPCXOycRMfl4sholw5vMTigAEbMqZI2LhbCDDmfiaxG/Oxk3WNM6edu45W8aRkw2Upg0fL9kHGzdO78dlen7aNCCP8Bol6I7ngKzM5wN3oCsqW/Lz7HHvv8xnU8RpVe2hone0c5WBrRcoPzJgxOyzBlLtVgkeOBP/p+keaB4So2vKmENCd5LigmmnNj9hQXqB+2I6y0JTxnrNFYdYfgA4JRWNsFNT0GBlOG0DvhJ+jLRFCDeW6lSKv1MJ5YEUiCqZz0PBCcXGBgsXs2KMoNTyC+Qo5DS9iZEzJ4EuU6yYDXdIc1WoklY8p7fDAeS9zRMb9sUxPEHygZfw2ib5JQ9+OevffT7phBOFEGiakLnrtqcuEJRTaZgKiuLW0kMoc8iSE9xpAKXml+OfxnBzGU/jpGZ3vJTHlVIJ4KJR/VjR1hnzIEesiCDZH102DSdQ++ytTabfs7dGUVqb5bceAS4DxNquI5faGUPm2YEa1bXucUO/fbdlLEiwX1Pdq6UOzjoQC2a2CJuLtJprmTSQ3DsQ6flSkGWSrtP0nGBH/0vMhW4I6t7X0eO5Da/nPBhYd0r3diHpJFFdIshqPwf468TiIYRbxF0ei2KerkaD1zHrStMVK/eOiNBi/IR7mytFLVS1AvxpRCsBOHa1vQfyS9xgDr9XchVWzw+IvHgQ3Cb/GBcxr14thygc3SGb6MY/ezt7q8BLngMnT/GJ4RrKbyZDSIB+/dCowvtx8sU51/YjQ1jHv1GTLwiVWAaZDLx1G0DwjT48BMUeAjfOiaYMYi4DBLeqgVFypFjhBg","device_id":"WGYBGBWZQI","sender_key":"Ujw/8UwhbJL/MqP2S8YMS/PID8kyzPOPUZ/gIbLXoSg","session_id":"s8LU3T6qjB2MaG0+jQgHd/F+MNfkn3CQ7Q2O4FX+H8w"},"depth":14,"hashes":{"sha256":"DbvGglaeaNHlRVsRYBRz00BsBh6RP7T6Smrzas/QHtY"},"origin_server_ts":1783625471083,"sender":"@ali:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$O8ybWunHmG8woUBjshPybaeo067xS8r1LX3jsFYbF_M	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	{"device_id":"WGYBGBWZQI","txn_id":"m1783625474016.5"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"ngVF4XMOh90dyqZ6n+7Gp5WWOU3vzDo6XYeQBxqc6okkh9knNbtAyzYU4r2p8inBu+mKFtL5SHx9Pw09dfFADg"}},"unsigned":{"age_ts":1783625472752},"room_id":"!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","auth_events":["$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE","$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4","$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI"],"prev_events":["$ZzByIqF4yAyhZDP-bd2SHZXxQ5OlHpoF1y4i0fQps0A"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgFEpAD01MO1xQeyeS8vAQKhUjDS0rgcOPMww2duhdLgSWtyO//A8XKP5Aggh0Nia/8FgfRQU4m3X6Caop9XhV3LEkFupH5/G21vLu2B1CcM9HIP+YD5V5poOIQW+l2m0sC5TQfDlDrm0bWlOy5xIhyr/fBh+CfQXxllsMN99iDad+d0sDWkb1hgN5f981zJhhxsw4x7RlYMQMTmOg8+4w3WjdttIjUiOF3qriFhxBR1ppVKQlHcGDerRii/v0j30R5II+scU0XpwwVBt3vreR0srM3QGl75UOXl2qmMO3ih1nQc3+n2zMk0//OycSo4nTJ7vPhTGBBlDVJCIqzdx+pZse5aBHROdj/tcRCEW+BSur9UjOLt2lT2a2DUUpV0orhBpgkamhtTcalWTOe5asB6ooW7XM2bA0AsmCB9dCF9jM/vG3gQPJM1HZnYXwM98OFiUnXH54GP3W3l7vFDwZQU1EAfLdVmDL9gcPPTsHqyMD1vCEOpWmL1sHNpdgZy9tfvstNvploaPmRn9BIsjv9gg5hlJWrirrUL9I8hXoIw2ToPoNWa1e//Qb7hOgFry1goGsI5+uGQAlSV87v3yeyzFEi0U8GGG1mWVAe9zSNqAHs/QEPFauOuMwjBg","device_id":"WGYBGBWZQI","sender_key":"Ujw/8UwhbJL/MqP2S8YMS/PID8kyzPOPUZ/gIbLXoSg","session_id":"s8LU3T6qjB2MaG0+jQgHd/F+MNfkn3CQ7Q2O4FX+H8w"},"depth":15,"hashes":{"sha256":"OaFK6fL1Gv2eKVxCC8RQAlFUrLga7O+SyW+oSHrZNQo"},"origin_server_ts":1783625472752,"sender":"@ali:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$OYsK4JS05N5L1dz1HFkKo5nIk3YnZZbM5RB4ZkCos6Q	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	{"device_id":"WGYBGBWZQI","txn_id":"m1783625478826.6"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"EiLpEL+XkaArwsHiTkPkGQUMhEhL1YFz1dGbrlnxy5b0KPio6OR3/3aupKExV/w4FXf/2Wrj6ODRv+x1BzXDDA"}},"unsigned":{"age_ts":1783625477574},"room_id":"!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","auth_events":["$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE","$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4","$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI"],"prev_events":["$O8ybWunHmG8woUBjshPybaeo067xS8r1LX3jsFYbF_M"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgGErABDzC23mcnzoFvrtBFREd3kzzVcz2J5j2GO4rf4Gr8h4tJeNMZ0c0P3ltKF1UuGCO81na7iheBHC4ZH7PoNOeiUZaJQKvfGUUbD8BwM9pBYzkxssK+5ZL+2mnce58vMbEpPEaw6VOOTIrd4sf6V5KZz2QQ7ByRoWydJM+44U8kO6gD92/i3iV2yutynCbNp7Q8W1/os6uOq7YT7b/5aap0WZMybGgt4VrTByfetOsMSe2bcEXqgFd3eZ9Ob8jeDueSr2ZE99LrM0eAwtqR1GdN97HmeFKA+W9mDQUQNpa8PAavZ78wtPQxcwNBOc7wzuz+LFb9o1ASegI","device_id":"WGYBGBWZQI","sender_key":"Ujw/8UwhbJL/MqP2S8YMS/PID8kyzPOPUZ/gIbLXoSg","session_id":"s8LU3T6qjB2MaG0+jQgHd/F+MNfkn3CQ7Q2O4FX+H8w"},"depth":16,"hashes":{"sha256":"IK0PijrkeE013Gc3gvVBo+dSvQ2cX52xvq6z2qsyp0I"},"origin_server_ts":1783625477574,"sender":"@ali:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"wtP072bmgtXkvaf+jrJk5h4CYrslqddSSSgLuII9/nDH2LH8/ndJWZoNAlkJfO8+AnXCIcfSj5IwvsPi8Ob3DQ"}},"unsigned":{"age_ts":1783625679449,"replaces_state":"$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag"},"room_id":"!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir","auth_events":["$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE","$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag","$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4"],"prev_events":["$OYsK4JS05N5L1dz1HFkKo5nIk3YnZZbM5RB4ZkCos6Q"],"content":{"membership":"leave"},"depth":17,"hashes":{"sha256":"9gVKV3PuMkAA7FnEZZ3SPSp6J/OjvjuR0HHcspFRnGs"},"origin_server_ts":1783625679449,"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"@brianrockwell:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	{"device_id":"NFLNJMUACW"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"RHMjMM2DlnnvbAnsORbbtJeTYWXsr6Ep0qTbNsACsOazqvaCzjMLkK3PVnuzsceoZematu1fnO2sY2xdIK8zBA"}},"unsigned":{"age_ts":1783625715065},"room_id":"!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir","auth_events":[],"prev_events":[],"content":{"creator":"@alextaylor98:matrix.shikpooshaan.ir","room_version":"10"},"depth":1,"hashes":{"sha256":"DG6s0lJRyA0ViPgzcjLryC2rCf5sfdv6URSgOujPArc"},"origin_server_ts":1783625715065,"sender":"@alextaylor98:matrix.shikpooshaan.ir","state_key":"","type":"m.room.create"}	3
$5P00VdpT2xziYLl8SJGwC9nL-vpZPERv25JcU1tQEy4	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	{"device_id":"WGYBGBWZQI","txn_id":"m1783626346651.8"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"fUclrpHwTLBllYC9A0DpJcuJomV6X6jIJcx8JuS+nW5jgPo7EKO9xaeNqNO35EfD7h1PtjLh9x/VUCe3O6BvBA"}},"unsigned":{"age_ts":1783626345420},"room_id":"!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir","auth_events":["$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY","$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM","$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg"],"prev_events":["$uMZ-ZidlxCHhXanXLN1-ytrhTVb9h1j1K2u-ZEvFmLI"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgBEtASeE4635aO2OdbIyLzK+Q6+J/s2Dsg0e9ih7+NFDLSlohZ18FRo6ZKH2nUc5+h9Gg4nSYcjkKRws1w031pBRRPNOOANn5yom8xo0g6EtCmzPCBDK51xDwqchNQKoJXHPfwg7JM0iv6JqnseT0anJz9Ke0N2diU3t7GvcJ+AMyvzqXogxnSVMM3YMTCHGd8Yd51HI4bqLPSfb0zSOaRozKNAGMtQ6yBXLoL8tGyqy6geT6XyByrAicwBemg79NtuZ7BqLwXkmKMbMh8cNa1l7RUhgYg++t0iFNKc8Xp3ycH5w0G5WVG+vXXWN+z0scUFV+isDdcT0m/pvVCJWFYeN7LwLi3cXjPiD0cz2kXsCmEAVYnC4twTVyu14DA4VNT093thz8QlK1y2gYkQPJ93j6s4JZYsci01+8CsMJm3ETuIvW3pjhmNffhFA21WCzf677nUo8GXBclCafY84KTK0D32XzAtbJS4eFysMVt0R1ww+YSDHPZfsYr9bIbTVcIg5BhWy7RY7WvceeAzLDveV4otG+ahiTgX9iYl1POGkICJgBJEKCoj3VTW3202z4RZ06yA87eyPypwG4DuBVpzoGnVikrVX+5Z3jy7k2NiWDmxbaigWlW3n2y+DIWc3cr0FK8E8fOp02uJQ4kWj9ab/T4Z4QLfm4OmWX+6O5LlnGRV6gxyrFEYOfOQs5l22wzs4Ej402/nWYyXv0wPNTlX7rmMQvxMuUiwP/H42XeLF79ajmx0n0dlRKcLSfOOrplAk8LvHtKBOap2cbB7dqFV13T15ghgIcisbu+cye789MURw5uk7RJxzbxQMuIPlisgTPYM8Z4yYQVqPE9/9nA1MlLjFcFzoyOWfy/5R6nYidLA0y7ThTlRol26f4nWcc0iLBnML6SITrgXnOcSluSJ+v+xoHOtF2SkP0rjjHZmRUz/b3MHw2/gaqEHu6+SCwejfer8PTSg70TTFkpyhtWn2JNxJOYM+HGmPvwK/fMnB3eX2jp/hv97u/NlR9ysJA65d6BlI9wCz8Z/WEwgcS2tkcZcRgoEkN1KwrgbhAl+eoebYyPH8mFHrzsOVjGZYx0HydE2YBOPMRtd1wwf/BavpEEU3MQ6LmDp4EFWFHfaBgxxzDflCVmTqdjSpku5uuSCaPRYdmACG2YcnfXEICipq53nnoc/nSVDeyeU4zuS3WBvd0RDzcJ2MPGuNWgIcGxHk14tlJ8i/8e3xoEVi/vVK6cwonQAqC0wJawMzSJWnMK5HB7yYbphkQJByZVp1zt2ZjWSxqanxAloWN2Dwze44sPE49NJEY1ytXPFaNHyNHwYj0ueA89hTJC3/ZxoBjEtdO/Tzf7XB12TiYgI+xpq3/8LNA52+ncdxQJNog6s3mlkqInM7ojz56qhD0GAVIWS2dM/ijmi+SuPSMK3CC56HdzImlINjxNEn2REcKVhqf5u6c2LM4Uy7a/3ZR7WsyH3ZTz88MnvkdSOPBYwRKHjLoal0RJSbpBL/zsbWRkdBxo1IQcoWnKNk7ZJHY4fRetyh4rMyBYWGAlINXbYVEfjERSGyU0m1Q5xl1HnkdB4ZR9sBrUn45S6Myyw/LKaJYb+DEyez9100Gz6xJbmDTAReKLdzTjxojlaIrWedPz9S/t2x54eTe1jw6wFfu1wa8q4HkUYAWAILRmHYSc61EUVUrzelr3hiA/7Fwvs82z0bNvJ6PRmoI/ZMoMYcGinMbkOSFWH/VNN1Jqje2AeaAbZXEGhUfW4lvQRFqVDYBvvBzfFGu1MatcsGWyPXQwsdh8QVl6dJE90aZbX2plKNg2BhcrvBipXEyandjQGWNacKGKhFeulrG7ffzQbqAFZfWxBpXc9Et0IwhkkSYGHwr5/G4UJTFKSa/ko08tscKnMyDH0bkQkCrGfOsBNU8e9/ORdLLj644+MF8KcMLOFDN52py6THDM8gtPp5vC8Vzb2fMkTTNtWFGZ38dYs+DvZgk+u+KnZq+IbYvGWHvB7RdpZrC7OddaSN56w8p5VvzQkFNhCjldbwaGMg57Eb2Ucn3ijqTOLd57jgJmS1l+R+1IFwUSahZXXc2BMuv0aUmblOfQoeAnOKk4dn6whufo00OzQMlGikH+5Pj+/6bafUn4qH3GSqjbWJUbSayRYI5MTV3wLHApdwn1hj3JNiotYPUeC5iycJI97tPn5Oc+k220PFA76390dO/6cuSqjjpPylm+fPZw4RipiJQyvMB+NA16w0ipwfWQCsOC9lYuDcf7uqP1yEK5MXtkT8ZW2e7f70iE8ApXKauQrAED+wsAt5NINbZC9yIMAXu+58vCwGXEZQiw0ZEee+lFLaOoT2cFjy4tU8CIG3NF6PX+7G3FIaMGCnDuLoLeWhzDng6O4shmXH13ZdrhByLpl4t4SOeHY0hKDJmu6XutS08lZd6/gyCuZP3ZwjNLHS7VbAlsh10deKgsjOz5rVhIicPa2LRaBCzcaj8s2BlnGTfqLrw9FoqIErbHy5WgQm7JPSQPpGVr0INlimKpMtvqOjoy0+yYw2d9PoHyVUSRiHv7qiwPsi40HuirGVuRPKsBqGE+XsSH8DaBVrK037bBLU2spg0ch22rCQdE5TO85KtnthpxdNKZ9BiuVR1dYm+QWZcZk9FVRtzmFsfopdXl9Hzv/R6eVfAzdDl45kdpV2hjA4Lh4ntXSjYbtDhfduB9VX24EWlfQq/3bZhe5u94RQSIXJ8gB5eXKAYz/16hg4yBLL5prJiSzQNkxowjNqkrJ/hkEvpxTte9xb+6gPUrbUY1jq89htlA6R+Qde8/ea9UqOEffsAhiq/atPH1uy3V3r+6WOaNUeRv/o8lhwsUQW2N4XU96XGSJ7uJ1PSIBEa/DO5d1guStdFwUeqOyCW5qZIRt685VsAn6Oj61sn3xLi45MU71taBImSHDiPOSU0YnFcf+irTHML/5Rb4F9WAl5CQ0IE0Kxwjh97zYlj9T44jh6N1IrdfF8xnAr2O+0G0IcRHinXspGjt7H+Ox3kYTLAxNyFo+OkNu8cAfLp1p523zZSDUxOfVqtsKC/jH6wywwkb8EY5MOe0Zl3FKAZydmAnOAfgjqUYCF4Qvkds+Jt5QDekXu7jV282gURELApSTJeib3qekGhjrEszf8zGbVZyydtNQKOCYUVxqt5Xm4rb0IyIADkdeX9e1H6S6FQ4Qe0geDo89Dy4hL58e9E2fYiZ6A/9gP8tDZInTXQ5FzXTZqsC+dvY8YXbcuhqZk/TekMis8KYyL+Nxqy/lot0WQ4","device_id":"WGYBGBWZQI","sender_key":"Ujw/8UwhbJL/MqP2S8YMS/PID8kyzPOPUZ/gIbLXoSg","session_id":"Zb/DDBAInmrP5eELfi+I9Wk6/w708BumrPMSBy8L1cM"},"depth":12,"hashes":{"sha256":"WSbvik5uvI74dhieLwen+ZP9/TI3WnhBLsVqyJE1Rd4"},"origin_server_ts":1783626345420,"sender":"@ali:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	{"device_id":"NFLNJMUACW"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"n8nqINv7LKsdgSnoX3mvTKM/Tj7ciIPPNJOBjx1naCVr4fxnjQOnGmG4thg0B2iKsBCYLvpiG4rWRtDDyw2GCA"}},"unsigned":{"age_ts":1783625715233},"room_id":"!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir","auth_events":["$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU"],"prev_events":["$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU"],"content":{"displayname":"alextaylor98","membership":"join"},"depth":2,"hashes":{"sha256":"0L9TaAxEY69xJVRpXRLbK3+pc53NF6emnaCg0Yr8Cnw"},"origin_server_ts":1783625715233,"sender":"@alextaylor98:matrix.shikpooshaan.ir","state_key":"@alextaylor98:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"Gbl2wWDuO6Ay36p4i0l9pPx0gN++gVfB2Oc3POfIpB4+qk/ktNFDG0VSBo+xfti1k/ldDReY0UnHoontdyWkDw"}},"unsigned":{"age_ts":1783626314313},"room_id":"!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir","auth_events":[],"prev_events":[],"content":{"creator":"@brianrockwell:matrix.shikpooshaan.ir","room_version":"10"},"depth":1,"hashes":{"sha256":"9Qz65KG4kcNZdbL7s5GEZav/HzYz1GHZV1XUs8/SVG8"},"origin_server_ts":1783626314313,"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"","type":"m.room.create"}	3
$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"Y6wBQLqFNrpLOqRlSxzo6nVjKlElSPpNwAzQtsePQB3RM7qEvl8teGnTBvB+exDM4xG6ijYjaoIwReELJiLYBQ"}},"unsigned":{"age_ts":1783626314534},"room_id":"!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir","auth_events":["$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY"],"prev_events":["$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY"],"content":{"displayname":"brianrockwell","membership":"join"},"depth":2,"hashes":{"sha256":"OC5q7drkZQ+389oFPW4rigTdtoIRR87MB/sOVjGFTfU"},"origin_server_ts":1783626314534,"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"@brianrockwell:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"RhygHNbSpkuIzJrwPZzUJnTRmOKaspYc6oh1u3Zc8z9b/ArZP5W0es5g3u+IdvCQlcpGVRi46jpGnbLGZ+aBAA"}},"unsigned":{"age_ts":1783626315047,"invite_room_state":[{"content":{"creator":"@brianrockwell:matrix.shikpooshaan.ir","room_version":"10"},"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"","type":"m.room.create"},{"content":{"join_rule":"invite"},"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"","type":"m.room.join_rules"},{"content":{"algorithm":"m.megolm.v1.aes-sha2"},"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"","type":"m.room.encryption"},{"content":{"displayname":"brianrockwell","membership":"join"},"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"@brianrockwell:matrix.shikpooshaan.ir","type":"m.room.member"}]},"room_id":"!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir","auth_events":["$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0","$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY","$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk","$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM"],"prev_events":["$JrVCAJ9f2DtGYEV120F1HrAvVIjWumvsdBmenypJvNY"],"content":{"displayname":"ali","is_direct":true,"membership":"invite"},"depth":8,"hashes":{"sha256":"4nPgrPA2NqbEycnAYka7zJeF4mObEp416cyQS7P4790"},"origin_server_ts":1783626315047,"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"@ali:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	{"device_id":"WGYBGBWZQI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"rtOjpJv+hY/RiXnGBh3JzULPARC6VgvuESM2hioNftIIYY4OeiJOYaOPn/FjNonkNn8kCdU7NTO4O5SvG8eUBQ"}},"unsigned":{"age_ts":1783626325202,"replaces_state":"$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I"},"room_id":"!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir","auth_events":["$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY","$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM","$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I","$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0"],"prev_events":["$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I"],"content":{"displayname":"ali","membership":"join"},"depth":9,"hashes":{"sha256":"BNZJ+x71Z7OIEFF4SCH9bInhL/sMnlXHpTfOnvKVOBQ"},"origin_server_ts":1783626325202,"sender":"@ali:matrix.shikpooshaan.ir","state_key":"@ali:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	{"device_id":"OFUSOVXTZJ"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"UB/e901+8p6xea0upJ1RDL9cQfJMyENhfUm7W7Q2pJ0PEHpVn0rtojsAwc2KlDc43zH1H0OwDK5ead7777ewBg"}},"unsigned":{"age_ts":1783626825536},"room_id":"!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir","auth_events":["$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY","$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg"],"prev_events":["$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY"],"content":{"ban":50,"events":{"org.matrix.msc3401.call.member":0},"events_default":0,"historical":100,"invite":50,"kick":50,"redact":50,"state_default":50,"users":{"@alex-taylor:matrix.shikpooshaan.ir":100,"@ali:matrix.shikpooshaan.ir":100},"users_default":0},"depth":3,"hashes":{"sha256":"XzEyU1OLFcoK2oVInKaPWG0X/jwTR/eoD9Uyv4oXr8E"},"origin_server_ts":1783626825536,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.power_levels"}	3
$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	{"device_id":"OFUSOVXTZJ"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"gtOsT+vMZK6ot68l3kbGFvMQgNsXatXvHJ9idPhJaIEHxadeYqgclG6BLe5q2KTN/Fn4jVDQ4S/aniJIqRSKBg"}},"unsigned":{"age_ts":1783626825595},"room_id":"!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir","auth_events":["$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY","$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw","$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg"],"prev_events":["$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw"],"content":{"join_rule":"invite"},"depth":4,"hashes":{"sha256":"Xvu1Ky+YI6KNUgB+uQXbhJXmv8T1jH231ql8MPddqdQ"},"origin_server_ts":1783626825595,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.join_rules"}	3
$14g0e4tQc-4i_Vdo1U2pNGwl-QbxmmrnRRA2DOZjnYs	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	{"device_id":"OFUSOVXTZJ"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"Bt+6X8qGRpzhogjDyOwa79np/uwZLGmqx4ANKw4z6WqDQIOOlpgqAroVFAXoN0znIOb6XU47nYWWO0E7gOd0Cg"}},"unsigned":{"age_ts":1783626825598},"room_id":"!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir","auth_events":["$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY","$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw","$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg"],"prev_events":["$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI"],"content":{"guest_access":"can_join"},"depth":5,"hashes":{"sha256":"W7Ix5vRZPvz/lK146s6aNEGSCAlyeFL9hmmrU3GhL6g"},"origin_server_ts":1783626825598,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.guest_access"}	3
$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	{"device_id":"NFLNJMUACW"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"WcNquO/xqPRQI5YijRpvJAi9EypLBHuxjmi9NlZztTPe6d35O92C8f/QQHcEqz1s1ggIRsgsvWMqxiO+Ks/MDw"}},"unsigned":{"age_ts":1783625715407},"room_id":"!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir","auth_events":["$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU","$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY"],"prev_events":["$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY"],"content":{"ban":50,"events":{"org.matrix.msc3401.call.member":0},"events_default":0,"historical":100,"invite":0,"kick":50,"redact":50,"state_default":50,"users":{"@alextaylor98:matrix.shikpooshaan.ir":100,"@brianrockwell:matrix.shikpooshaan.ir":100},"users_default":0},"depth":3,"hashes":{"sha256":"3hZHKNdskgphvC8fe+wBXzQjXHGO2bL0CtNrfmKKe68"},"origin_server_ts":1783625715407,"sender":"@alextaylor98:matrix.shikpooshaan.ir","state_key":"","type":"m.room.power_levels"}	3
$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	{"device_id":"NFLNJMUACW"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"XqU8SRHtSI3oLW2XII53FO5xA58XVENB77GeqHzlOU5J1j8uecLaYb+u0J89IWmw76KKlRiB7GpQK0QpId3dBQ"}},"unsigned":{"age_ts":1783625715455},"room_id":"!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir","auth_events":["$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU","$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY","$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo"],"prev_events":["$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo"],"content":{"join_rule":"invite"},"depth":4,"hashes":{"sha256":"fcMbwhJNr1LK9ZfOnrolQeFuauG64i7TsHJqq3p4P+Y"},"origin_server_ts":1783625715455,"sender":"@alextaylor98:matrix.shikpooshaan.ir","state_key":"","type":"m.room.join_rules"}	3
$pR2OnVDcJjiIYWrhS9nEoocIiQESVvpdsQfYu64Jhp4	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	{"device_id":"NFLNJMUACW"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"KE/p16wokkbtSdWUHJ/aqhlxoUleLsueI6htBMnu0RjCJNVOsuIW+uLVjQOLeRpEMQekvW0SxrQccuRplHPmBg"}},"unsigned":{"age_ts":1783625715457},"room_id":"!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir","auth_events":["$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU","$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY","$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo"],"prev_events":["$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M"],"content":{"guest_access":"can_join"},"depth":5,"hashes":{"sha256":"oXtRkf4u+TkER4V5Il2J9Y2bgjym533hWbbBI8779YY"},"origin_server_ts":1783625715457,"sender":"@alextaylor98:matrix.shikpooshaan.ir","state_key":"","type":"m.room.guest_access"}	3
$uPRJ79eQQkEtz9GsgfXr0y-f3JPTNkvLdecu65l13Eo	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	{"device_id":"NFLNJMUACW"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"24TZ5i+2HvFWOC2/w4zrr9h1bHGU0TMgfR/JiorTcUKyFZ8VjPThELqhCwiKTwdyxeckAQLV5JIkCIfm+iADBg"}},"unsigned":{"age_ts":1783625715459},"room_id":"!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir","auth_events":["$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU","$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY","$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo"],"prev_events":["$pR2OnVDcJjiIYWrhS9nEoocIiQESVvpdsQfYu64Jhp4"],"content":{"algorithm":"m.megolm.v1.aes-sha2"},"depth":6,"hashes":{"sha256":"RHRgBhN6YU7A8hVPXlXcv0gxZdvyBnXmlcLDUXfqPMA"},"origin_server_ts":1783625715459,"sender":"@alextaylor98:matrix.shikpooshaan.ir","state_key":"","type":"m.room.encryption"}	3
$h_Aewnb-d3kjnDHdRL1B_3KhQvXaRyb0xNw9N0ctEUM	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	{"device_id":"NFLNJMUACW"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"1eHCKqgKZOprP6FDTHUdu984Iwjk8nXEoZYvNbLEjYtc7f6C8NuKQqSpOxFyOrKlUdWiOYlMTnsA0qNP+jCpDg"}},"unsigned":{"age_ts":1783625715461},"room_id":"!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir","auth_events":["$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU","$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY","$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo"],"prev_events":["$uPRJ79eQQkEtz9GsgfXr0y-f3JPTNkvLdecu65l13Eo"],"content":{"history_visibility":"invited"},"depth":7,"hashes":{"sha256":"bDGsdkjtpnojwhL4eqJVpyo88B1Q5YQpHTlPOOWonR4"},"origin_server_ts":1783625715461,"sender":"@alextaylor98:matrix.shikpooshaan.ir","state_key":"","type":"m.room.history_visibility"}	3
$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	{"device_id":"NFLNJMUACW"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"xFcbG0CmHjU0PQkhbAkrBd50woMECcT7RNEfU1XKgkX/py5ZB45XpOumaX0/QsHtIzi4bUqFf0pLRanrP+1ZCQ"}},"unsigned":{"age_ts":1783625715800,"invite_room_state":[{"content":{"creator":"@alextaylor98:matrix.shikpooshaan.ir","room_version":"10"},"sender":"@alextaylor98:matrix.shikpooshaan.ir","state_key":"","type":"m.room.create"},{"content":{"join_rule":"invite"},"sender":"@alextaylor98:matrix.shikpooshaan.ir","state_key":"","type":"m.room.join_rules"},{"content":{"algorithm":"m.megolm.v1.aes-sha2"},"sender":"@alextaylor98:matrix.shikpooshaan.ir","state_key":"","type":"m.room.encryption"},{"content":{"displayname":"alextaylor98","membership":"join"},"sender":"@alextaylor98:matrix.shikpooshaan.ir","state_key":"@alextaylor98:matrix.shikpooshaan.ir","type":"m.room.member"}]},"room_id":"!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir","auth_events":["$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M","$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU","$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY","$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo"],"prev_events":["$h_Aewnb-d3kjnDHdRL1B_3KhQvXaRyb0xNw9N0ctEUM"],"content":{"displayname":"brianrockwell","is_direct":true,"membership":"invite"},"depth":8,"hashes":{"sha256":"S7td3ipbbsRKOmhlisBmWg+6iUZzzO2/rWG/X0dLj3g"},"origin_server_ts":1783625715800,"sender":"@alextaylor98:matrix.shikpooshaan.ir","state_key":"@brianrockwell:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$38B-Weejbpnil6mQvy5fn8Vc0qGoDasfdZ5t3hdt-u4	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI","txn_id":"0c247a25a86541b4a07ced0f842210d4"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"CvSr3VhsbRrQCQXpqIG1VtF04wpOu475sN/n64hTUBPiUf0yHJ+2O7ZfXdmjq4LExVx8O0hnOKpYBAM0jsyfBA"}},"unsigned":{"age_ts":1783626337459},"room_id":"!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir","auth_events":["$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY","$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk","$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM"],"prev_events":["$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgAEpABJQOoOrCchHqwa+kXsVGhh5OLzyy526bZztgFREFWOoz2Ibf4Tl1QngXHSnuYTncTNPlT9O/MmlF+nl5AIy75of0yLfmfvCYOjuRH+0JDza4q9NkNEHyPEYlpwzSRjMjx9sUejiKOlXQnboudfiB1L6FJ9YhFnFsNVMTKQ4+cuwqekKv5Qfs8/cF0JBNkaGzLrrPvUtruE5Fsi9WLv0zdnYYGuubeFD/gUT+euMAe1OTAXbY2LwHnGg3UTHU1uJJxNFLo+S7IqVoKdTCONczhS+mT5MZHkm0H","device_id":"KYQHVGSULI","sender_key":"UIpQHHKPG6wIRXbeXPOIYDVgWXsovOBpDsEYwuB3rVQ","session_id":"vWRYp1WXj+N89r+Rtpd/f+f0Qf8ULvh5BSOrFB9GMjw"},"depth":10,"hashes":{"sha256":"bHVXoB9zOIpF849Wexgj3dK6xm6iGVJB7Bfx8jnheqY"},"origin_server_ts":1783626337459,"sender":"@brianrockwell:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	{"device_id":"CHFTPUHNYF"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"z9RsJTuzi/ItlURYXCfGEQaDx1t4tY9qJ7p1jrSq+RW0sMydLLM69ktCN0oHen/wzf2POaYyWTU4+mQIgf6sAQ"}},"unsigned":{"age_ts":1783670156780},"room_id":"!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir","auth_events":[],"prev_events":[],"content":{"creator":"@alex-taylor:matrix.shikpooshaan.ir","room_version":"10"},"depth":1,"hashes":{"sha256":"55g8cjJKXLV9nYgQ8rYIMyTAT1slHCyAihpGM3wVrm8"},"origin_server_ts":1783670156780,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.create"}	3
$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"JtPk+obONqhhSP0lGzTb3EVmln2H03nhX01ZSnrmoJT1Pij1oD4G3aV5IGbNsNyQ9UcMxARguKwc9RsqV8uOAg"}},"unsigned":{"age_ts":1783625720630,"replaces_state":"$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU"},"room_id":"!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir","auth_events":["$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU","$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU","$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo","$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M"],"prev_events":["$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU"],"content":{"displayname":"brianrockwell","membership":"join"},"depth":9,"hashes":{"sha256":"r3gAhOJP+FYjnYdtt6QPfRFWDpjl16qAHdi2Oo4ubgY"},"origin_server_ts":1783625720630,"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"@brianrockwell:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"dbNtNdQR8cQNjeiUiCjLLPgbwd3DZfR5flnX8Fkqo/J9x2dPCWO59Xv/WLawRI+wR7a6iPWhOBJwRWjNPKVFAw"}},"unsigned":{"age_ts":1783626314694},"room_id":"!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir","auth_events":["$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY","$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk"],"prev_events":["$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk"],"content":{"ban":50,"events":{"org.matrix.msc3401.call.member":0},"events_default":0,"historical":100,"invite":50,"kick":50,"redact":50,"state_default":50,"users":{"@ali:matrix.shikpooshaan.ir":100,"@brianrockwell:matrix.shikpooshaan.ir":100},"users_default":0},"depth":3,"hashes":{"sha256":"i7cNahPm0c0LC7d4x2GCvHMgQ/p3XrFWu3Zv9TiD8pA"},"origin_server_ts":1783626314694,"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"","type":"m.room.power_levels"}	3
$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"ewVD8JMQn75HF9BnjAY0HhonytnKg6LkcrFwCI+91I19ayOgSB5yfqO0eWBeOU7S9xYSCPZIjYVdleYFJlp7Cg"}},"unsigned":{"age_ts":1783626314739},"room_id":"!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir","auth_events":["$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY","$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk","$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM"],"prev_events":["$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM"],"content":{"join_rule":"invite"},"depth":4,"hashes":{"sha256":"TuEeprEFMn5YdNjfBBV7GbSfJ8Dw8QVoIXqu7vcYLEk"},"origin_server_ts":1783626314739,"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"","type":"m.room.join_rules"}	3
$VWhXTrJ895IdYCilHYuIInhbeUE8rsIzTWUjb7gSL1M	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"MwFn+Fju5znrB8CRC4NsH8tqT6I4eeDoenVoXIERBsMNhnfoS3EpaD0s/e9DZSyTnHX0sSYn9biDzQm3HDqvBg"}},"unsigned":{"age_ts":1783626314741},"room_id":"!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir","auth_events":["$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY","$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk","$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM"],"prev_events":["$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0"],"content":{"guest_access":"can_join"},"depth":5,"hashes":{"sha256":"6P6wC1teX7v1aNdDNPeSGej3Q91wVUAw7RosDEMYN+Q"},"origin_server_ts":1783626314741,"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"","type":"m.room.guest_access"}	3
$egxiNGcQc850qQa01Ox8mP5yoEj1Q5Ex-bzUWtN4W5c	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"loBST9gSp/fZRr/BZRALhYuvUubkC4E2R4EjfPKqQToNvNiC4PqimbSlxj9zDAcaMOBqb9ntENU7f64a7GSmBQ"}},"unsigned":{"age_ts":1783626314742},"room_id":"!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir","auth_events":["$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY","$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk","$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM"],"prev_events":["$VWhXTrJ895IdYCilHYuIInhbeUE8rsIzTWUjb7gSL1M"],"content":{"algorithm":"m.megolm.v1.aes-sha2"},"depth":6,"hashes":{"sha256":"f5sGzDevQIKOmqDCCu+qKIbRzv0Gk7thZnVCDCSYoH4"},"origin_server_ts":1783626314742,"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"","type":"m.room.encryption"}	3
$JrVCAJ9f2DtGYEV120F1HrAvVIjWumvsdBmenypJvNY	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	{"device_id":"KYQHVGSULI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"E6c9knfv6t3oMHklJl+GJh/3qo728xOwM0v20y7TLjdOGmh/7i05MytxBjHwIav9WM4vWla4QaJ07j9bCOyeBg"}},"unsigned":{"age_ts":1783626314744},"room_id":"!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir","auth_events":["$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY","$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk","$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM"],"prev_events":["$egxiNGcQc850qQa01Ox8mP5yoEj1Q5Ex-bzUWtN4W5c"],"content":{"history_visibility":"invited"},"depth":7,"hashes":{"sha256":"cd579j2fX0BjhaMJHD+WIqOXUGS+1p5DUfd7mU7T2s0"},"origin_server_ts":1783626314744,"sender":"@brianrockwell:matrix.shikpooshaan.ir","state_key":"","type":"m.room.history_visibility"}	3
$uMZ-ZidlxCHhXanXLN1-ytrhTVb9h1j1K2u-ZEvFmLI	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	{"device_id":"WGYBGBWZQI","txn_id":"m1783626343644.7"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"Mv/fB2hZ5LS0bkmYJgbcgEPW0NouoGc980JrdSB9ftIxXPhKDBBn3XE2GoEB5QpkDMx6eikSj6AY7PnlnDSEDw"}},"unsigned":{"age_ts":1783626344136},"room_id":"!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir","auth_events":["$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY","$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM","$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg"],"prev_events":["$38B-Weejbpnil6mQvy5fn8Vc0qGoDasfdZ5t3hdt-u4"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgAEoAO8R3Yf0/SQav8BOLl23Syibe9PuG6xw+PkVpn/Oxoz/xkp+mabFowLAVzuQZt5S1JQCsIheedraJSk5XGBmM67yJpRrWaXY1i1tqAi3nasxkwiS6gvXTpxcqiPxUMh/6+UzrQ/yU0a1oTB/B/nSr1Rxreuke5Hc1wFgwcwUFcGmgb/EUE4t/YV1YXAGk+yXOZT0O+mV+8q6NblXpcsUMcW7aVfd+w/28D3a0NRXYyUfTPdN1LsfWQHgfDQmY5mQyAJlnT4yZVeuD++PG0VQC/WmyfvbK+/Uet7ElayinZ6bF5Exlqg1U7sfB4x0a4pI9Z6tTYoxKVpsXlFgOFL3g8hlyxFDELPjBLbX4y1iNuHZSnQ8Rov5xnwb5LyROL5tHFHlyCth12XLqLYSS9kImtNmBX4MRnONddg9C+vvLQJBL6BTFgGb+w2Qn69hY1p2ilF5NiIKYhov1peg/KB8okJmtSYMy/DVMCoZp26kjrcbi6lkFUQu0z0fIQjAfaw7Hh/9tgWUL37QlQplqGzNl7Usul7T1gqZVcDQ0eitk/9YirQNBd2aCgIoPF0ZvcUXHG4K67XNf8AxPW15NHMO7M04uABMdts2FFyrKZq7ngM0txiwMxXzW6ucRAfCVLHUEWss+8be5zzCpN//imAYoavEd+gYgMzrTEz5ERju8i7DGGuL8QInBi1m+2tO29Q6QOPj/a066SJM0+IczNc7c75uj2g3wFDTQHQkjmWGcOlRlrOUNrnJ/Qb//UdOrQrf2OmysvE5MYi2KWGUf6CMRckCDTg7zQR9zBr1y6pcdCFBTtBXmoLURUxZvi8VXfeSZKA6+dl0uxlkHYnVtn75g1xY6aFbenWOMHmGnGY9Iw63XfJ2+POhEbXUBzS+tu2fKmox+cBqv30nL3yMCfDLaDCK+7VD4Bw49yna7EwuLqiwA569m+mUChIKWMNOp32vp6BUd6ZTqgYvwHeF1kn00V5u7G25lSBsniGN/ljKgh0Vxm8tp16Jr16y8sEud9QwXKqsmbZsjub1EtTy80B5xtewEIRA7rtj5mAg0NapgWaU2c9bK/F1xPHXr5CRJmFnqhWUVuN8VPbeN0TsrIvZyFREVewE61vB6JFP+r3ycFD2nGQnziEbbbbsIIrmQ2aU9WU27ZgrHJrzRxLfA2yxeUPXiCnzPcxANs6JUhs7Ghn+pH7vjUQuQsusAUp5gns7g7XCoSEeWEOPDStlw2T6blwzBjg459UNbHBF6+umRuhxvbz0QZhHxz3ATBZCAn/1hyB22m1S1JiKjga54TVldatg5afSSwOZVIGIe1VPwgfQL9yDgU/fCeOeZMAg+bRhlpkrFbDci3C64IYmACCa0AbIhe72ajQD9w+rhEO/ihN7Lx5V3pyoR2zBsuAWoWaQbHlYsVlDyHqawRpn2+2+q5v4ob5PgXIt+XiHcBXhwGRddraX+WUWuOCPBq4h9oWfh7RSCmK2etysG6xb34BlITHCxv2ABM1wwNEhjdw+QXiM9vXKXSLqjI+TZpVkiKVicJVG1xpev7LqEcpHYoRo36kB3hFXAyIghFHqLDIemwWsc+nwNO6HLIqiVu8dlpIiAHxyLjajuWeecqMITAmGXX8BqNq2MMWD+nqbkiK3vihKXUzqmm7DWCK0H2NTXtcu+/75AuLDAeLgkMS/BjuDZBZpDLN+CAXKHh5/neRN47q625m0KdFPyTe1A8jQhWonPbHvb1KlZbV2gJDaluRrAds46XdqHnXLE5HAuZ2mWLqGwGN/WlxQp8GaphhVt/Xb4paageFXi4L3ScCkRMqsjjqywbn3X+Z6rkzIWWtQgYoR4/47PwHEPCjJ/zDzRIsf4YerESFn2+6/muTIZcPuMKrHs200T2PEU0/fEt46AS5JQt67eKqZUnoK5xFDNYDFMwHchsBoDqJvzbs/4S+gYwsiHKYXk7FIn8XB0qu6e2jw8dIMYMZ6K8Yhj5FXC7Kr2AtSeV7ap5x5tuW+Go+olsdhUBFJUoplsC7V5vBoknPgcwoYIAfaR05xXcW0+trutyrHQ4mxFJK7glTE2av4yxUfegK5d9Y2zqM2emuSyuH8s7CMARGs6Kx9e3ph1cmyZeglWQmJM5ATf3VVlvUGC5pGq8dZcH6cjmpKeY50ftjKXCvtJYU552W5owAktlZMKYALPwszJDFQkHB8Zo7b9wYQipSdeAptGRwhBpckcciITVFd+zvkBWL4lHyxtveeZ+xTPBMKh51XM2TjEpDX+0JqopxWUz5CsJ95byhcc3IoBba6Xvj61+Qe7VxpwcwhV9ESMQdd9dAxbp6AFw7/f32iEITFfjfrbkesWKy/f290TGYaz8bQQJNR9SirOzt5H5UIchHiSRuDwx9DXo/KaNk+jB9rJpiMIHS84ghGY8UY6rHStpMm5iPeITjLtBaKqZOPm9bE2k/uQhYZYE7i35uxhlTXHuj+hpl5lfe5vLUQGWCRTepguZCg","device_id":"WGYBGBWZQI","sender_key":"Ujw/8UwhbJL/MqP2S8YMS/PID8kyzPOPUZ/gIbLXoSg","session_id":"Zb/DDBAInmrP5eELfi+I9Wk6/w708BumrPMSBy8L1cM"},"depth":11,"hashes":{"sha256":"3uXRfckjK40AW1odZlJ7ZjriipfZiJvwXyb6+z52h2M"},"origin_server_ts":1783626344136,"sender":"@ali:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$C3PYkudwbc1C1vhjMWGEuUhQS2SwdWK2dFzNgexrfug	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	{"device_id":"WGYBGBWZQI","txn_id":"m1783626357317.12"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"R2p2oNkYE7ol7wb1j4uzxXnbIGOR5NSNQPufeNO4OTEpa+nRLUk1P8QwvEJznnslnRtgZF0sr93Wv8WfQYyBBQ"}},"unsigned":{"age_ts":1783626356069},"room_id":"!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir","auth_events":["$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY","$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM","$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg"],"prev_events":["$MKIG_xPNWt7pAeRQie1-ff8u79mcVuNrOYFINP7GYb8"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgFEtAC3ljIGpX8kzclAVvrMNa/gJpMHDH0YcVRQZ34FspDTQkVWfKWWWiFxSF8A5luHReaxX/sRnmHC/KvQqq/Xg6LwLoqc6zWqX6gc8czOyq/hdWNCiHPwcjZDtNHSVFrW3PWgnWMagbYoE4u+WwVm/NLQ0BagNO/l0+u/dj9cgQkHStVan8WzG+ut9k5UYGrmCghVBjdr1sI+SyOxWDs3h6irqmiqkqQ++ESIDwY1od/MNVNA3WUJA8sB8Xtz3Lg9X2kumgLRNXZk4+nq9PGqMWo07F7T51EwbpjeSK8aovI4XjzFJHBvj0XixVeF53nbU9oqi2n5IpQ3KQv4jTpu1npvJ5krDGEs2hvLdTu6Kdx04P4voDE0os7N6vNR2LNz1HnwRvVi0B2aEPqR6peJKmLzoQkpH/fqoB2PWi9VMIHnvpgY8iPbnVZTJquuaICZtpDbNojopHAUoRKSxzHDiPo8QFG4ljM71GdItAtFsSQwJ/sjD10aRDI3CEpXRETV/8jBhJF0J/vRCkEDXABasEEGBlgjO9JrYYI","device_id":"WGYBGBWZQI","sender_key":"Ujw/8UwhbJL/MqP2S8YMS/PID8kyzPOPUZ/gIbLXoSg","session_id":"Zb/DDBAInmrP5eELfi+I9Wk6/w708BumrPMSBy8L1cM"},"depth":16,"hashes":{"sha256":"y3tj+fuzbMuGpZxZRbnFAims2iaXWFhM0LIUZQFWmFg"},"origin_server_ts":1783626356069,"sender":"@ali:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$bJp5268AbMlSvGSOLwL1QuROb-6Q8w3--hz5R4shhsE	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	{"device_id":"WGYBGBWZQI","txn_id":"m1783626347906.9"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"2ToV+Xc1mUm9NNWJKK7n1axBI3aQj00WoL2exSz14/v7t0aGFjwtDUESfU5w2fsSGF2tLB3JAzQ0vuteu2uSCw"}},"unsigned":{"age_ts":1783626346650},"room_id":"!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir","auth_events":["$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY","$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM","$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg"],"prev_events":["$5P00VdpT2xziYLl8SJGwC9nL-vpZPERv25JcU1tQEy4"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgCEpADu+zj2yuleAuDF36Lh1xKq5mJklvql6+a421VcoScp6FF3AdRM1k7TyZ7KynKsr06+I8xRklir7hKQIuV3wU8llSzc9hM6hWwZ1Nhem/9ot6UrLMlHcBq2IBZQYrA3/59QhwHlntfMaKllWcGSELd7ahclGBY5EMkcfTt8EGstWVyTlHfgte+wPjMpcN+UyPKrL4YdRfo5HMn93dwT3DTWdHT0827CIpPD0dAPmWLjUCQcbJOmQVaKAIAgJ8fEdw5UG7UujXdIbPNg11tlR1pczOewjBIZ5hAShcRSa4gm+KyouMlOx/pCMYnTrbdhmXDys1husOOCftlupI77+NlV6PDQAOeBkbbtz7S2QjbBvb6Cnrsi5h094cZn8RiGMRmVKJbo1YO3V4J8U+XnyggsuW4a2SR6wBx0LhQGF7q3b5dlLFj1RB8pw1VO5R49WR9/M1ieaG9TKif1ueWcF6dvCrLZz9arVO/vRh5+ypQ659uAehSNEX9/ZxWbXu4LUaJ8S3fXtfBzOY8tDZhjgBxz6kmGpeXSKREJtlOFm3FrVCU9OBEkzbSeN9mXnVaGR8i+Qc8mITb6jkOdJ/nh7ByQgRr3weGqGPYq98dpIfB6w+qcZON8A6eAw","device_id":"WGYBGBWZQI","sender_key":"Ujw/8UwhbJL/MqP2S8YMS/PID8kyzPOPUZ/gIbLXoSg","session_id":"Zb/DDBAInmrP5eELfi+I9Wk6/w708BumrPMSBy8L1cM"},"depth":13,"hashes":{"sha256":"uL9H4OEAqtu+YD0Uxpo3W9YurduyEG9qfjg4LMPYzqE"},"origin_server_ts":1783626346650,"sender":"@ali:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$nX0BIvxzfiMjoGPKmnp3zaDJ_Lwe4buCfaVfv4wKHAA	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	{"device_id":"WGYBGBWZQI","txn_id":"m1783626355557.10"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"6gXZkLN8G2yN4RYuUCwzlLRwgRpajaTOXV2wYsAMmG6FHUU00dJu8uqpUHKiWX8/nEZUy2zIdwhktwygu9D3Cg"}},"unsigned":{"age_ts":1783626354283},"room_id":"!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir","auth_events":["$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY","$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM","$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg"],"prev_events":["$bJp5268AbMlSvGSOLwL1QuROb-6Q8w3--hz5R4shhsE"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgDEsACPgX8cmzEV8QYbUPkOclHzwdNmB28AYPaA0Jw4O9HGw6X2T/A29t1/venAqQH4Xr1XwiHyTtHik2qLrIH7VDLPh8Oj6ZoZB+CkkBcmm1uKNLAyKsjitP6JFfhV+2ip8xUUkVf2nfemoM8N0GVOwVFc0pRGAi5sIabKE0sBZrS4TWRMv985kTdOZQ4NPRY/byfQEaH66YT+uDcZrc4T9lPZymhYZthgtETcr2TfmTof1C3Fw1k3EVPmVhvMYvEz/mHjpmDP/bISEoPrJFwekgk4VyidS3mtYoHeWpn3mBUwm3ZpqOsgTVI2UP0PY4FmDpvzzKTdDEym6jTKYdszMfhInENOpeNuKAcrrSqovIoxprvYXTByyxakngj/DbmkAwFBoMXWzyjZmePSEISPSns+OBRamCocxFyqO+P1pxbXLVwFzlaUA81fp013BufFbQszPqVIKzihNoFKKXY5UhJ6YaT3u8DYtduRFsao2AYgRu3db+LbMUk7k4b3J9N9BUgF52DFwVXxgU","device_id":"WGYBGBWZQI","sender_key":"Ujw/8UwhbJL/MqP2S8YMS/PID8kyzPOPUZ/gIbLXoSg","session_id":"Zb/DDBAInmrP5eELfi+I9Wk6/w708BumrPMSBy8L1cM"},"depth":14,"hashes":{"sha256":"woFOLk0YUmu4N1N9yLiRD5f8Y8AOwOxtzOhVgqnIPfU"},"origin_server_ts":1783626354283,"sender":"@ali:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$MKIG_xPNWt7pAeRQie1-ff8u79mcVuNrOYFINP7GYb8	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	{"device_id":"WGYBGBWZQI","txn_id":"m1783626356612.11"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"plZ/CFQHsNAxvefJ5BZdzhcqsSgvhzIDnr1t+c427i07UCJWRMmDXkXVil3G047iJQ8m8NGdLpjbHPNYEuhbAA"}},"unsigned":{"age_ts":1783626355388},"room_id":"!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir","auth_events":["$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY","$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM","$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg"],"prev_events":["$nX0BIvxzfiMjoGPKmnp3zaDJ_Lwe4buCfaVfv4wKHAA"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgEEsACzCBzqzNvm6Acg3fNyj5YoCGF3tH5btCwIsiedy0R3k/2hrSXMFdqqO6DB9nTpWvicsd832x4GuK0YIHmVv12OeJUnUQ9x40kNBzR9h02LokFhPPV9YSm/oD6WX/xex+bTQKN2BznDjSv66uBx71Qc4wMrmxIMTotLX4N5CwKnY6e70pVJm1h4okTK8v+MXWGxUCg5SglWntpU9oWHZKSB/58wlaUBI/Ps2E1ewIvxMfBa0BH+gwPAh0hUmDwe+0X4jmf7ymNbEZ4eaRjS5OchWyTfGwZ4FJMFW9MwhVYiTA3+f/6TCVkLukPK+9+b1VvAP89NlBDthbVz5w8RsgK4CG5MIY+p9yrleWBmRKB/l298VOJpqyI8PiVzT1v+mLKkSS8namtVgXONrv+L/s5ssxgcCshP6UEgurgBBDJtbclcoeBXReaR90RaTxoBXfb0uGVr98qP0WHrAmG7f9Tdh7SpA+3rw5jo+ljdh/Zv/mvYAI7YhsDxfKZIP+c7tLG2hCZ7/tRmg0","device_id":"WGYBGBWZQI","sender_key":"Ujw/8UwhbJL/MqP2S8YMS/PID8kyzPOPUZ/gIbLXoSg","session_id":"Zb/DDBAInmrP5eELfi+I9Wk6/w708BumrPMSBy8L1cM"},"depth":15,"hashes":{"sha256":"Iz41erohcJJKh2BBrjvt1Fv1yqfb4NLCpQdYsQfmhd0"},"origin_server_ts":1783626355388,"sender":"@ali:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$7683AfvdvVGbujZUglQ3dOVMhLfC5n8sd4USeya9_9A	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	{"device_id":"WGYBGBWZQI","txn_id":"m1783626359848.13"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"yfcVKvuhaiTilZQAkr1qIhZ6612+xoq0zSEJ2ZhBla2fRPAMoSj14sIsr4DFJDZzUra+jTzLSyQ0uwzGzZwZDw"}},"unsigned":{"age_ts":1783626358593},"room_id":"!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir","auth_events":["$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY","$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM","$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg"],"prev_events":["$C3PYkudwbc1C1vhjMWGEuUhQS2SwdWK2dFzNgexrfug"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgGErABCbxmP7g8uNdNop245ws1maJsH48CJtjrWGMcN4WRCKSalh0Vhvkrgq6ZMR1QyXoKd9irhlwu/q8BBDd+ib9fALLzBe158K3EaTHkbo3MozUg24xj+43muQNNodNmLX08VtMqRw4yuz9AB8uWF0k6k4/33xoNPrDaYd7HoBZwQbI+vn/bCg2gmxZFcPjmIbIE4GAvOOU5ECWwsPbIc17gqHgUc9xVVm/jIBEpbzgYysup4hXvMXAGso6UgP/JWIRvRpJaNLALLVmsz2WlcsObNCoGF0++uRtoOjQUjKk2szNHyCnr25c4v62+BqNp1gJCqgcl733DgAc","device_id":"WGYBGBWZQI","sender_key":"Ujw/8UwhbJL/MqP2S8YMS/PID8kyzPOPUZ/gIbLXoSg","session_id":"Zb/DDBAInmrP5eELfi+I9Wk6/w708BumrPMSBy8L1cM"},"depth":17,"hashes":{"sha256":"VsuJ14S93A5sGckge99svP9jYQQyg2QKzjx3UeDXcbI"},"origin_server_ts":1783626358593,"sender":"@ali:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	{"device_id":"OFUSOVXTZJ"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"bC223ge9u9kv7rAMW58FagY+RzdL90rlQ74eR10L7G1C1qfoRlmj0QOCwItEq28wQ6yZqYhekuVb3pXnKCopAQ"}},"unsigned":{"age_ts":1783626825017},"room_id":"!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir","auth_events":[],"prev_events":[],"content":{"creator":"@alex-taylor:matrix.shikpooshaan.ir","room_version":"10"},"depth":1,"hashes":{"sha256":"7iCCWmxuS76GBppfBIRTS/lA6WexKqFs33TT3lg0R7M"},"origin_server_ts":1783626825017,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.create"}	3
$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	{"device_id":"OFUSOVXTZJ"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"tL5ZLkN9AWfcoLoHpsld5avQB51Vyf9WeCH5LNQZVNaDIgEJn7791Bl2fHqOQi6rR7uZdQZ2zFvolg3+E3hiAg"}},"unsigned":{"age_ts":1783626825275},"room_id":"!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir","auth_events":["$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg"],"prev_events":["$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg"],"content":{"displayname":"alex-taylor","membership":"join"},"depth":2,"hashes":{"sha256":"2NaU5p7mmJk+awKui7zpI5WCBE0qVT1vUbv+EfZSR/8"},"origin_server_ts":1783626825275,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"@alex-taylor:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	{"device_id":"WGYBGBWZQI"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"ZASOBfC1KMoNbQmusNOYO3QxYl7Mx3Cy8BEGj0/+IzfMyhJ3gVAxfcGvjoCQJAyEZ4CAW8H3InKLYBB//OcJBA"}},"unsigned":{"age_ts":1783626835369,"replaces_state":"$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA"},"room_id":"!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir","auth_events":["$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg","$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw","$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA","$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI"],"prev_events":["$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA"],"content":{"displayname":"ali","membership":"join"},"depth":9,"hashes":{"sha256":"+UAqd5Y2+97IhMjhGoXozvlTXQhW4dGJx6lplFJEuos"},"origin_server_ts":1783626835369,"sender":"@ali:matrix.shikpooshaan.ir","state_key":"@ali:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$_VnHK-C5uJEI_LtZ6Edmfv4J6T35_tYN-Em2qO-sRyU	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	{"device_id":"OFUSOVXTZJ"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"jVLlmpm6eR7YC1qMrQuf+hIyZvUR5YrZv0n5onKiR7ieE+88a86P2WloEkjp4kndc1IxlmK8qmDsEj4ycs4ZAA"}},"unsigned":{"age_ts":1783626825600},"room_id":"!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir","auth_events":["$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY","$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw","$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg"],"prev_events":["$14g0e4tQc-4i_Vdo1U2pNGwl-QbxmmrnRRA2DOZjnYs"],"content":{"algorithm":"m.megolm.v1.aes-sha2"},"depth":6,"hashes":{"sha256":"KlJ2Nv0HEHnvOjgto5r75Vl1/p16vXhAWrXlxnnmBpE"},"origin_server_ts":1783626825600,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.encryption"}	3
$NFsUH4yHF1VWTTF3R7erS73-88ifZ3r1Lk1lrp7s5rI	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	{"device_id":"OFUSOVXTZJ"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"lJDMGVQbAmEA17lwgC+idJ/Vs6EJGrQVRhrAslIOLmbWw/RcSOx0PKB+mK6i/ImXC3Jsm1qbLChijr/P/a0oDA"}},"unsigned":{"age_ts":1783626825602},"room_id":"!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir","auth_events":["$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY","$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw","$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg"],"prev_events":["$_VnHK-C5uJEI_LtZ6Edmfv4J6T35_tYN-Em2qO-sRyU"],"content":{"history_visibility":"invited"},"depth":7,"hashes":{"sha256":"qYcaHq6GAwI6P8De1ilbdc9LSC6rPONWl5WIPo4EyIs"},"origin_server_ts":1783626825602,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.history_visibility"}	3
$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	{"device_id":"OFUSOVXTZJ"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"iTjTMbrOIOT0Wa6GvmHcMq/tyBUzW9bQsPpDDad4P29fGuh8vno1KysjqZJXG1pjvL6lxqzJt6v2QPv25PcmBw"}},"unsigned":{"age_ts":1783626825973,"invite_room_state":[{"content":{"creator":"@alex-taylor:matrix.shikpooshaan.ir","room_version":"10"},"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.create"},{"content":{"join_rule":"invite"},"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.join_rules"},{"content":{"algorithm":"m.megolm.v1.aes-sha2"},"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.encryption"},{"content":{"displayname":"alex-taylor","membership":"join"},"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"@alex-taylor:matrix.shikpooshaan.ir","type":"m.room.member"}]},"room_id":"!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir","auth_events":["$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI","$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg","$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY","$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw"],"prev_events":["$NFsUH4yHF1VWTTF3R7erS73-88ifZ3r1Lk1lrp7s5rI"],"content":{"displayname":"ali","is_direct":true,"membership":"invite"},"depth":8,"hashes":{"sha256":"JiF0XLru64zNqEQR6Y66eYRcJT7JBIRU5hI7Uz2ZzFI"},"origin_server_ts":1783626825973,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"@ali:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	{"device_id":"SPEPVPSHPR"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"Pmt731EC40QxiFxRspNoq8n7rK5Z/CI73ucA6nno5VnzF3ooUbA33+7DdBfooHmg8lLY78nxQfuwq6iOdq57Dw"}},"unsigned":{"age_ts":1783627135945},"room_id":"!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir","auth_events":[],"prev_events":[],"content":{"creator":"@alipaz:matrix.shikpooshaan.ir","room_version":"10"},"depth":1,"hashes":{"sha256":"9D7uGLi8tPgxF7YwoM65AA3ZL7CKq9+y0+VBsqv/7Cs"},"origin_server_ts":1783627135945,"sender":"@alipaz:matrix.shikpooshaan.ir","state_key":"","type":"m.room.create"}	3
$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	{"device_id":"SPEPVPSHPR"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"RqZKEy4ZSMHN0iLJc/25VC6svxJFkCF9021S7BeAnto1dyLvmQtmuWmLrRNj+HDyTKknYQKLe2kNpbncH9HGDA"}},"unsigned":{"age_ts":1783627136167},"room_id":"!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir","auth_events":["$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg"],"prev_events":["$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg"],"content":{"displayname":"alipaz","membership":"join"},"depth":2,"hashes":{"sha256":"rVXGtlQ566faG1jaPvU11yj9zeXvXJ3VVS8VzyoHmR4"},"origin_server_ts":1783627136167,"sender":"@alipaz:matrix.shikpooshaan.ir","state_key":"@alipaz:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	{"device_id":"SPEPVPSHPR"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"k1e418zwoY4Dn+439XUrpW0Eq0YnVdkroKlBLdjOd3IWNv5sELDCiNMBoBCeBwmnVG3M2ZNIph/SruA76hCjCQ"}},"unsigned":{"age_ts":1783627136303},"room_id":"!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir","auth_events":["$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg","$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ"],"prev_events":["$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ"],"content":{"ban":50,"events":{"m.room.avatar":50,"m.room.canonical_alias":50,"m.room.encryption":100,"m.room.history_visibility":100,"m.room.name":50,"m.room.power_levels":100,"m.room.server_acl":100,"m.room.tombstone":100,"org.matrix.msc3401.call.member":0},"events_default":0,"historical":100,"invite":0,"kick":50,"redact":50,"state_default":50,"users":{"@alex-taylor:matrix.shikpooshaan.ir":100,"@alipaz:matrix.shikpooshaan.ir":100},"users_default":0},"depth":3,"hashes":{"sha256":"c2RxidkyKETrr9lvGYmXe7kgj6/tQOqAoxyN4qsiq4M"},"origin_server_ts":1783627136303,"sender":"@alipaz:matrix.shikpooshaan.ir","state_key":"","type":"m.room.power_levels"}	3
$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	{"device_id":"SPEPVPSHPR"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"tTVDGy5t4feQf4dBvPItmPCr375vToLk69ofH1rNQvvxjlAGMtJIVJUQEKJy86xV6+3q6gqtqhcNQS7yXR9YCw"}},"unsigned":{"age_ts":1783627136340},"room_id":"!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir","auth_events":["$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg","$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ","$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8"],"prev_events":["$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8"],"content":{"join_rule":"invite"},"depth":4,"hashes":{"sha256":"K8PzNidPI6r7vaqbWZY8xwHayLCiiCCvc93v9xHVHyE"},"origin_server_ts":1783627136340,"sender":"@alipaz:matrix.shikpooshaan.ir","state_key":"","type":"m.room.join_rules"}	3
$Z2e6JO81o3A3wHKKBJSTB-q68xOeUakOBJi-6H0er2I	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	{"device_id":"SPEPVPSHPR"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"Zi0bg8QYXLR0hdUYAYLglvHW4bXXY10koMmUvPDWTwfIyQJ24VBdNRoakS2kbr2IbPrkoema6Bm/ffT0u31IBg"}},"unsigned":{"age_ts":1783627136342},"room_id":"!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir","auth_events":["$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg","$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ","$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8"],"prev_events":["$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE"],"content":{"guest_access":"can_join"},"depth":5,"hashes":{"sha256":"PquypMSwuQ8VIWu2ygYpYspJrIwRAyvfb7FssZ0EbNQ"},"origin_server_ts":1783627136342,"sender":"@alipaz:matrix.shikpooshaan.ir","state_key":"","type":"m.room.guest_access"}	3
$2F_r1QYHaObawQDNr91dUNyPG7vMIy94v6I6KmYFAYk	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	{"device_id":"SPEPVPSHPR","txn_id":"m1783627150999.8"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"F6jqt/L+BR20E9e2rnGJjsoPF5cZuc/1foaLRhJXcVD94Ds4r0QooXYBS490OcceBNwdAOhQZ5kX/J6nuNllBw"}},"unsigned":{"age_ts":1783627149840},"room_id":"!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir","auth_events":["$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg","$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ","$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8"],"prev_events":["$afVsFJEIQ2l3SduwcVGDn3fVRxWpwp6Z294e_VvMTFc"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgCEoARpgiXlA46T0TKGgFVJRZc875ZvO3TL3rBsW9X3Ly59O0n2iV06CDI/mQGNkzenlnYb7y4iR6mFhwvoUjj8NP1lo6MOkJVwc2kLx0R6e5bOWDrBhkj8ur6dLz6P2oX2TLvuJfITSABoc3e1MZmRRYtlYLRM6OmcEoAY7/IEuGPJTLK7YlfTl/yEofqrLU8PDIs5OOe8ynB/ZKGLTPcAOhLaoUuf2RkRJb4WQxdqFV1Z1a8WCBh1+sA34/RuDp5sYPuuscJsn9fiUjMqoZIg7s5x5ikoFbyiGa21xF924H+KXMGQ51w3dwY2W0SbAbqpgwE9PITOQVll9RPYvlFENMp08iSbPU0T0hIKH8EjEdryXluoxxjku/lScJrrwHHx6nmXbrrp6b/3RxS7vKYcmU72aOrK/70WntPjYBj2eD+M+E5e8tc97gsk9ccnMtz+IDZ7sO8M71rZmmY+6zSBqOTQ3bGqgEvtKbVt5f+whZp8EEosP3kFHLSTOpPqe/pVdi9W9jcJfu+FsJ0klGUl7WPQygjP5PSuoQEmwishZttwppN1N8BuZ8LBmhcJVifUSTjffRFqawV7OZmdpfY/osv/LaMavsSkktKcwvTDKm8fZAFhTNFWyoTL3YRCJ5/ctB7otLhb47qbsCIKvp3VQkYDeGcGC7rhBVrKfJF0V5JlaRHWyiroMbzeCt3x1DrJXcP6DdmXM0StymGMFySy3wlWxusHzyjT5WQ8/L6dFyHjCkgYM7JuMGIfQ5iUQfOWEdDwe7gtyZXVG099rrJh77+rLEaZDmLRF6p5hEmymYhYcKv+feMMeLaogSCWVJ/IUendNSQx1YN0rENQulV0xKziJuGjcIcZbUkSyHcxRP5PDTzUd0C67hRRZttKt4IW0HGdods3QgCAIA4rMg2zH8LK69vOBqEU5u0p1xofq8pYD8t5SmE/e7+sSTZB3daeUDCYdmIUEdPtGGxnZk7l1wy0JvWTHDf2JzfZlqCvM7Wrw8qhR88XQF2MetKpE4VwxSqCG8h7J196NMvRjlbbuVXB0ntEWz86e0bqW0P928ObhKTLHrVdvoPyltzMWrF/Z97MRaOIMnBt6vwf7CSp22KQZIWb1ShZcBPgQF0HW9wT6iwuI+cOOLBrm47lCStSdXGV7QUvQWwd3oFDE6S8FWXnDrRy8vixfF7I7uj7R9kYhwnPC3c1H43Mj9FlOUK50ueXPrffDw8loW5+e5l8MOAhJmZrJXTOUIfUimBGBtnNDQSuEsa3/KCfNqVPrm6jI9hOudOnT13fW5dKrgkq7xFUKpl/cVYxW3bunx3/KxpOB3g0Eh8M04twRcabUJqa+Fe/e6OmkQUTgLNWzqa2c4nw3Nkz+sVcMoqzlvlgdDkRtyj51e7uy+l2ArDTlJMqg679z4tZLNklL6bU6DGcOEaSv9CjNMoS/MYVcRt6COHM845hfycXmtj84NkrG0xqNPkuauXUjZkCwG3p1HLV0PIWhrCp6CBrmS3li9xweb0d5d+z0E9CUFBvC+Jr2uaKOaFrjxv0ReQ9fDuCTa7pl8HznLitnfSrkxVdLnTyv0RpVVaPJKovbnvPK005DEJWj/BtIvnj3SWy9GmwzI/TGvoLpdL5Az7Dj9jeKtIJoCukP81D4+4lCnTlKdduKiSV+h2GQblydVhXxk4bRmgJy1yh9f7i2Z35WmbDjhWsowDW5zBJWCYhICHz8utWSxBYRFno1YKWHUwnXb2628R9JNzLILcTvYnPYoNfPvk2UACoEAuqOwguOINImMuVMhnptgl3DeLgYK28la4AGvODHqQQlHmFXA9RiZF52xOKsdFaSknwnVDA/f0BrYBesaUGGipmJeV+C7wE91JMgNEtDPFYolaYbvmMUFc+A44TmoCp2wlVl9pbQbclfUzRN8m+Z/ibgG+ocBXX0oYlWycm9aSPz5qSM0tAgx9iOWACwyzVem+E5dwL+LwJu12eO8S57mfUD0XS4ujEJxG7TWASSi9evvmY3gK8/SSUNEa7cFtDXmdLsAM2EeL8GDY5oa0voQ4dsJIBV78llqwOC3BFjTuHu48WxRh1qoY21uLu62SJuUVCfIG1xLlxwX8UqEQ4GILfkdpNlKB/iSFAv/afAKg4RiCOlqMRwYLYO5/vxH4WNMzSPNtiQqJoY5LkppVYnmSUiLVHPP6JmJaoCrE2kp3oXUWCI+BHKBE225u6AIBHC6HWkMbYWgmfn+tGy/cV1o+I90W7RoPNzGxxjlVnkKpdbg/SV/MsLP3ohkF+WXrtiz34GNHVweZ22Wdj+P3xxjJcb3tfy+XdFaVzZO7K3WDX96vNIZdSLfK/uVnvMWWlXz12avOtLCQnDSehmJD0zBK9vfeeJ0UkItnESrNLb5sJx0KhApWdFh9PNnAxpnZpIIr8iKF6DqNzQPzY2vGRxG87qNWpGihyv/a5Lb8gD9XuWGMKuzS3fKgVqcGzZ83UjmStiYWamrE0TpEZ4GM+eJa6oQ0r7AAMjQnurBe5v6MVTGYCDUBADfTpk/MXFILdyj2pxVZhRgOAWhxsrMB+PYfMwRC2WMnaEYxn5/RjAQLxczdbFaXVlhPYn4VV3XmMlE6x7+Gr3fAXbS3OnURyEgtskHtK3IoaJvp83JKpqWNWE0ZS76YR7VWKfzMGHkghhXaYXEPFPbFygLa2iFzX0yVmsZRazASGQdKQWx2NmnUngBT0dvyheO+UhWDv6xkqxOJ9bVfnrlxJ8UR8hEVt+UX2rqULv2s7FAVnttSMWA1YRF3wcFTqma6lxRqjTz+JwlvLK5TcmtUEmdaiTEHngj4H7cOnwL/mC5G+vpiaDg6pypNoXi/cL5wERtkqGIFSvx/VYfUW6A/w324cTNE3S2T5rVFE/fDuG4fU8zfKseYFNzd8WbT9dkxR+8dZK3RQ7G0yO9a0Mbzd/uKggbagXn5ZyMisNIcUlwn3Pw0J8AscY0Mse05fY4Nys34qyYa8SkkU5wRQOTYCw","device_id":"SPEPVPSHPR","sender_key":"PhSzjo5DIBBKKminzRKyXkypH+XfLbCUIu7bFjMhbxw","session_id":"4q0hpaOVi+zaa34pNBtOm+GwYOLf5xjhGkuPZO9UQwo"},"depth":12,"hashes":{"sha256":"jnToMuGgb86KqZoFkx3etTUfQJ52rhV1AJOKmtuoIKU"},"origin_server_ts":1783627149840,"sender":"@alipaz:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$oUHPDjqakCWglPegHTY6TC8e_Qaqub-Yoh_XfUKTjjc	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	{"device_id":"SPEPVPSHPR"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"MA1+e0ttRNk232pAkXckUeXKU9qSCpBgr7Ubt2ZhyuCw4+SMETt2UANLyK12na1EoOvo6C56yExtHrFQw5KgCA"}},"unsigned":{"age_ts":1783627136344},"room_id":"!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir","auth_events":["$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg","$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ","$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8"],"prev_events":["$Z2e6JO81o3A3wHKKBJSTB-q68xOeUakOBJi-6H0er2I"],"content":{"algorithm":"m.megolm.v1.aes-sha2"},"depth":6,"hashes":{"sha256":"CSXSNblIibcF01CSNKrMTp5HzssgNMdOpU2jWlkTQ7w"},"origin_server_ts":1783627136344,"sender":"@alipaz:matrix.shikpooshaan.ir","state_key":"","type":"m.room.encryption"}	3
$ZaaKYiCE_n9AzqSGJntdPRcRM7BRhym69EHSrFwgdac	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	{"device_id":"SPEPVPSHPR"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"vbNccHjXbRWzXerMYuKnAoK9Hao+vzj6sC2yrH8DIUC7bIVk96cd+PUurpTKWtYjWcpYvr3ULaZarpmkghBYBA"}},"unsigned":{"age_ts":1783627136346},"room_id":"!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir","auth_events":["$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg","$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ","$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8"],"prev_events":["$oUHPDjqakCWglPegHTY6TC8e_Qaqub-Yoh_XfUKTjjc"],"content":{"history_visibility":"invited"},"depth":7,"hashes":{"sha256":"1X30Mp31qyPsnYpsLsn6wov7TzVCwGK0pOfl5DhVEeI"},"origin_server_ts":1783627136346,"sender":"@alipaz:matrix.shikpooshaan.ir","state_key":"","type":"m.room.history_visibility"}	3
$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	{"device_id":"SPEPVPSHPR"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"VL6XsbOtI+Q1oig0YaQ8EcjN7zwjpkejQsqsyGmGUKT2frFbITL761XRWoUXMhPaxAPZj8OllaR9+kHD1f5CAA"}},"unsigned":{"age_ts":1783627136677,"invite_room_state":[{"content":{"creator":"@alipaz:matrix.shikpooshaan.ir","room_version":"10"},"sender":"@alipaz:matrix.shikpooshaan.ir","state_key":"","type":"m.room.create"},{"content":{"join_rule":"invite"},"sender":"@alipaz:matrix.shikpooshaan.ir","state_key":"","type":"m.room.join_rules"},{"content":{"algorithm":"m.megolm.v1.aes-sha2"},"sender":"@alipaz:matrix.shikpooshaan.ir","state_key":"","type":"m.room.encryption"},{"content":{"displayname":"alipaz","membership":"join"},"sender":"@alipaz:matrix.shikpooshaan.ir","state_key":"@alipaz:matrix.shikpooshaan.ir","type":"m.room.member"}]},"room_id":"!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir","auth_events":["$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE","$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg","$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ","$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8"],"prev_events":["$ZaaKYiCE_n9AzqSGJntdPRcRM7BRhym69EHSrFwgdac"],"content":{"displayname":"alex-taylor","is_direct":true,"membership":"invite"},"depth":8,"hashes":{"sha256":"QdftEDjZYBbdGYhKQDGxqRwmrSbSJQ1TUJS2GYA7BXo"},"origin_server_ts":1783627136677,"sender":"@alipaz:matrix.shikpooshaan.ir","state_key":"@alex-taylor:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	{"device_id":"OFUSOVXTZJ"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"XSFnqXLLHsVdEXgfX0W68RAQXtKisL3ibpv/SW6ORaC2jS5fjCanjYE0HEOBVVLyhN99oSFmVQtbt6MoZoEiCQ"}},"unsigned":{"age_ts":1783627138997,"replaces_state":"$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA"},"room_id":"!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir","auth_events":["$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA","$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8","$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg","$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE"],"prev_events":["$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA"],"content":{"displayname":"alex-taylor","membership":"join"},"depth":9,"hashes":{"sha256":"KINRIJm6gHMd6n2FIyJME+Yt7PgSqzNGq/CHYWs0hVo"},"origin_server_ts":1783627138997,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"@alex-taylor:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$ExyXltZ8XVgCS4zv7cy-lT_wdLHC4I6gFOEe9WIXLxo	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	{"device_id":"SPEPVPSHPR","txn_id":"m1783627140987.6"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"YfUalY/SGT5ABrKcwelWxGzg1nl/xB/mFjw0dCV+xO59JbAe/D+OoW+oi70ueWQ0q8iObg0rpg17RqtZZqTmDQ"}},"unsigned":{"age_ts":1783627143288},"room_id":"!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir","auth_events":["$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg","$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ","$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8"],"prev_events":["$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgAEpABFO+5bp9cFWEH5zF7lGPVtkYDSNeHzhEJ0+PuZ77R375QzPb8FOnfAHt6QpRqyuhZgGy05T84C/EHgdGjUQvn79kCQyisimhDhC9syxCCfceeZV6d+pC5IuRNRDaHQE1jQORV9gDKthoWjjC9m+XDw6BR2rEtED1GN74ALGyevm2Z+8q86tYAcU20pb85+e7JfpK+fjqv/6HGoAb0wlx6Vnap/wYISwajgVS+K0WgIBC0t9Q9OM+Jq+MOPuv0PGHNbXAfC4+a39yx8AlPbuYITSqvIZE/AO4G","device_id":"SPEPVPSHPR","sender_key":"PhSzjo5DIBBKKminzRKyXkypH+XfLbCUIu7bFjMhbxw","session_id":"4q0hpaOVi+zaa34pNBtOm+GwYOLf5xjhGkuPZO9UQwo"},"depth":10,"hashes":{"sha256":"EzJyRmsxpyQgxANOEbWI82Dxz98qf52uLkVS3dWfZ0c"},"origin_server_ts":1783627143288,"sender":"@alipaz:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$afVsFJEIQ2l3SduwcVGDn3fVRxWpwp6Z294e_VvMTFc	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	{"device_id":"SPEPVPSHPR","txn_id":"m1783627149094.7"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"3m9GT0YHtCAWjX7vAgT63vDIyXIZgCO9Xz2cGR0SoHAwtz7EsuZclzRvptDaZhX4LJblPysk4RC9mfXBvMHHCA"}},"unsigned":{"age_ts":1783627148070},"room_id":"!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir","auth_events":["$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg","$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ","$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8"],"prev_events":["$ExyXltZ8XVgCS4zv7cy-lT_wdLHC4I6gFOEe9WIXLxo"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgBEoAOhlhNCa+f/SFmgbyflKydVcUDnUaLuzQOTjnRcbPwWPZeuOahxdXKWJaB+iv9wLm+emzbEePnZblvJM5cl58WFPnqbKun3wxGfSmFrA6/EPElBeyKbZ4B+0a44X4C4tFgqMNk5Ep/eC/aYnAQ1BfLNk722HUEAj6sK4EzcdfkgiK4yMdk4SV1QrocUYFqfZyfG9qH+AbDtw4uzZ6/ss5aEMtOPMEV6mvfLRqVAgFFaeJp/i8U62HdBt4hJT5WXNNlgt1rNpL2r8KzZF9ySgSFhTa3HnzMSPvkmjH3uSHVvaRVuvKMYgXvKF+hC2W7GvJe82alos7u/D1isYKm8ZTyHJmm68swaOUK77KBzznfi4fdsEA5uTzbVmJcQGi2CotjZv17hGD56f4m7VkAtDliRCvYd4vrIG5xO5fnuZuQAwFo+p/e874vyb7FyfuFXaiv7C1JFLNU1czCeMTbgBLHbqb6jUuVcnc+4JiuxK9IzafNOnrpFMPcrW3HRJGN/OqpI4NY/DfG57Qtb78IQ5SPjJs0DAyaWCP/28Rr+lnyykAClcqJNqDajxO0bIizMUOt1HhkTu6LqlBNa7WuZr+AuZBzLQinVCkgVcT6EddfV6vGyOcArS3UHa3XoUaWAhuFqCv5hIwyuUDSehiA62DanSDaIiXcdAEBRPSq40zy2N9Izz2lKBF8oRGbvZqZ8uZRSIJRLOu2ihSa65NtxTs3tCKSDuPM5TWX5pOvCPh1wzuiEQZoWJlBIrzPvqBnC4w0FxLthdNiF+MkWCBnK8nzpSKmKiFSTcjEFXHTul18OTXoSAPJ4wNe90RT58OhZvMWwSKyUChILoFZTupHKeNaegiSs8KnJoBVLEOnEqK/qjptAFi3gvQBm7D0yOpVlDPLNT+Z2BWKJva/rYCE6NwNGwxHUR3NQ79ttNNvuWV6eyq86S1I33M2MLK9dSxs8Xs2bukmMns+MvQpCLdxTJx/hIJBf889xVhUwYweGF42QqID3InkXlVHhVl2mP2PL9C0At0pKc9QefxMU/33nGhmFEHBPFeRHll+gCzunolN+WzD0HYFPw/ZKumwMVAecXrvq5oGCOfhPvXnkl6gMbem7yq5AqfIhOEZzPxEG5AgCZwGCC2SRmM5kqxGgxZ68GC7ShbL+BLd7qF6pBL84kqZYgIaHMHD1PPZHuJUxqzPywdtGHc5+3+sUpgN8XNF6pyzyYTzSYZxml8ciKh6eOTaextwIFNEg6rToPfmr3/xHvG+pubJHG46CA7rSp2TZINBV5/HiFgmRriDXiCH0pC18tDSDBH+ZrLqkgmn8R2VrQ4OapeaBoc9bfVoK6Pbd4PvbLc6a1nPlbDA28/0lb855E595s5Hxoq8M8ZVa/+U8lhQ5rOaXcaMCTLnBwJqn0JqTll/xRWeizfvkZuMJnGIXOHJjXQCgqLO5uJjrIaxjE3X0bI43MKDvgTg8q5/8vIkhGO+nLXhpzTlqS7R+jNDrRlJcr68D4yRKEON9Q++Sob4V7ixrgJkpiBmQJfEEIZnc5NEisNEtlO8qdxrRMbHDv8iKxGQKX3Xzl3nBq3ywkxEB70+iiGWJK0GOMvrCV2MIZw1IDJNwQ6aXW5qzI2LaWnpLrqIvQspm1Wt4N6wA0RghIXGzsTzMlQiKGdSPywQVobreF75zrlJNgqbpJ89mXeU/OUSxoDWgemTs6eIXL7zy530PwAfzgakeZNCqXGCl5Y77GH1n/DuAuXIjgAkyXhK7k0hRGG4KPzCtKOiMJjRuu72EoQISbKrnNXCVmToFkcJodJHb1c9/BaHVx1yLZBKgAglVE1G1bD/yHwIVOcD17fdL1UVfpP6/fjj2t5IT66cfqwY68elRFjpeu1MsN6SC1hrPWB3ApJXox0ZTOicczsg2wRTjqcKxm7jZi/NmgNHBy74GtIf+nxc3YNhGofcZIZlVxK+mleiGQg90bjfrCYE+e7RaGICdB9y9La+NwNBnYpOyBERtZe8mSe7Vmu1OwWhLhCdiEzUtqGcZGCK0oU4zVCmSArH+qn+fWwYKYTWsx9S/LWyGdDwJnwa8bYyAsvyN+DWOSHS3Bfa9luYHV3BXZRKlii319gYGhl0UlBSW4bAcQvkQ63AJwUTIZd+e76XC2mLDmiuba8ESFuwWBX0s6SeWfPOAoNjUI1VfeLFzLREPACx95Mxb8HbLQBDJv+M14PgCoAMCuRt8/tRNRHCp1+yPHkKt4rlMr1kBTE9LvmuVh5Jb2AgoAgDd68/sOPE+YG51w1Rv8bi1fyRgK9cTx/GGPGmbJixVNgn21WtfcyXWa1S0qiDIuNUowx5H4XimdO76VGs3um2O/sjjudnLMBv7ftsBBwQFMlPEo08+CyQOFec+ZBdIldQ/FZUyIOh2UPDFAesWY7uuaFvtRn4vK9cqld3Im5t7bPt9cq/HGDhz48jWkAPPxISLxfNyZ72xH81HKqW+jmQjKZ0m2GuVN0uDw","device_id":"SPEPVPSHPR","sender_key":"PhSzjo5DIBBKKminzRKyXkypH+XfLbCUIu7bFjMhbxw","session_id":"4q0hpaOVi+zaa34pNBtOm+GwYOLf5xjhGkuPZO9UQwo"},"depth":11,"hashes":{"sha256":"hxwcBFKODrBxRbJGkju3BS5N0VOR6NeiGvmWZAiBW/c"},"origin_server_ts":1783627148070,"sender":"@alipaz:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$_H2DZoM2QWFOqEQG70J87qAZM3H467C9Jlh4_5gWzzI	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	{"device_id":"SPEPVPSHPR","txn_id":"m1783627152419.9"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"KVbaW6fHSt0nEuahN57rJIJo5OH0G/IiUKZEsy31ffW7iMOK8kRN80ls1Sx5pWPXtXtXwb3V0tUKnDA93Q+bBA"}},"unsigned":{"age_ts":1783627151124},"room_id":"!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir","auth_events":["$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg","$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ","$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8"],"prev_events":["$2F_r1QYHaObawQDNr91dUNyPG7vMIy94v6I6KmYFAYk"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgDEuAEruG15eM/xlMHlDRTg0C49ZbZs7ok2YUCNwARoOpKnA1SWehKY0G7R2kQ0UgfK5uvH/6g4vPbq0DjVzdlBQqvVlsFuH/yeBUX/l+sJpkVtyuUZuSf05gSwIf3iZbGI0xv4uosjdTkQQQn4+InPIBeB/gk5iXX7ORHNNGR1P0piDNazq/ZST6Ssr8DqizTv+YCTn7D8CEHIwHvR7a4p1+zDJY5W6xzsEV87n6ZX5uPoELiM1tYCPgWbvXC4KCJx5vMMZQWggD74TkcxvQlhtyB4IzBZTfIBXwFrIE4+l6j043YE2+aH6vT3ILTuOtOtrtEHGY6kIC4ZF9vj+TepkpR53QL9m7Uywdt0MNdtGmC8gZoXGiDJkPLyRQ2nSZIPBPtSMJD9fFLRX8tVicWzeDVb769EPhzKj7ZCULtBQfuqRkNaKsFNqD9lVnGcnbYErHYpJVBv0yQKVqDwceFXY9UVjwVFlwTFTj6ko/f9S8OFTnHJbqNVA2yQELKPlWECYGnaORhB75MaB6KHj7lCOe0mTMfpB3Nz4g2qYHm0vWy3JFPSK8eliZ/2bOWWxBef25mCS0H4uuRXDXHM4IlSJ+d/XbyH5pEMfqlcBjKe27TGZ+1fGV+NRUDrMbck5my+Lvgt9jsWy9I7SrTbEY+MXkSND7dJ/GAaU9fQFJsmDhjsWtanFZ1DFYvI3hhB0SHDyjFeBpMHSa3SYV+9jdoapPFlVyS82c9JOotzuSfpzTnaGoUx+T5nePN6iKYZU2LwxPWSzpE5FJaOYJzJUhUiMBlXbWz5SK/aBGnw/fPtrHTWe5po8TXCPEExy+M8GyFWJCzIt7F6CyGME73yfaq40wsGL6mASP7wYo0r9/BlpAW3dkeob1LzVKKkhNbASeU1GM0J621wmTNlgg","device_id":"SPEPVPSHPR","sender_key":"PhSzjo5DIBBKKminzRKyXkypH+XfLbCUIu7bFjMhbxw","session_id":"4q0hpaOVi+zaa34pNBtOm+GwYOLf5xjhGkuPZO9UQwo"},"depth":13,"hashes":{"sha256":"IgS8foBLM0z2zYV/uhd2CkSO3e8Il/6/bohhFVnu1H4"},"origin_server_ts":1783627151124,"sender":"@alipaz:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$nOti7xJQKHyROEyoGtsBKtap-hocvso_bgZ53R7EE8U	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	{"device_id":"SPEPVPSHPR","txn_id":"m1783627160242.10"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"daAiF0cb76Cp++D74zevOfkGdu44JYRw6U1oV3fvXeK9dhiT1YVVFmmMJA26LZJ+eztw1ZV5/n8dIneuMlf9AQ"}},"unsigned":{"age_ts":1783627158994},"room_id":"!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir","auth_events":["$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg","$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ","$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8"],"prev_events":["$_H2DZoM2QWFOqEQG70J87qAZM3H467C9Jlh4_5gWzzI"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgEErABnuElf2nihL9nPKsr3DBt2SAwgGXe+wLUu0JMb1xLT9jx086Tg0rEpnIw/5C4dXc4clZDjkigV92aallzaJYGDCINV9S5Tf63xJsLaYvO+uIeNa/aefZj5Pto1uoIJnEXSfaThRMqWpx7oKtTYRNNgduXu057F94duEBh/bavLCGQlycGtI1G8WKJYmzfICJWNgvaDeFI9x1Bo3FeJlvDMR7aTqsNcRnRiCcPipuyEdCiBxcGR/ur0mD92shD8nUH5x4XBDDiW8Fe1xmLv7aNXCCeicU5tB5S0+4SlzS8vgZFAeTQ99OCtjDO56PqByUYT6HFvc5wGAs","device_id":"SPEPVPSHPR","sender_key":"PhSzjo5DIBBKKminzRKyXkypH+XfLbCUIu7bFjMhbxw","session_id":"4q0hpaOVi+zaa34pNBtOm+GwYOLf5xjhGkuPZO9UQwo"},"depth":14,"hashes":{"sha256":"00jAJhg9nlurMf97/jXWZahypNKOyO/MceEOB81576s"},"origin_server_ts":1783627158994,"sender":"@alipaz:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	{}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"TEYdCPpxlhC7SG+GP1Q6tmkBf0SAJWQ9bambJv6UN2KOrS8YQrdZyaZKqiFu4ISRZOhvAlNSM2nYq+oJ1r5bBg"}},"unsigned":{"age_ts":1783669885808,"replaces_state":"$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY"},"room_id":"!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir","auth_events":["$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY","$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw","$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg","$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI"],"prev_events":["$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA"],"content":{"displayname":"Alex98","membership":"join"},"depth":10,"hashes":{"sha256":"AfAgq+UkyCIkZk1qqHSVKmO9p9otLuAdQHXpZczoQ/g"},"origin_server_ts":1783669885808,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"@alex-taylor:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	{}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"KJCxb/wKSaVfq4GiQQH0Scs5oMfOpnOxYniPbjTtZIJ4DkeFqtHSvzRzEJJGLpPy7FJ2Ki/avMhsRdMdn8S8Bw"}},"unsigned":{"age_ts":1783669888505,"replaces_state":"$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s"},"room_id":"!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir","auth_events":["$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s","$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8","$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg","$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE"],"prev_events":["$nOti7xJQKHyROEyoGtsBKtap-hocvso_bgZ53R7EE8U"],"content":{"displayname":"Alex98","membership":"join"},"depth":15,"hashes":{"sha256":"3sqhh7zClCDYR+C2OHys+qWqOYWuZIgWGv139c2HaOk"},"origin_server_ts":1783669888505,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"@alex-taylor:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	{}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"6pwHy67lgqpZNOO8X+hHtEi10kahSrCvKCWjcxUQdzuW/OKkSwohtDM8NIGl8qxvpkBnvVeS4i+oXMv+8s6HDw"}},"unsigned":{"age_ts":1783669997692,"replaces_state":"$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg"},"room_id":"!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir","auth_events":["$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg","$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw","$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg","$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI"],"prev_events":["$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg"],"content":{"avatar_url":"mxc://matrix.shikpooshaan.ir/WYjvRrHdQwXttYBqKVGTNjYo","displayname":"Alex98","membership":"join"},"depth":11,"hashes":{"sha256":"ZZRP+x8RHE/zCkUtUUvLDIJsaTLbnv3u8ScCo7tp1vM"},"origin_server_ts":1783669997692,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"@alex-taylor:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	{}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"2+OR+ZHszPQ9JUwwZWx6V1RvqQJPpQif9sT4dzNLKM6obKdWf3vywTx66jjdo9dn9TkIp2EnlMNhF50dXZm0Bw"}},"unsigned":{"age_ts":1783669998649,"replaces_state":"$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A"},"room_id":"!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir","auth_events":["$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A","$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8","$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg","$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE"],"prev_events":["$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A"],"content":{"avatar_url":"mxc://matrix.shikpooshaan.ir/WYjvRrHdQwXttYBqKVGTNjYo","displayname":"Alex98","membership":"join"},"depth":16,"hashes":{"sha256":"N/Kc1DPcZV3v5F/6GXFVBW33Y20K2xUF7BLREmE6MU0"},"origin_server_ts":1783669998649,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"@alex-taylor:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$Ax7Nf2f62jFM6Iukww-bvFvDhxGkhcDQHJOA8GGe3pg	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	{"device_id":"NFLNJMUACW","txn_id":"855a30dd1bde4b2997be5b2e202c4798"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"fTo/CDWLH4NBCFTT86R9+/sTs/HuLCb/iYltPTS/7SdSNRu1hP1NB2+KnxANJPGM7HOidtrL8VmFNMqzLsmTBg"}},"unsigned":{"age_ts":1783670231459},"room_id":"!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir","auth_events":["$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U","$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk","$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo"],"prev_events":["$Np7L2UpX2tMrmcWkrhqTkIPPQf2JHPiRI9eGpZCUi9k"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgBEuAHsGQJ0cbYzJ5YIPFP5l2ulMOp+AwkGBQk+BbijTo8aV0H8UwQkjce4JPJnYapDYBFhasHC9MGizSgIGXw2qZDefUAfKBlvXlWBMmvaHs57v67avbY6AyJ70f++7zOYYZQdwOTXyOHyGmJOPAY6uTM6j8A8YP6CYywJmX8398cj/sGSnVNmoRhluQnW5Nig6cF0ooeC7GWNpSomurd3aRs3psEvRcuDgbBK/cfZGD+BwSrITsgSWO2wzR7foN+Xw+zbQy9fk/ueLE+UZBSsHk2yUWEf6Uu77KkZhFlM+PoR/6m7WlNHpTo1CuokktuFSIqt9R9zqCCRI2e/ANgjaxzqwaaJVBhVj+vmemtlU8eQJL1aoUBi3ERHrS0DZcu0MvcxFftZS90woB00c3XIh4nOeH2xUUYJr3/DWPtuxenQlBmJgpCzCFNWyAbDaS9F6Z4lb1CQuB625LeoNXLmMtWG318UXY475/l0ZgqgGh8smmqkTSiwCjZt5FUKPiHpwJIsj14vg7Kd289TkyCqPxXCfFeIErOx5LeI6vUYpA+QI2SGNJFBVMxeIkFcPD1IYdWy9/fxpmIm1JQIi2kFaGdmT+KxuPp5QQBRNqz9qVb0uHi1L3qGupwdY6SgTd9bSryoR6TVjc1roKwWjf0p6l6deL8cwCg7+Knh2flH5ggTX2ewUJH4XNzZ1gZU4mZhdf+wdAAhWP33b3Ay9ynvROuf259wD05d/sEuM3PUP3ALRac22XOIc/1vw/lJTMTNOZ/+xjWN0lPMi531UgVAVV3K2URTZpsZanq83jeQn6q3ttg0ms1ILNfqhT+aBEs3QFnvDsZ51az6Fva5AkqOlvPaaUcgWJ6JR1eszbsXp482t1qIJQF4pKo0tuqSLRe7/2kWy8H7F/N4vkGOYXz9xmt+zuDHBcTSzXSVrWi/sEVw6mmhgMkBrb+AeRg4w8RBKhCsDd7XEMyMfZRThB0yFVhA3/nkw4IK4H0ESCJyX5Dwub0+MwAXBeXDzaQNxhLmIgIDBXEidn/6v9RRdmjZbD/YJbIWRawXqc4Jvp0XcUc1D+7Tl4WGc6tBf05PyW74TLqZxB3Ym+efS8VnAuls2xIfrnCJcORMwpq+mIm/peSaZlzLiPxvjM2gmt1ZZ2fQ8MTgvZSAq27bFAsF86RL8M0jfaCpq18Qa48/3ZC1CPlgWu8nO2zDfri3LLkmAGWYUc05tEXsg6TkOnCalJxfjdyNh57HiyCJcf6VdbWhp/zQ78GpeTf23u1RssVXoXL9Yc8RSnmf8+LiQHtOYBLaVkN2DBRcBy7+BAuu87p5yqVmlNoJ4x0NZurGdQznNBbJRUbUuQonOD4SsZEfUu83iYsuTKkTuSwOQ9kQtGIIe5CYaxMcZYYLct/qpWZp/+3h/kyil4JKMf8+QI","device_id":"NFLNJMUACW","sender_key":"AwAHM6NjH1L2MkVS4FUG7WR8KhEnySQziynlcj1+flg","session_id":"L1YLj/45zaFTl8Au9b4uXWsp1q8J+0hZj7GWa+xiulc"},"depth":11,"hashes":{"sha256":"uz9zdHmGyDwEygyrabS0zfxQsT5qApPDeSPUhs7OOns"},"origin_server_ts":1783670231459,"sender":"@alextaylor98:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	{"device_id":"CHFTPUHNYF"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"Ek3P5IiDhxQBkwJf72BiFS97BWyd13ZjCzxT3ayPYcf6WxfYGgmLSR0a0QRtFDLW/mbnqG4NRlUQiDfRMDG1Aw"}},"unsigned":{"age_ts":1783670157302},"room_id":"!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir","auth_events":["$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4"],"prev_events":["$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4"],"content":{"avatar_url":"mxc://matrix.shikpooshaan.ir/WYjvRrHdQwXttYBqKVGTNjYo","displayname":"Alex98","membership":"join"},"depth":2,"hashes":{"sha256":"f1ObD6/684KQ1pj5uQRnzkr0JxHDlWtQLf4tIrSF304"},"origin_server_ts":1783670157302,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"@alex-taylor:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	{"device_id":"CHFTPUHNYF"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"2UxocFxlsuTyPS/h3nZdNgJNfdpw+208gyf+/Pk3QR0L221lg2bsT/grd60n6lS8ntFZBsOm8C9vYcXbdQb9BA"}},"unsigned":{"age_ts":1783670157574},"room_id":"!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir","auth_events":["$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ","$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4"],"prev_events":["$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ"],"content":{"ban":50,"events":{"org.matrix.msc3401.call.member":0},"events_default":0,"historical":100,"invite":50,"kick":50,"redact":50,"state_default":50,"users":{"@alex-taylor:matrix.shikpooshaan.ir":100,"@alextaylor:matrix.shikpooshaan.ir":100},"users_default":0},"depth":3,"hashes":{"sha256":"m7ZzWGqGkjuxioFgWzl7qg4fZ/LYdQKPFtW0ln2rpnQ"},"origin_server_ts":1783670157574,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.power_levels"}	3
$ekFlSyfMDYeG34nr1qqB9Bi-AbjdiJ_J9bLNNsHuLKs	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	{"device_id":"CHFTPUHNYF"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"b/at2ymE3ESFGf1xyoIy+IY9vrXqjkp4YszQ2u8oYZ+I5AUJ3IOYu7qn85euYjWegx7cn2tPx6RNFLiHvErLCg"}},"unsigned":{"age_ts":1783670158040},"room_id":"!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir","auth_events":["$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ","$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY","$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4"],"prev_events":["$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY"],"content":{"join_rule":"invite"},"depth":4,"hashes":{"sha256":"/lvIZJrWL2IMJtVYbhQrc6kwOr6Bk32AYEf5zUK6r9o"},"origin_server_ts":1783670158040,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.join_rules"}	3
$zc8tOpOdwrt2LhO6ZIPa8Tv1PyclAu-E3cFNvQTB_rw	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	{"device_id":"CHFTPUHNYF"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"sg9sYY4Z7b+sTLFPlP0464ShbG9FyXYwYGXhAKfJE+DB2sRBah+8bzGIxSR7pRn/3nUBJBKDQWUhBawZHCkDCg"}},"unsigned":{"age_ts":1783670158042},"room_id":"!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir","auth_events":["$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ","$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY","$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4"],"prev_events":["$ekFlSyfMDYeG34nr1qqB9Bi-AbjdiJ_J9bLNNsHuLKs"],"content":{"guest_access":"can_join"},"depth":5,"hashes":{"sha256":"NnvWhX2HNFTjk/jtJhddQp1jvNoHBJ1WM2Jx0PNnUmM"},"origin_server_ts":1783670158042,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.guest_access"}	3
$KTjmV6JHWFiwg8JXvrYWGjeMxJtAvzZoRDulWpsNaSw	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	{"device_id":"CHFTPUHNYF"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"26Ob0xyrAY53xQ/EwZcEYHxLzZhTFqittw1eN9rln4M33Iyajbbv07GWgxmVIJNK86n2P2pt1Of+AjtBX94bBw"}},"unsigned":{"age_ts":1783670158051},"room_id":"!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir","auth_events":["$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ","$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY","$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4"],"prev_events":["$zc8tOpOdwrt2LhO6ZIPa8Tv1PyclAu-E3cFNvQTB_rw"],"content":{"algorithm":"m.megolm.v1.aes-sha2"},"depth":6,"hashes":{"sha256":"zOKmDPkmpje6bV5a23O8dNfnmrt6/6DlcBUqFCAV6WQ"},"origin_server_ts":1783670158051,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.encryption"}	3
$Dc3jotNRZdjzDW_y7eg_fRWeyXs382gqm43HSX5lbOI	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	{"device_id":"CHFTPUHNYF"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"A2lSYxA19nr/ERr+U5+LMbSVF/DLwsGjtyquw75qkT23L6vdL0Ge1mHQPWwCou0x3jMPNiiawIXmzXvQEyKpBg"}},"unsigned":{"age_ts":1783670158057},"room_id":"!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir","auth_events":["$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ","$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY","$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4"],"prev_events":["$KTjmV6JHWFiwg8JXvrYWGjeMxJtAvzZoRDulWpsNaSw"],"content":{"history_visibility":"invited"},"depth":7,"hashes":{"sha256":"KvDTLFxPMqQpBIYeZSSFBs9oiJnhg3Hm7R4+L+I4+zo"},"origin_server_ts":1783670158057,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.history_visibility"}	3
$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	{"device_id":"CHFTPUHNYF"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"4NDYBSlXmhIjXIFc9PrFlWdCpOM8KM1cpyxVPYGKqzS7AJ8zruolskoBOxiv2bYxeVQGkzo/hYR/a4pYjFqtAQ"}},"unsigned":{"age_ts":1783670197776},"room_id":"!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir","auth_events":[],"prev_events":[],"content":{"creator":"@alex-taylor:matrix.shikpooshaan.ir","room_version":"10"},"depth":1,"hashes":{"sha256":"bO4OXYr2T5ztPbYJvRZIltGQvkvtnl+1O2dcldDOn/k"},"origin_server_ts":1783670197776,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.create"}	3
$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	{"device_id":"CHFTPUHNYF"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"8ZjB7FiQcYXO6YXV/OC6T0RWGuS3IydZRsml+P1JMl6RArgcS4aSNeCzjK1OBgXa0x4d3TYj/syMzY7VayhmCA"}},"unsigned":{"age_ts":1783670197966},"room_id":"!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir","auth_events":["$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U"],"prev_events":["$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U"],"content":{"avatar_url":"mxc://matrix.shikpooshaan.ir/WYjvRrHdQwXttYBqKVGTNjYo","displayname":"Alex98","membership":"join"},"depth":2,"hashes":{"sha256":"+S9zOga0B4ISVdV+bVC7S6tAcPx6CPNkLEuVBF5VhpE"},"origin_server_ts":1783670197966,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"@alex-taylor:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	{"device_id":"CHFTPUHNYF"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"a5bPB5upE2Y1YapUGrRdWdKlLqmDg2D509Rrq3KjB/qQgQZgBWswWxqcxmNvdZkmaEylvET01ny7pUTl0Nb4Bw"}},"unsigned":{"age_ts":1783670198153},"room_id":"!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir","auth_events":["$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14","$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U"],"prev_events":["$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14"],"content":{"ban":50,"events":{"org.matrix.msc3401.call.member":0},"events_default":0,"historical":100,"invite":50,"kick":50,"redact":50,"state_default":50,"users":{"@alex-taylor:matrix.shikpooshaan.ir":100,"@alextaylor98:matrix.shikpooshaan.ir":100},"users_default":0},"depth":3,"hashes":{"sha256":"Ia/zelRc0iLOMQe00f9ZaZ6U3l6VrnyIEzswPEJe4MI"},"origin_server_ts":1783670198153,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.power_levels"}	3
$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	{"device_id":"CHFTPUHNYF"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"c/SyPuPal4qlceokaxw9g3MyyHXEV0XF01sfU+bMrFWQrcDUARyja+jNNDJOWSffoUxxnfJt7FY2BkBbARtIBw"}},"unsigned":{"age_ts":1783670158534,"invite_room_state":[{"content":{"creator":"@alex-taylor:matrix.shikpooshaan.ir","room_version":"10"},"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.create"},{"content":{"join_rule":"invite"},"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.join_rules"},{"content":{"algorithm":"m.megolm.v1.aes-sha2"},"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.encryption"},{"content":{"avatar_url":"mxc://matrix.shikpooshaan.ir/WYjvRrHdQwXttYBqKVGTNjYo","displayname":"Alex98","membership":"join"},"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"@alex-taylor:matrix.shikpooshaan.ir","type":"m.room.member"}]},"room_id":"!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir","auth_events":["$ekFlSyfMDYeG34nr1qqB9Bi-AbjdiJ_J9bLNNsHuLKs","$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4","$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ","$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY"],"prev_events":["$Dc3jotNRZdjzDW_y7eg_fRWeyXs382gqm43HSX5lbOI"],"content":{"displayname":"alextaylor","is_direct":true,"membership":"invite"},"depth":8,"hashes":{"sha256":"9lGPMepJhT2wAuDVFD2SbHHdQWM4wsvzp7k1kHnegIQ"},"origin_server_ts":1783670158534,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"@alextaylor:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$4FmnE3et4KlX8gqLLuDjSYLUFKZG8CgNq8_OPh3TWYY	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	{"device_id":"NFLNJMUACW","txn_id":"6911d2452dd94064a8c20684d341370f"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"qzGrgUR0x/ehrbBgjB+M0PUFKvjHc7zhuiSO3cx8c+YQLnwZRXip2qZ61FLOMoKsj3ZiknMtPR14vWlUHxl6Bw"}},"unsigned":{"age_ts":1783670505780},"room_id":"!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir","auth_events":["$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U","$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY","$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo"],"prev_events":["$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY"],"content":{},"depth":13,"hashes":{"sha256":"r7cIxXsl8W2y45cMJNOJ6Xm+ilXCz3CtDVlaSZ4wBiE"},"origin_server_ts":1783670505780,"sender":"@alextaylor98:matrix.shikpooshaan.ir","type":"m.room.redaction","redacts":"$Ax7Nf2f62jFM6Iukww-bvFvDhxGkhcDQHJOA8GGe3pg"}	3
$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	{"device_id":"YOCYFXUGYQ"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"SbOc2kbvZxV3CnOQU9877hIzFuCqpo9QaIM2HvOjuPvypwhkBV4H7uBrPSOzC0riKvPHEdPGOGfktDWO9g0bCg"}},"unsigned":{"age_ts":1783672403407},"room_id":"!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir","auth_events":[],"prev_events":[],"content":{"creator":"@brian:matrix.shikpooshaan.ir","room_version":"10"},"depth":1,"hashes":{"sha256":"d0JACV92JHc7U/hnCFUrA6bsA84xK6q6mkmS0CSVT98"},"origin_server_ts":1783672403407,"sender":"@brian:matrix.shikpooshaan.ir","state_key":"","type":"m.room.create"}	3
$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	{"device_id":"YOCYFXUGYQ"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"mQ5Lh+DW23pgm2X/XsGFw1IqG4/P6XDF9eknGQWuoXjGlNKWxr2WYlPV9DSXyhoKulhqAwOH+NVK+20Uk9P4Ag"}},"unsigned":{"age_ts":1783672403731},"room_id":"!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir","auth_events":["$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs"],"prev_events":["$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs"],"content":{"displayname":"brian","membership":"join"},"depth":2,"hashes":{"sha256":"Y/RJY51id82kGdHdcLqYwOEqI+wokS2GhDE5/BKxQ6M"},"origin_server_ts":1783672403731,"sender":"@brian:matrix.shikpooshaan.ir","state_key":"@brian:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	{"device_id":"YOCYFXUGYQ"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"R/ekj0ATGSyPvY/VHfIgp1CYCa4/ic/teAxIeH6UxqhjEwAxru7eFPCmeHIHbryWv9X8a4qO8EE4aXM1iKlPCQ"}},"unsigned":{"age_ts":1783672403907},"room_id":"!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir","auth_events":["$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs","$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw"],"prev_events":["$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw"],"content":{"ban":50,"events":{"org.matrix.msc3401.call.member":0},"events_default":0,"historical":100,"invite":50,"kick":50,"redact":50,"state_default":50,"users":{"@alextaylor98:matrix.shikpooshaan.ir":100,"@brian:matrix.shikpooshaan.ir":100},"users_default":0},"depth":3,"hashes":{"sha256":"HubrkFxzBtE4ilbSwNAxmTJqhjwl8Ux71R+st62x8Dg"},"origin_server_ts":1783672403907,"sender":"@brian:matrix.shikpooshaan.ir","state_key":"","type":"m.room.power_levels"}	3
$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	{"device_id":"YOCYFXUGYQ"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"NWgX1ZUqh3SKn12bOEPqbJhHlnxnn66sDUiOqA7d0JHZ2ujUKKKAuuLwq+5RZ8aC/v6vt+GaPmRDIedTc3YLAQ"}},"unsigned":{"age_ts":1783672403943},"room_id":"!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir","auth_events":["$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs","$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk","$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw"],"prev_events":["$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk"],"content":{"join_rule":"invite"},"depth":4,"hashes":{"sha256":"AojeBa3fMC04qajjQDKHl9ADHCVFTIeZNU/GQTDoZEQ"},"origin_server_ts":1783672403943,"sender":"@brian:matrix.shikpooshaan.ir","state_key":"","type":"m.room.join_rules"}	3
$lzdi23BC1bOIDnNJnuoZzfFYBb3iv4PDZ1pw9Tg4z1M	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	{"device_id":"YOCYFXUGYQ"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"bAOe1snBXarcB+Cyog3w94VKkXjX4+/SXGxUoIxPWeuResNfTt8hl4o0Ks4u13PkOdGd3nzQf03Daik6ZLpbAQ"}},"unsigned":{"age_ts":1783672403945},"room_id":"!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir","auth_events":["$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs","$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk","$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw"],"prev_events":["$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ"],"content":{"guest_access":"can_join"},"depth":5,"hashes":{"sha256":"Amv8gE+xJ74LJdQUlcTgpDY9ol9FH8q9xZ2UFZR0jHk"},"origin_server_ts":1783672403945,"sender":"@brian:matrix.shikpooshaan.ir","state_key":"","type":"m.room.guest_access"}	3
$d-DLbKD_o_R1rzHrZD8hyXWTZsKArLYnNTv9_1HRatE	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	{"device_id":"YOCYFXUGYQ"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"FvTEHwd06nxVr4c9JekTf3IhzUW6zx4PZ+JshquxoVEshEW+DhjhR7NUyzWoYUrKHlP17scFkwQ5HOFZsDPzAw"}},"unsigned":{"age_ts":1783672403947},"room_id":"!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir","auth_events":["$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs","$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk","$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw"],"prev_events":["$lzdi23BC1bOIDnNJnuoZzfFYBb3iv4PDZ1pw9Tg4z1M"],"content":{"algorithm":"m.megolm.v1.aes-sha2"},"depth":6,"hashes":{"sha256":"ePCHbGPsH9yA1NWHVQGHCeisRI8h1lKpJ9CCOMnazrM"},"origin_server_ts":1783672403947,"sender":"@brian:matrix.shikpooshaan.ir","state_key":"","type":"m.room.encryption"}	3
$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	{"device_id":"CHFTPUHNYF"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"DxLRVoI04c76J+8oKZeid63EAjjhIX+bHH7qHSyjjWc/8JxadIvY8VpGsHcWvZp7clD5gsvjENGLgV/dQ6BmDw"}},"unsigned":{"age_ts":1783670198216},"room_id":"!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir","auth_events":["$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14","$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo","$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U"],"prev_events":["$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo"],"content":{"join_rule":"invite"},"depth":4,"hashes":{"sha256":"deYeBnsGD5u7uQXZnj0xDKuC+h8k4wP9jRdP0CmyXcE"},"origin_server_ts":1783670198216,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.join_rules"}	3
$xRkldK4rXGoVy6SNEazvj_642j0z4vnhDKSsno94oMs	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	{"device_id":"CHFTPUHNYF"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"xm/UniEwFuDXmGZyzW8Al3Ri7NUnVpiiIN1D5q8G8VwzghC7mGy2S4PuzOzhqFNhvDwIOT+5riPyJOFXFcxiCQ"}},"unsigned":{"age_ts":1783670198219},"room_id":"!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir","auth_events":["$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14","$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo","$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U"],"prev_events":["$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw"],"content":{"guest_access":"can_join"},"depth":5,"hashes":{"sha256":"TFD9/qePO7io94bDDOsRPHMCVPPSO4aUa5BitM27U9E"},"origin_server_ts":1783670198219,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.guest_access"}	3
$RDmQ4EMxY-FgFox84X5UWejaA1ImHNYssM_nyAlLSbs	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	{"device_id":"CHFTPUHNYF"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"DHh64tqLvzFCAppv8paPdgcYboHpkbihNMnKl1/tSVHhWiLoN0ZjnK9x4WcPnc3Qnv8EedF7kXJ+rR12vkpGCw"}},"unsigned":{"age_ts":1783670198222},"room_id":"!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir","auth_events":["$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14","$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo","$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U"],"prev_events":["$xRkldK4rXGoVy6SNEazvj_642j0z4vnhDKSsno94oMs"],"content":{"algorithm":"m.megolm.v1.aes-sha2"},"depth":6,"hashes":{"sha256":"VYYgGDvTQ76M4n9vOQ2pnHncJofclHOHph4rCgdH9lc"},"origin_server_ts":1783670198222,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.encryption"}	3
$YP8LBjVbUpZKdDbx8B7q46a8-CJwDp3EK1qyDJCSoio	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	{"device_id":"CHFTPUHNYF"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"MCwmdGzqt92TtIX4hpkgiL+mLvbk9Kollu5t+dMIoubwV1w0gL/Vt2FC6q4wHyn6sAo7PJ02XIi7LjDvNVXOAw"}},"unsigned":{"age_ts":1783670198224},"room_id":"!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir","auth_events":["$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14","$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo","$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U"],"prev_events":["$RDmQ4EMxY-FgFox84X5UWejaA1ImHNYssM_nyAlLSbs"],"content":{"history_visibility":"invited"},"depth":7,"hashes":{"sha256":"tUS7LwGhhkLzgOsZ+u0PWkZqsCRm4+fmS0CFONF7qkM"},"origin_server_ts":1783670198224,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.history_visibility"}	3
$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	{"device_id":"NFLNJMUACW"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"MwS9XXaohZnYibidNX97Q1iYwVL1v37kEHyDcUgHKYdD9TkLNvZsifklAlH3jLNPMUTfdDBzBsFKH0xzs51xCA"}},"unsigned":{"age_ts":1783670201883,"replaces_state":"$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg"},"room_id":"!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir","auth_events":["$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U","$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg","$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo","$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw"],"prev_events":["$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg"],"content":{"displayname":"alextaylor98","membership":"join"},"depth":9,"hashes":{"sha256":"LIF+2URzeSZQWRKOiLnf7CPXWn7N1bbPJO7o7p/0oOQ"},"origin_server_ts":1783670201883,"sender":"@alextaylor98:matrix.shikpooshaan.ir","state_key":"@alextaylor98:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$4X_PjJl7QiE3U7c8UuRUw5-rEt6S9u2f1fEzR5tiWso	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	{"device_id":"NFLNJMUACW"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"aJSVIjruw/nszmFLjxNts9VJTjUz2XJXrQiLliSE00LzQvydICRBx+LmpoEMcePTZNATqquyqvZonGtFh0BcAA"}},"unsigned":{"age_ts":1783671328719,"replaces_state":"$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is"},"room_id":"!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir","auth_events":["$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU","$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is","$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo"],"prev_events":["$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is"],"content":{"membership":"leave"},"depth":11,"hashes":{"sha256":"iqsCMBG18iZZsE4nRfoma22ekMgX5q2APnkUKk4feBY"},"origin_server_ts":1783671328719,"sender":"@alextaylor98:matrix.shikpooshaan.ir","state_key":"@alextaylor98:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	{"device_id":"CHFTPUHNYF"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"HtBfIb0EcUcnVmg8ihSo7Cut/rQQ5PHuUdxnhnmuO6E9QhLeM+knZSitVP21VHPl4BNlf9Cq6sEU3+G6IcitDQ"}},"unsigned":{"age_ts":1783670198622,"invite_room_state":[{"content":{"creator":"@alex-taylor:matrix.shikpooshaan.ir","room_version":"10"},"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.create"},{"content":{"join_rule":"invite"},"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.join_rules"},{"content":{"algorithm":"m.megolm.v1.aes-sha2"},"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"","type":"m.room.encryption"},{"content":{"avatar_url":"mxc://matrix.shikpooshaan.ir/WYjvRrHdQwXttYBqKVGTNjYo","displayname":"Alex98","membership":"join"},"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"@alex-taylor:matrix.shikpooshaan.ir","type":"m.room.member"}]},"room_id":"!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir","auth_events":["$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw","$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U","$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14","$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo"],"prev_events":["$YP8LBjVbUpZKdDbx8B7q46a8-CJwDp3EK1qyDJCSoio"],"content":{"displayname":"alextaylor98","is_direct":true,"membership":"invite"},"depth":8,"hashes":{"sha256":"126YQUOjSHtfYtYE0AqBPCcSQ3BuJDzIrk7E5wXhAvs"},"origin_server_ts":1783670198622,"sender":"@alex-taylor:matrix.shikpooshaan.ir","state_key":"@alextaylor98:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$Np7L2UpX2tMrmcWkrhqTkIPPQf2JHPiRI9eGpZCUi9k	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	{"device_id":"NFLNJMUACW","txn_id":"6656538aec814b149a50a1063a3e7912"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"LVYgfU1uPv/N1AvNsKJDnm0K1eGZlkmfA2jHIJi1ClWO2/tpRIFka1HysoIEOs80CMZz3FuHEvg6IG3Q5GDJCQ"}},"unsigned":{"age_ts":1783670208904},"room_id":"!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir","auth_events":["$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U","$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk","$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo"],"prev_events":["$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgAEpABMYZce66r2qCq3B3n4XLm1dQsh9wgOpRxZb93LEXOW8IcjcElAQFTLR+i/6XLBGVH5jRC0V/mS/2DrrSe1+R0+Nfit1QZzbdnSZMmjQn/XXUvgM7k5NBkO9zHwsXIWw4fmIfNPfYyou4hSCJHKeDVnUsbmDvY4//rtu1CV8z+qZmRlCYvNWbsX5KzLrzNIn2qQtQOR8/7hB79JWk9jS3ZLfGEqL4drZGleOfT4U71pBQM+Yde2ASoqAZWPhqOhoHRvHmHppMfIvHqOnmqCKkQiBZ/Y5RtpqsK","device_id":"NFLNJMUACW","sender_key":"AwAHM6NjH1L2MkVS4FUG7WR8KhEnySQziynlcj1+flg","session_id":"L1YLj/45zaFTl8Au9b4uXWsp1q8J+0hZj7GWa+xiulc"},"depth":10,"hashes":{"sha256":"oOiFPESPjVNC0ukp0evcBluztLRIXoyxnYyAd2o+mrI"},"origin_server_ts":1783670208904,"sender":"@alextaylor98:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	{}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"ytIzsWN/rWP3kN2yavRqFet1tNLUR9PUtz4oKMw7u75yXDuVzYYqRf/RknKWv9ueOCdoLuXeARQpScNIJ7VgBA"}},"unsigned":{"age_ts":1783670495456,"replaces_state":"$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY"},"room_id":"!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir","auth_events":["$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU","$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY","$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo","$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M"],"prev_events":["$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg"],"content":{"avatar_url":"mxc://matrix.shikpooshaan.ir/ZvnUeFyFDpHyzXqzuIhncSVg","displayname":"alextaylor98","membership":"join"},"depth":10,"hashes":{"sha256":"ecETeqXlGFD13l+DPmt89n2lIu4cI+4WCInnMR69q0E"},"origin_server_ts":1783670495456,"sender":"@alextaylor98:matrix.shikpooshaan.ir","state_key":"@alextaylor98:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	{}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"d2vRYi+7IFe7iXYDdO6OSOdouMdikWulHXmEkswrw1mxhMjy659gWyIAZSwFFA6VtmMrMxc0L+P86ImHX/sTBA"}},"unsigned":{"age_ts":1783670495857,"replaces_state":"$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk"},"room_id":"!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir","auth_events":["$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U","$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk","$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo","$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw"],"prev_events":["$Ax7Nf2f62jFM6Iukww-bvFvDhxGkhcDQHJOA8GGe3pg"],"content":{"avatar_url":"mxc://matrix.shikpooshaan.ir/ZvnUeFyFDpHyzXqzuIhncSVg","displayname":"alextaylor98","membership":"join"},"depth":12,"hashes":{"sha256":"rWfiEwcXYdCBH8jn2IUl3LHm+pB2zpF0nudHQCk02MQ"},"origin_server_ts":1783670495857,"sender":"@alextaylor98:matrix.shikpooshaan.ir","state_key":"@alextaylor98:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$zM6vJpoUtsXTUex3viHLPy-oiEKdsGSx6OqizILlFdI	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	{"device_id":"NFLNJMUACW","txn_id":"7b0025456d1044839306a2b7a582ec49"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"F13JuymsRrXIuknCGmF/qMunqQE/lfnTU3PaAjdM0WWvWugI2hwMO/7DeCVrfxZQiDytu0DE6m8Iu2ESMRCcDA"}},"unsigned":{"age_ts":1783670515590},"room_id":"!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir","auth_events":["$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U","$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY","$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo"],"prev_events":["$4FmnE3et4KlX8gqLLuDjSYLUFKZG8CgNq8_OPh3TWYY"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgAEpABYZKnAkUnhu76Q/ezCFknM/vue3o1sJ3oKiWLVVHIjPGe18aIn7ZYlbxZ1W3vq0i3sUP0vTS+9rJxLh9lTL55sQkGl0E7C21qtLs7iwYJOAQhKxxq+O11boLtEXaoUpcFoqMfail67AvMBbqx7Xu4j0QzbTCTIb1ayPa9e0XrTM4nWRuMj/y3tSG8Mt7xXQOfHg+yPyORQpEUkfRbUawFvGtyOOvmrzdlnvWZ8M2WXsJoYWOBtah44UXMFevdoFDFNTg15kc2ErJ163XT6anKmcsyEPZRXvkO","device_id":"NFLNJMUACW","sender_key":"AwAHM6NjH1L2MkVS4FUG7WR8KhEnySQziynlcj1+flg","session_id":"IaIyZp/8K6Q2w5b7ZgXg6IXm7Q8GDWgb4BmUlpNp7Is"},"depth":14,"hashes":{"sha256":"ukKR7pxxw+p9srrYghKyhIpgf5zZKzeaWn4etNtCUo4"},"origin_server_ts":1783670515590,"sender":"@alextaylor98:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	{"device_id":"NFLNJMUACW"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"hqf0sCWNZFIr+J2x1umq5eq2kR/IseTVyFMDfCAH1dqNBlvHFoRvHADLtYymo2Ee26Rtu+vPr/rqtJiESBH1Bw"}},"unsigned":{"age_ts":1783672409722,"replaces_state":"$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg"},"room_id":"!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir","auth_events":["$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs","$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg","$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk","$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ"],"prev_events":["$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg"],"content":{"avatar_url":"mxc://matrix.shikpooshaan.ir/ZvnUeFyFDpHyzXqzuIhncSVg","displayname":"alextaylor98","membership":"join"},"depth":9,"hashes":{"sha256":"JeiSHLNn716kII929oQXbRucOecIa9y+zhfKI/HrPrs"},"origin_server_ts":1783672409722,"sender":"@alextaylor98:matrix.shikpooshaan.ir","state_key":"@alextaylor98:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$Er7aPlzKizvAozxf620HpDa-P3Uqu59Re3mkzFi9s8w	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	{"device_id":"YOCYFXUGYQ","txn_id":"c3ca229a6bae443f825a1a3d63064a80"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"QXMwBSXfShviWuaUmgFfGyrSec/1PhTCbNP1uh8IT+vMdThE2OXTy7rh4SOKfn6WQSX1weGx4Eb+HodYx1dQCQ"}},"unsigned":{"age_ts":1783672466067},"room_id":"!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir","auth_events":["$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs","$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk","$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw"],"prev_events":["$6kTTzdJWNwDbZB4BZt4uyMdlAegiGE1HtQPgLUpZBbs"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgAEoAIuEtETbxSYr9L3FSeha4XZpIg/IVkNk5D//z/ybXjTzD2W/gesI+NRtFL3gJiYo0YeJQP/M3G60vmTza7qRJwHobX1CJV0Ykz5G2aeP3WmEOWMLwcwCzEGrNIdTGkMjqiwXBiP0Afe/AE1kE+MOVvimksgVgzR/Un+h9E8Sv3R0b6qbu2Fs/6j3+5CzHrB7LgTJaqj3l/8dfI4fTjzAO8tPCUAtjkp2+4b1NBRFprTUtWLKR1zkyw6idfSXT3SszmT5KR545cEaUnfkuzMKEdAfndVsCPqCh0wObIyefEKjrCrvYUhV/7mUx4SGtdjngPMy9ySzOEg1kcKxYiVwcBE/dj21EEnoKPpVZg+h75wSNrnhbpf4BJRVeJ5HyAkqkqO85KlVNAg9N1DS3VzWQCtQgVIwFul2RME7Ah87c9+tV1ZiXcbGsYwwLNI3rqbYvvQF2atdWKNyjFxqnh240pVIEW9nlGLzCUO9nJSY3uhGNjLloDVzfnCVWi7rCLXC5I7yWkcI+9NJ4rDV4zFmcm24e+3gnqjPhqIV3+nIGZ064vkwgrojQmienpGIHqjWV71Qu9ssvEUINV/bHgVaOpF9FztDTIxCV9X83RqKyslxwWa2LAVY28J8mNyByaxz5k0MNlh+5qHdtmf6HgOdIMgoPAhTBM59qWSo2ucv6YaTPkJnU/sLn0xJuwrpxtLFAJW/fbVs8ZIQYpYRRDDhGFzv3G6S+NBskXhnsRSME9VAQZybYhPkRmsBhasENS7KNmMiYutmpb6A821joX1FZRQAZlBJ2levKpumocWJZ5JAmY8MIAQYVT+rJXvib/8UhvZOhH70Ws4Q86k4jZDabUGgj8oIon3K9rYwZVcClR/PZ3FVK5HZeQ+y2JDwIU0WFZNdqKp0US7wbmRanq3i1mQXEeBLtkwXWWYWR4MXK1jkTAdQ7rfF6nha8t5HUf6+i8H4KBWNl1WPVWpuzxrzn+Q72tfoGW+Iq5scufVFVBt7gw0wodNYJREDyOT3VH1sr86ZUbieOcysr3GkkeUV2DAeG1farI45ZQjdNchuGHSqbi2lXQkfoBvkCVxJrtqQo1VQwaZ/iM4DqboNyZKosVo4uQuqJ5KlPZbq+n8NL7KUAzL+MXQU1m6tDVZ67tosgn494VHnupXkd1Er5KFvdh06rvBNQMD1Nwx5c70NFShWbsBhlIdfrx4gVaHqN5ZswwYy/EZTGVKf5zH8qfKIebPS5QByDnfrxKCxwpKtDYiPEJ7se6iZK7pOFcK8W6IhtvPqwmHfs8+vB2Y9f31RfCMldbtbc8V0T28TLKaII2g3QFBj+33T8sCkpwaA6Ohzgp+wHIGY9RJUK3UR+X+Tubq1zKLu5Q/kQh0NVhYHRprBRRpyr9HQDdt+qTFa75+OgcEKONgkYOnVuXHVaqvvgJxNMbYNFAyitlpGskCUOxq6PDweloUbHVBg","device_id":"YOCYFXUGYQ","sender_key":"R99bo1drmc6MccpCOgPXGOJl0u+ceLj62pp9qxWjjQA","session_id":"G/7rbkp/q1FQo7EHM+ghVl8dMKjTlfDlzdvKE7FX5ms"},"depth":13,"hashes":{"sha256":"1oW+iuNNBz9pGWYxQVb1DOFFiZyhyMJghBaXbJa7xw8"},"origin_server_ts":1783672466067,"sender":"@brian:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$1MLqlvYR1hYyOHAgVVxyOygzdyCxZYc0iLQZrXia5Ls	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	{"device_id":"NFLNJMUACW","txn_id":"14ac1d9579084f3bbea630d591e6d03d"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"EZXRYPL7w9o63tRBx5l+LzCI5wAPmvaHmArFBmGBb9GkFGi22L6dpIw4aRaaQ+1kss15i1A9BjAgf/Xykzu/BA"}},"unsigned":{"age_ts":1783672534283},"room_id":"!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir","auth_events":["$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs","$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk","$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk"],"prev_events":["$Er7aPlzKizvAozxf620HpDa-P3Uqu59Re3mkzFi9s8w"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgCEvAHeJQs2B9z3urxT4KL/mdZa8I9FmZdDhCYyyVcj63GPU0oNO0+qbKoA+DSf3ULrkgmZaXNB+O6Sm2Vl7LDva4WUhpons7RhOA/Hi0A3V+tLggN5oUzC7dGqJtr4o3y+9AQnubW0LFyonu6ro02hUed7aIK81MuxPFREJp2TqSEGt1r3zYg713TFYnESd5uDkiurQZr2AZShuPOBQ2YhlWLoaWka8ZmkC4PLbPQxVgnlUyWDjz3OgVofZUqo1CQRN84BbZmcEBiK0ZhT56FdyUbo3LVpEHHPaD03a+DYlwmEuFhwJBG7Um2C3Mtd7ewXGPr4sUKuDz7F21RCgZoUUN8IGJ17oNq24cLklNuhmlcrbVqdamb3oYqfLQqH2xKcOqHNprbw6o3X6mjqY979hOLJ52X3oduRLgtPFNzvv194ar3H4ZUITRs+hVvSKS0PiY6y8mAUqpYpU3yD65/QStUC1JFZEN4ct6P8KayTIyGNrKiHPH7WtI5saFJwdZGyz1kHcQ00aC/mnzs03BR7RVPYgSfctE1Adq7iN9V5S6MmoRzp5IEx/rV23LhyVunvVIRf3++KzVLMlbaCGNhyHppRYmczTyKseNuJd2rnjQYTXnAnDL5X3ElggyeJgFCifnL1BN4OcSvPEx5hfUKLET1zWkTsBk+pGcU78185Vj0GDJMhbX/9XPKb0wn9obNpHxSbzILZVL7IdMPpnulHT1NvVhak71HulvPZF4QayEqdEgatDspnyIOmuTDh4032tIVf6nKNoGW273P3orMmTRIpzs8nHH5szD+w5j2Oh3gf0gPzqpiwQ/1njv6Wl6J70nxOdCgJHKGhuyqu2AF1K3uSnDHoWzRF0CqfAN+OeMFYIy+9KND4M8RPjmbhvMY76uosMaSbFWffnu3DrDX7AbHlRvD7ykeKVXPfkk0vOji5pRVMiK0lknhznkaXMaOFZwDJV1PW11zKWRBU8PSRZa4LxCvXWKKyTURo4C9+PEyODcQFEA4u5fgMP1qVZ6fJfsIhiFrnuq6j86E1SCo7wdS2TBeHfjjP300f+tQ10olx6OxoG18nE19fLnsuH5EuKaHK7VDEfBW5KN6kG9zXMMkU+FBTNGoIgGxwxq8eReb8/0FmRRtVl09GAWcFR+uRHfIEMJ/0MwJiCz9xHr38zCygJYMLqd194sCNk6GvZNd966LgMP7z7g3rZs2u1r1hn1T8eh8yiIidEGq3WwyEqupu0vybLDoxTDFfBae7TzE7aN4haMoDkPyn8YVQhgpqhSyYkliyp6Iu88hLyGbIdXiZ5dlSOui+UbfD23baV+VFnAace4m1OpAsoinacr4XPHc4f+54GlwS0/tcAudBP93VnPyk+JmCQOq/CtZMh8DwPCacL0parvhaopz2lptYUPkuv6G9mSVXmI9f/P/xpPCMFjybyoJtMED","device_id":"NFLNJMUACW","sender_key":"AwAHM6NjH1L2MkVS4FUG7WR8KhEnySQziynlcj1+flg","session_id":"7vhvzni8iU4fwPub9cwbMJFZHa6uM85wWQR1RSJkZKA"},"depth":14,"hashes":{"sha256":"g6dA2KKGdiWjURNaqBzbhZ9qGeJMw7r8Hd93EOY8+9U"},"origin_server_ts":1783672534283,"sender":"@alextaylor98:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$6UQ-qIZULcBYRTpiEHtIjLH-lHfTx1ipANQeBo3ldw0	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	{"device_id":"YOCYFXUGYQ"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"+44SjD/rroxaL0cLJmhkbSbtPLFQyumCmQ47GlGnFfJRqnbU/qMVxPAB7dsMHOY//JD8olftGrknMcKF28vrAQ"}},"unsigned":{"age_ts":1783672403949},"room_id":"!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir","auth_events":["$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs","$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk","$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw"],"prev_events":["$d-DLbKD_o_R1rzHrZD8hyXWTZsKArLYnNTv9_1HRatE"],"content":{"history_visibility":"invited"},"depth":7,"hashes":{"sha256":"zt7GjCuNOu0ux0XuvGVeVIQS0qvVjLPj4Ec5pA7lfqk"},"origin_server_ts":1783672403949,"sender":"@brian:matrix.shikpooshaan.ir","state_key":"","type":"m.room.history_visibility"}	3
$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	{"device_id":"YOCYFXUGYQ"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"fjAEHFLY1vr+uTeKnoLDHkOn37MXjB4B7MOQUl6/+VZeypWP5jvc89Ss45zYk6C9TVP2Zmy7ITuQWKnVihXrCw"}},"unsigned":{"age_ts":1783672404417,"invite_room_state":[{"content":{"creator":"@brian:matrix.shikpooshaan.ir","room_version":"10"},"sender":"@brian:matrix.shikpooshaan.ir","state_key":"","type":"m.room.create"},{"content":{"join_rule":"invite"},"sender":"@brian:matrix.shikpooshaan.ir","state_key":"","type":"m.room.join_rules"},{"content":{"algorithm":"m.megolm.v1.aes-sha2"},"sender":"@brian:matrix.shikpooshaan.ir","state_key":"","type":"m.room.encryption"},{"content":{"displayname":"brian","membership":"join"},"sender":"@brian:matrix.shikpooshaan.ir","state_key":"@brian:matrix.shikpooshaan.ir","type":"m.room.member"}]},"room_id":"!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir","auth_events":["$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw","$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ","$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs","$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk"],"prev_events":["$6UQ-qIZULcBYRTpiEHtIjLH-lHfTx1ipANQeBo3ldw0"],"content":{"avatar_url":"mxc://matrix.shikpooshaan.ir/ZvnUeFyFDpHyzXqzuIhncSVg","displayname":"alextaylor98","is_direct":true,"membership":"invite"},"depth":8,"hashes":{"sha256":"zlYRhTPo6H9Ff2W4U3WJcVAshJD8d/qCQv+hb+QqSy8"},"origin_server_ts":1783672404417,"sender":"@brian:matrix.shikpooshaan.ir","state_key":"@alextaylor98:matrix.shikpooshaan.ir","type":"m.room.member"}	3
$oZTAqRbttOiPuTLHUN_H2ptq2VqGzcx4o8urdtkZR9A	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	{"device_id":"NFLNJMUACW","txn_id":"a39f4fe6670a4bf786fc9eff75e2bb50"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"kszQiAHJIDjK34WXa/2TOlHvBgIsYl65H/MAGtq5rCeHwBr6ocIFE+D7bIyUxkbJCTrj5qiLGcjJeQ/qVNk5Dw"}},"unsigned":{"age_ts":1783672414307},"room_id":"!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir","auth_events":["$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs","$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk","$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk"],"prev_events":["$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgAEqABgL/i/uJsYRJmXVJgfnPcrpbyc2Q+i6ij2m3ee44M/kpql3nxzOzJ4TGztI7/t6gGniMirkdJ+IUiZeR1JKB9bOtfmQaP71LJOvy1EDPDDHh1ShHd3NugMngnMx1XhI1eMmRIjDS7B80Y00Aq0Rzzua8+5mrpVdgPD+TR74ma+tpmWOJKnkA14/qdMZUk4uSw3BOrlQqZMFYIFXq/Yl9V82yiYOJ3YUujP1tZnloUobvZBiRUhHIjdP6hX7CTe9Z6TNdaQhKc/BgaldBrt3WElHA0l2HovL3zINgeGLbpaXq6rQCknw4kDg","device_id":"NFLNJMUACW","sender_key":"AwAHM6NjH1L2MkVS4FUG7WR8KhEnySQziynlcj1+flg","session_id":"7vhvzni8iU4fwPub9cwbMJFZHa6uM85wWQR1RSJkZKA"},"depth":10,"hashes":{"sha256":"UWUZM7Aw/B6apjVkDEtNn2zePq0wKapASYHhUy2pHwc"},"origin_server_ts":1783672414307,"sender":"@alextaylor98:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$x-laZQjLN_ybbNbLzACqCd1-j4uqjJ9UBDzWYpYGv54	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	{"device_id":"NFLNJMUACW","txn_id":"c3bd497a4cca47a7b8e4ddd3575f5d36"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"HEINIM4qGaL+aANobXiz86wuEn4+iOywEPlO800vjzwwcgKFfxM07H005rhxVqaYG04YNz1trxY0GH34+DbIDw"}},"unsigned":{"age_ts":1783672423821},"room_id":"!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir","auth_events":["$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs","$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk","$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk"],"prev_events":["$oZTAqRbttOiPuTLHUN_H2ptq2VqGzcx4o8urdtkZR9A"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgBEvAH5SYLAHg1Ch/3JPju3JOf9aMaSi9RkkV/EE3Xnazx38Krs6XsSHw96Wo1sWOCedq/buMu6Ni7p+AIQIQN+fkowy0C8Fhr7BPkGlUMS09Ceo9ld4ww/KZYDVlDt6gf91Qyr1gxACzaKA0Q2d3HkAswBxSNnjb5RezYhy9wVaLXLIJkaRv+qp5zbIim4a7ga/1lSN020dQsWuh2ZZqUgvegffF+gEuGU8mr8E86lqrCCwk2sXE5Ayz+eGsZ7AfMdesZJ4OUEhN4UXaSvgxjyDXrJiObaP3sp6lVI5mQ7zYnQaWnZFlTHtB3hsy253OAI/IWYT5580HawV9a45aTt1Tn5vt549pTUpUWjknFyfUIUUJl7OHmt7W/z2uRFlSYn5l6xYz4xrFGIEIIHb3wWq5jbEZ/PkPJZOUFAQIZvqobRfurSyuNEouuzD9fNYQ5fhFS4FnKenRhe/rtjoPyoazLyCmhwGHwSK7yanQb3YhyXq8elglWsDzBABqva6IN8Ec/gLk64lXblkMMWNrk6h9PjAGqi4C7z7yIgfIeAocYHPpssg2NcdzigTIDRLf5CKn/47YoxAT3mmLk00Qs7gQ0oqCdU2CRFf5Ds1sYYN6V2bSMaoFh3IX166gvZ+r4z/URjvy3gyHbLQyoqVGhp1BnDKuJoXI/La2kSh2jT/GBKAfJBhkTjSIkFNOO/pRiMWxaemr7FsVgz9AMHxa0VNIaONElIbY5Z8huUiRxICPaWKFWqF8bqrXYNK2Ldb82fmNRpbKDHpVcjdWk7BmpzZsmrqGJeZYWI7ZqqM4dM7BeZRoa3tj/1GR66h6wMdQLo9i6m8IKcftR9Rz/VfatPk2bovl3Q7n0yp7gk70/D826KudBfjoChEh6Z4FKrLR3x+unD+MwzhJLxh/Ud5+PgW2tpF57H6rvn7ycohau8fztipIWIIx1d/uJOgPFREpsZ0DN+GUkUGT6q+IasD5l1J+mUFlr/fPpDjuAy5v7dtKexSi2QZlnD2ft2kgcjE437YH32jyzADtXjWBufJd5iy0IWKXSZvUBcTsR+AxD49e1DmDvUWzfPRAb9HZWTOwYMqZjHGPa7g0IkjaP+k8VjfddT5JcVdGa6sCHDZ2ZUSL2UGcIyb1CbqBFz7xVOty7rhTRaeTCa0H8Jx4PaPViRX+wnSxxYf+V150WC1TfJ56R/oQgUVjEtgXlwCFjF0S1x71yAmA4ssroBcNg4SwzOWv5YDdVvfaRxMB2zyKhBWQLzZ3x9xFyRDeZlIa6WVeKAKafJwOs/g2oqsIx0EDSJM/VEJeiKtj9OmljYPGk/lP4Acqs6e3/5V8u3TWXe1MqTZoxWs84NdgFio1Qyz/1AJciktsVsDwTEGsGqvdDFjxqdijIIevlrmGcY3vjS6KAWceP45mgh7XCKD87x+gC6w5jXCrSKZMCN9UK","device_id":"NFLNJMUACW","sender_key":"AwAHM6NjH1L2MkVS4FUG7WR8KhEnySQziynlcj1+flg","session_id":"7vhvzni8iU4fwPub9cwbMJFZHa6uM85wWQR1RSJkZKA"},"depth":11,"hashes":{"sha256":"5A7EEZpN0QxtyYjNHCawz/0Bf83oRyX/yw91UZ0b6rc"},"origin_server_ts":1783672423821,"sender":"@alextaylor98:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
$6kTTzdJWNwDbZB4BZt4uyMdlAegiGE1HtQPgLUpZBbs	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	{"device_id":"YOCYFXUGYQ","txn_id":"7d6fa7ab6b304e5bbd27c98788d09c6c"}	{"signatures":{"matrix.shikpooshaan.ir":{"ed25519:a_LvlB":"ro3CWxEixKdr0l87LKj0AO0rujAR/KVB5rXvWz3vHLJO9JbcWf6OT/TVn/u4qn2Z+vdOAqYpm2blHO7WZag9AA"}},"unsigned":{"age_ts":1783672424590},"room_id":"!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir","auth_events":["$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs","$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk","$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw"],"prev_events":["$x-laZQjLN_ybbNbLzACqCd1-j4uqjJ9UBDzWYpYGv54"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgAEpABGcdk2JKs+wxUAGhGRJgaBqWHiMTKOnFJ5GNf6BcM5Gns8/wa9X/EkSywsrWg84Oew25YUXH1psO+myr1wH7ZdtO1V7T2UKARgyC3P+rsrW9yqjyij6BSFhj80v9q/taPnWJ9lx3+diDdnvLklOhB8pnXazOU/pKueahz8Vi24A/mHIIOjnHgqSJkZG9BFkuyTR5C9U8jMMKowHSpByqXu1Gsb2aVL+PDKa3gaeiefxjvSOdYZWn6hRKZ68AWx3A9USEX8EvhqoCSHF4l8eiCOu+EJPetRtQC","device_id":"YOCYFXUGYQ","sender_key":"R99bo1drmc6MccpCOgPXGOJl0u+ceLj62pp9qxWjjQA","session_id":"yAyQ21rcBzLXk5D5369WGOm7T5fvyYkjCI/KwyFdjqo"},"depth":12,"hashes":{"sha256":"V0CTejdyni9Azy20x668iM/mbyY0XL22zGYESo7/hF8"},"origin_server_ts":1783672424590,"sender":"@brian:matrix.shikpooshaan.ir","type":"m.room.encrypted"}	3
\.


--
-- Data for Name: event_labels; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_labels (event_id, label, room_id, topological_ordering) FROM stdin;
\.


--
-- Data for Name: event_push_actions; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_push_actions (room_id, event_id, user_id, profile_tag, actions, topological_ordering, stream_ordering, notif, highlight, unread, thread_id) FROM stdin;
!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$ZzByIqF4yAyhZDP-bd2SHZXxQ5OlHpoF1y4i0fQps0A	@brianrockwell:matrix.shikpooshaan.ir	\N	["notify",{"set_tweak":"sound","value":"default"},{"set_tweak":"highlight","value":false}]	14	15	1	0	0	main
!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$O8ybWunHmG8woUBjshPybaeo067xS8r1LX3jsFYbF_M	@brianrockwell:matrix.shikpooshaan.ir	\N	["notify",{"set_tweak":"sound","value":"default"},{"set_tweak":"highlight","value":false}]	15	16	1	0	0	main
!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$OYsK4JS05N5L1dz1HFkKo5nIk3YnZZbM5RB4ZkCos6Q	@brianrockwell:matrix.shikpooshaan.ir	\N	["notify",{"set_tweak":"sound","value":"default"},{"set_tweak":"highlight","value":false}]	16	17	1	0	0	main
!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU	@brianrockwell:matrix.shikpooshaan.ir	\N	["notify",{"set_tweak":"highlight","value":false},{"set_tweak":"sound","value":"default"}]	8	26	1	0	0	main
!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE	@alextaylor:matrix.shikpooshaan.ir	\N	["notify",{"set_tweak":"highlight","value":false},{"set_tweak":"sound","value":"default"}]	8	79	1	0	0	main
!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg	@alextaylor98:matrix.shikpooshaan.ir	\N	["notify",{"set_tweak":"highlight","value":false},{"set_tweak":"sound","value":"default"}]	8	87	1	0	0	main
\.


--
-- Data for Name: event_push_actions_staging; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_push_actions_staging (event_id, user_id, actions, notif, highlight, unread, thread_id, inserted_ts) FROM stdin;
\.


--
-- Data for Name: event_push_summary; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_push_summary (user_id, room_id, notif_count, stream_ordering, unread_count, last_receipt_stream_ordering, thread_id) FROM stdin;
@brianrockwell:matrix.shikpooshaan.ir	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	3	17	0	14	main
@brianrockwell:matrix.shikpooshaan.ir	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	1	26	0	\N	main
@ali:matrix.shikpooshaan.ir	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	0	27	0	18	main
@ali:matrix.shikpooshaan.ir	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	0	35	0	37	main
@brianrockwell:matrix.shikpooshaan.ir	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	0	44	0	44	main
@alipaz:matrix.shikpooshaan.ir	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	0	53	0	62	main
@alex-taylor:matrix.shikpooshaan.ir	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	0	67	0	67	main
@alextaylor:matrix.shikpooshaan.ir	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	1	79	0	\N	main
@alextaylor98:matrix.shikpooshaan.ir	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	1	87	0	\N	main
@ali:matrix.shikpooshaan.ir	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	0	94	0	70	main
@brian:matrix.shikpooshaan.ir	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	0	108	0	109	main
\.


--
-- Data for Name: event_push_summary_last_receipt_stream_id; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_push_summary_last_receipt_stream_id (lock, stream_id) FROM stdin;
X	29
\.


--
-- Data for Name: event_push_summary_stream_ordering; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_push_summary_stream_ordering (lock, stream_ordering) FROM stdin;
X	109
\.


--
-- Data for Name: event_relations; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_relations (event_id, relates_to_id, relation_type, aggregation_key) FROM stdin;
\.


--
-- Data for Name: event_reports; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_reports (id, received_ts, room_id, event_id, user_id, reason, content) FROM stdin;
\.


--
-- Data for Name: event_search; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_search (event_id, room_id, sender, key, vector, origin_server_ts, stream_ordering) FROM stdin;
\.


--
-- Data for Name: event_to_state_groups; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_to_state_groups (event_id, state_group) FROM stdin;
$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE	2
$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag	3
$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4	4
$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00	5
$prihY7_PFyGlMWv4ENxfD2iizqJyMNoQbig1eNbs7UY	6
$A960r4luhjM4-N8ZlQT_oZvugpHLDMyoL7N8LsvnnlI	7
$-Yvs0xYmtCB-d_v2Z7zGwQj8jvY11ZDzzMQaPKj3DHw	8
$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA	9
$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI	10
$X8K_VFEiQvuPoOUsEKgfuQVwB45D2aU4Otzgi42XIKA	10
$M3CKOhgprwuo0MJ8t87vLcopCe-GbCoKg7i0182GwRY	10
$QRnyjHg7tbmZzQ96yfYxKL3mWswOmQhqDX8uf-mQqZY	10
$VDxFUMtILxytmO-s2kFHdkmCGyfSuMGfvtuZK6zZf3Q	10
$ZzByIqF4yAyhZDP-bd2SHZXxQ5OlHpoF1y4i0fQps0A	10
$O8ybWunHmG8woUBjshPybaeo067xS8r1LX3jsFYbF_M	10
$OYsK4JS05N5L1dz1HFkKo5nIk3YnZZbM5RB4ZkCos6Q	10
$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU	11
$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU	13
$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY	14
$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	15
$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M	16
$pR2OnVDcJjiIYWrhS9nEoocIiQESVvpdsQfYu64Jhp4	17
$uPRJ79eQQkEtz9GsgfXr0y-f3JPTNkvLdecu65l13Eo	18
$h_Aewnb-d3kjnDHdRL1B_3KhQvXaRyb0xNw9N0ctEUM	19
$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU	20
$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg	21
$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY	23
$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	24
$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM	25
$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0	26
$VWhXTrJ895IdYCilHYuIInhbeUE8rsIzTWUjb7gSL1M	27
$egxiNGcQc850qQa01Ox8mP5yoEj1Q5Ex-bzUWtN4W5c	28
$JrVCAJ9f2DtGYEV120F1HrAvVIjWumvsdBmenypJvNY	29
$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I	30
$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg	31
$38B-Weejbpnil6mQvy5fn8Vc0qGoDasfdZ5t3hdt-u4	31
$uMZ-ZidlxCHhXanXLN1-ytrhTVb9h1j1K2u-ZEvFmLI	31
$5P00VdpT2xziYLl8SJGwC9nL-vpZPERv25JcU1tQEy4	31
$bJp5268AbMlSvGSOLwL1QuROb-6Q8w3--hz5R4shhsE	31
$nX0BIvxzfiMjoGPKmnp3zaDJ_Lwe4buCfaVfv4wKHAA	31
$MKIG_xPNWt7pAeRQie1-ff8u79mcVuNrOYFINP7GYb8	31
$C3PYkudwbc1C1vhjMWGEuUhQS2SwdWK2dFzNgexrfug	31
$7683AfvdvVGbujZUglQ3dOVMhLfC5n8sd4USeya9_9A	31
$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg	33
$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY	34
$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	35
$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI	36
$14g0e4tQc-4i_Vdo1U2pNGwl-QbxmmrnRRA2DOZjnYs	37
$_VnHK-C5uJEI_LtZ6Edmfv4J6T35_tYN-Em2qO-sRyU	38
$NFsUH4yHF1VWTTF3R7erS73-88ifZ3r1Lk1lrp7s5rI	39
$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA	40
$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA	41
$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg	43
$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	44
$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	45
$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE	46
$Z2e6JO81o3A3wHKKBJSTB-q68xOeUakOBJi-6H0er2I	47
$oUHPDjqakCWglPegHTY6TC8e_Qaqub-Yoh_XfUKTjjc	48
$ZaaKYiCE_n9AzqSGJntdPRcRM7BRhym69EHSrFwgdac	49
$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA	50
$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s	51
$ExyXltZ8XVgCS4zv7cy-lT_wdLHC4I6gFOEe9WIXLxo	51
$afVsFJEIQ2l3SduwcVGDn3fVRxWpwp6Z294e_VvMTFc	51
$2F_r1QYHaObawQDNr91dUNyPG7vMIy94v6I6KmYFAYk	51
$_H2DZoM2QWFOqEQG70J87qAZM3H467C9Jlh4_5gWzzI	51
$nOti7xJQKHyROEyoGtsBKtap-hocvso_bgZ53R7EE8U	51
$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg	52
$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A	53
$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo	54
$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k	55
$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4	57
$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	58
$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY	59
$ekFlSyfMDYeG34nr1qqB9Bi-AbjdiJ_J9bLNNsHuLKs	60
$zc8tOpOdwrt2LhO6ZIPa8Tv1PyclAu-E3cFNvQTB_rw	61
$KTjmV6JHWFiwg8JXvrYWGjeMxJtAvzZoRDulWpsNaSw	62
$Dc3jotNRZdjzDW_y7eg_fRWeyXs382gqm43HSX5lbOI	63
$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE	64
$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U	66
$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	67
$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo	68
$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw	69
$xRkldK4rXGoVy6SNEazvj_642j0z4vnhDKSsno94oMs	70
$RDmQ4EMxY-FgFox84X5UWejaA1ImHNYssM_nyAlLSbs	71
$YP8LBjVbUpZKdDbx8B7q46a8-CJwDp3EK1qyDJCSoio	72
$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg	73
$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk	74
$Np7L2UpX2tMrmcWkrhqTkIPPQf2JHPiRI9eGpZCUi9k	74
$Ax7Nf2f62jFM6Iukww-bvFvDhxGkhcDQHJOA8GGe3pg	74
$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is	75
$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY	76
$4FmnE3et4KlX8gqLLuDjSYLUFKZG8CgNq8_OPh3TWYY	76
$zM6vJpoUtsXTUex3viHLPy-oiEKdsGSx6OqizILlFdI	76
$4X_PjJl7QiE3U7c8UuRUw5-rEt6S9u2f1fEzR5tiWso	77
$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs	79
$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	80
$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk	81
$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ	82
$lzdi23BC1bOIDnNJnuoZzfFYBb3iv4PDZ1pw9Tg4z1M	83
$d-DLbKD_o_R1rzHrZD8hyXWTZsKArLYnNTv9_1HRatE	84
$6UQ-qIZULcBYRTpiEHtIjLH-lHfTx1ipANQeBo3ldw0	85
$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg	86
$oZTAqRbttOiPuTLHUN_H2ptq2VqGzcx4o8urdtkZR9A	87
$x-laZQjLN_ybbNbLzACqCd1-j4uqjJ9UBDzWYpYGv54	87
$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk	87
$6kTTzdJWNwDbZB4BZt4uyMdlAegiGE1HtQPgLUpZBbs	87
$Er7aPlzKizvAozxf620HpDa-P3Uqu59Re3mkzFi9s8w	87
$1MLqlvYR1hYyOHAgVVxyOygzdyCxZYc0iLQZrXia5Ls	87
\.


--
-- Data for Name: event_txn_id_device_id; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_txn_id_device_id (event_id, room_id, user_id, device_id, txn_id, inserted_ts) FROM stdin;
$ExyXltZ8XVgCS4zv7cy-lT_wdLHC4I6gFOEe9WIXLxo	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	m1783627140987.6	1783627143366
$afVsFJEIQ2l3SduwcVGDn3fVRxWpwp6Z294e_VvMTFc	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	m1783627149094.7	1783627148163
$2F_r1QYHaObawQDNr91dUNyPG7vMIy94v6I6KmYFAYk	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	m1783627150999.8	1783627149960
$_H2DZoM2QWFOqEQG70J87qAZM3H467C9Jlh4_5gWzzI	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	m1783627152419.9	1783627151212
$nOti7xJQKHyROEyoGtsBKtap-hocvso_bgZ53R7EE8U	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	m1783627160242.10	1783627159068
$Np7L2UpX2tMrmcWkrhqTkIPPQf2JHPiRI9eGpZCUi9k	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	6656538aec814b149a50a1063a3e7912	1783670209094
$Ax7Nf2f62jFM6Iukww-bvFvDhxGkhcDQHJOA8GGe3pg	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	855a30dd1bde4b2997be5b2e202c4798	1783670231524
$4FmnE3et4KlX8gqLLuDjSYLUFKZG8CgNq8_OPh3TWYY	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	6911d2452dd94064a8c20684d341370f	1783670505879
$zM6vJpoUtsXTUex3viHLPy-oiEKdsGSx6OqizILlFdI	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	7b0025456d1044839306a2b7a582ec49	1783670515670
$oZTAqRbttOiPuTLHUN_H2ptq2VqGzcx4o8urdtkZR9A	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	a39f4fe6670a4bf786fc9eff75e2bb50	1783672414392
$x-laZQjLN_ybbNbLzACqCd1-j4uqjJ9UBDzWYpYGv54	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	c3bd497a4cca47a7b8e4ddd3575f5d36	1783672423993
$6kTTzdJWNwDbZB4BZt4uyMdlAegiGE1HtQPgLUpZBbs	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	7d6fa7ab6b304e5bbd27c98788d09c6c	1783672424703
$Er7aPlzKizvAozxf620HpDa-P3Uqu59Re3mkzFi9s8w	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	c3ca229a6bae443f825a1a3d63064a80	1783672466139
$1MLqlvYR1hYyOHAgVVxyOygzdyCxZYc0iLQZrXia5Ls	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	14ac1d9579084f3bbea630d591e6d03d	1783672534359
\.


--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.events (topological_ordering, event_id, type, room_id, content, unrecognized_keys, processed, outlier, depth, origin_server_ts, received_ts, sender, contains_url, instance_name, stream_ordering, state_key, rejection_reason) FROM stdin;
1	$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE	m.room.create	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	\N	\N	t	f	1	1783625247853	1783625247964	@brianrockwell:matrix.shikpooshaan.ir	f	master	2		\N
2	$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag	m.room.member	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	\N	\N	t	f	2	1783625248099	1783625248166	@brianrockwell:matrix.shikpooshaan.ir	f	master	3	@brianrockwell:matrix.shikpooshaan.ir	\N
3	$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4	m.room.power_levels	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	\N	\N	t	f	3	1783625248330	1783625248590	@brianrockwell:matrix.shikpooshaan.ir	f	master	4		\N
4	$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00	m.room.join_rules	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	\N	\N	t	f	4	1783625248374	1783625248590	@brianrockwell:matrix.shikpooshaan.ir	f	master	5		\N
5	$prihY7_PFyGlMWv4ENxfD2iizqJyMNoQbig1eNbs7UY	m.room.guest_access	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	\N	\N	t	f	5	1783625248376	1783625248590	@brianrockwell:matrix.shikpooshaan.ir	f	master	6		\N
6	$A960r4luhjM4-N8ZlQT_oZvugpHLDMyoL7N8LsvnnlI	m.room.encryption	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	\N	\N	t	f	6	1783625248378	1783625248590	@brianrockwell:matrix.shikpooshaan.ir	f	master	7		\N
7	$-Yvs0xYmtCB-d_v2Z7zGwQj8jvY11ZDzzMQaPKj3DHw	m.room.history_visibility	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	\N	\N	t	f	7	1783625248380	1783625248590	@brianrockwell:matrix.shikpooshaan.ir	f	master	8		\N
8	$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA	m.room.member	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	\N	\N	t	f	8	1783625248705	1783625248830	@brianrockwell:matrix.shikpooshaan.ir	f	master	9	@ali:matrix.shikpooshaan.ir	\N
9	$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI	m.room.member	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	\N	\N	t	f	9	1783625265280	1783625265372	@ali:matrix.shikpooshaan.ir	f	master	10	@ali:matrix.shikpooshaan.ir	\N
10	$X8K_VFEiQvuPoOUsEKgfuQVwB45D2aU4Otzgi42XIKA	m.room.encrypted	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	\N	\N	t	f	10	1783625444076	1783625444211	@ali:matrix.shikpooshaan.ir	f	master	11	\N	\N
11	$M3CKOhgprwuo0MJ8t87vLcopCe-GbCoKg7i0182GwRY	m.room.encrypted	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	\N	\N	t	f	11	1783625446240	1783625446380	@ali:matrix.shikpooshaan.ir	f	master	12	\N	\N
12	$QRnyjHg7tbmZzQ96yfYxKL3mWswOmQhqDX8uf-mQqZY	m.room.encrypted	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	\N	\N	t	f	12	1783625457313	1783625457386	@ali:matrix.shikpooshaan.ir	f	master	13	\N	\N
13	$VDxFUMtILxytmO-s2kFHdkmCGyfSuMGfvtuZK6zZf3Q	m.room.encrypted	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	\N	\N	t	f	13	1783625469594	1783625469651	@ali:matrix.shikpooshaan.ir	f	master	14	\N	\N
14	$ZzByIqF4yAyhZDP-bd2SHZXxQ5OlHpoF1y4i0fQps0A	m.room.encrypted	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	\N	\N	t	f	14	1783625471083	1783625471181	@ali:matrix.shikpooshaan.ir	f	master	15	\N	\N
15	$O8ybWunHmG8woUBjshPybaeo067xS8r1LX3jsFYbF_M	m.room.encrypted	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	\N	\N	t	f	15	1783625472752	1783625472812	@ali:matrix.shikpooshaan.ir	f	master	16	\N	\N
16	$OYsK4JS05N5L1dz1HFkKo5nIk3YnZZbM5RB4ZkCos6Q	m.room.encrypted	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	\N	\N	t	f	16	1783625477574	1783625477631	@ali:matrix.shikpooshaan.ir	f	master	17	\N	\N
17	$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU	m.room.member	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	\N	\N	t	f	17	1783625679449	1783625679535	@brianrockwell:matrix.shikpooshaan.ir	f	master	18	@brianrockwell:matrix.shikpooshaan.ir	\N
1	$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU	m.room.create	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	\N	\N	t	f	1	1783625715065	1783625715136	@alextaylor98:matrix.shikpooshaan.ir	f	master	19		\N
2	$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY	m.room.member	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	\N	\N	t	f	2	1783625715233	1783625715298	@alextaylor98:matrix.shikpooshaan.ir	f	master	20	@alextaylor98:matrix.shikpooshaan.ir	\N
3	$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	m.room.power_levels	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	\N	\N	t	f	3	1783625715407	1783625715653	@alextaylor98:matrix.shikpooshaan.ir	f	master	21		\N
4	$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M	m.room.join_rules	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	\N	\N	t	f	4	1783625715455	1783625715653	@alextaylor98:matrix.shikpooshaan.ir	f	master	22		\N
5	$pR2OnVDcJjiIYWrhS9nEoocIiQESVvpdsQfYu64Jhp4	m.room.guest_access	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	\N	\N	t	f	5	1783625715457	1783625715653	@alextaylor98:matrix.shikpooshaan.ir	f	master	23		\N
6	$uPRJ79eQQkEtz9GsgfXr0y-f3JPTNkvLdecu65l13Eo	m.room.encryption	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	\N	\N	t	f	6	1783625715459	1783625715653	@alextaylor98:matrix.shikpooshaan.ir	f	master	24		\N
7	$h_Aewnb-d3kjnDHdRL1B_3KhQvXaRyb0xNw9N0ctEUM	m.room.history_visibility	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	\N	\N	t	f	7	1783625715461	1783625715653	@alextaylor98:matrix.shikpooshaan.ir	f	master	25		\N
8	$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU	m.room.member	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	\N	\N	t	f	8	1783625715800	1783625715959	@alextaylor98:matrix.shikpooshaan.ir	f	master	26	@brianrockwell:matrix.shikpooshaan.ir	\N
9	$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg	m.room.member	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	\N	\N	t	f	9	1783625720630	1783625720690	@brianrockwell:matrix.shikpooshaan.ir	f	master	27	@brianrockwell:matrix.shikpooshaan.ir	\N
1	$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY	m.room.create	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	\N	\N	t	f	1	1783626314313	1783626314412	@brianrockwell:matrix.shikpooshaan.ir	f	master	28		\N
2	$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	m.room.member	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	\N	\N	t	f	2	1783626314534	1783626314593	@brianrockwell:matrix.shikpooshaan.ir	f	master	29	@brianrockwell:matrix.shikpooshaan.ir	\N
3	$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM	m.room.power_levels	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	\N	\N	t	f	3	1783626314694	1783626314936	@brianrockwell:matrix.shikpooshaan.ir	f	master	30		\N
4	$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0	m.room.join_rules	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	\N	\N	t	f	4	1783626314739	1783626314936	@brianrockwell:matrix.shikpooshaan.ir	f	master	31		\N
5	$VWhXTrJ895IdYCilHYuIInhbeUE8rsIzTWUjb7gSL1M	m.room.guest_access	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	\N	\N	t	f	5	1783626314741	1783626314936	@brianrockwell:matrix.shikpooshaan.ir	f	master	32		\N
6	$egxiNGcQc850qQa01Ox8mP5yoEj1Q5Ex-bzUWtN4W5c	m.room.encryption	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	\N	\N	t	f	6	1783626314742	1783626314936	@brianrockwell:matrix.shikpooshaan.ir	f	master	33		\N
7	$JrVCAJ9f2DtGYEV120F1HrAvVIjWumvsdBmenypJvNY	m.room.history_visibility	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	\N	\N	t	f	7	1783626314744	1783626314936	@brianrockwell:matrix.shikpooshaan.ir	f	master	34		\N
8	$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I	m.room.member	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	\N	\N	t	f	8	1783626315047	1783626315173	@brianrockwell:matrix.shikpooshaan.ir	f	master	35	@ali:matrix.shikpooshaan.ir	\N
9	$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg	m.room.member	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	\N	\N	t	f	9	1783626325202	1783626325276	@ali:matrix.shikpooshaan.ir	f	master	36	@ali:matrix.shikpooshaan.ir	\N
3	$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	m.room.power_levels	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	\N	\N	t	f	3	1783626825536	1783626825849	@alex-taylor:matrix.shikpooshaan.ir	f	master	47		\N
4	$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI	m.room.join_rules	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	\N	\N	t	f	4	1783626825595	1783626825849	@alex-taylor:matrix.shikpooshaan.ir	f	master	48		\N
5	$14g0e4tQc-4i_Vdo1U2pNGwl-QbxmmrnRRA2DOZjnYs	m.room.guest_access	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	\N	\N	t	f	5	1783626825598	1783626825849	@alex-taylor:matrix.shikpooshaan.ir	f	master	49		\N
6	$_VnHK-C5uJEI_LtZ6Edmfv4J6T35_tYN-Em2qO-sRyU	m.room.encryption	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	\N	\N	t	f	6	1783626825600	1783626825849	@alex-taylor:matrix.shikpooshaan.ir	f	master	50		\N
7	$NFsUH4yHF1VWTTF3R7erS73-88ifZ3r1Lk1lrp7s5rI	m.room.history_visibility	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	\N	\N	t	f	7	1783626825602	1783626825849	@alex-taylor:matrix.shikpooshaan.ir	f	master	51		\N
10	$38B-Weejbpnil6mQvy5fn8Vc0qGoDasfdZ5t3hdt-u4	m.room.encrypted	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	\N	\N	t	f	10	1783626337459	1783626337532	@brianrockwell:matrix.shikpooshaan.ir	f	master	37	\N	\N
13	$bJp5268AbMlSvGSOLwL1QuROb-6Q8w3--hz5R4shhsE	m.room.encrypted	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	\N	\N	t	f	13	1783626346650	1783626346740	@ali:matrix.shikpooshaan.ir	f	master	40	\N	\N
17	$7683AfvdvVGbujZUglQ3dOVMhLfC5n8sd4USeya9_9A	m.room.encrypted	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	\N	\N	t	f	17	1783626358593	1783626358661	@ali:matrix.shikpooshaan.ir	f	master	44	\N	\N
1	$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg	m.room.create	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	\N	\N	t	f	1	1783626825017	1783626825131	@alex-taylor:matrix.shikpooshaan.ir	f	master	45		\N
11	$uMZ-ZidlxCHhXanXLN1-ytrhTVb9h1j1K2u-ZEvFmLI	m.room.encrypted	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	\N	\N	t	f	11	1783626344136	1783626344220	@ali:matrix.shikpooshaan.ir	f	master	38	\N	\N
12	$5P00VdpT2xziYLl8SJGwC9nL-vpZPERv25JcU1tQEy4	m.room.encrypted	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	\N	\N	t	f	12	1783626345420	1783626345512	@ali:matrix.shikpooshaan.ir	f	master	39	\N	\N
14	$nX0BIvxzfiMjoGPKmnp3zaDJ_Lwe4buCfaVfv4wKHAA	m.room.encrypted	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	\N	\N	t	f	14	1783626354283	1783626354326	@ali:matrix.shikpooshaan.ir	f	master	41	\N	\N
15	$MKIG_xPNWt7pAeRQie1-ff8u79mcVuNrOYFINP7GYb8	m.room.encrypted	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	\N	\N	t	f	15	1783626355388	1783626355447	@ali:matrix.shikpooshaan.ir	f	master	42	\N	\N
2	$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY	m.room.member	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	\N	\N	t	f	2	1783626825275	1783626825373	@alex-taylor:matrix.shikpooshaan.ir	f	master	46	@alex-taylor:matrix.shikpooshaan.ir	\N
9	$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA	m.room.member	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	\N	\N	t	f	9	1783626835369	1783626835431	@ali:matrix.shikpooshaan.ir	f	master	53	@ali:matrix.shikpooshaan.ir	\N
16	$C3PYkudwbc1C1vhjMWGEuUhQS2SwdWK2dFzNgexrfug	m.room.encrypted	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	\N	\N	t	f	16	1783626356069	1783626356133	@ali:matrix.shikpooshaan.ir	f	master	43	\N	\N
8	$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA	m.room.member	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	\N	\N	t	f	8	1783626825973	1783626826120	@alex-taylor:matrix.shikpooshaan.ir	f	master	52	@ali:matrix.shikpooshaan.ir	\N
1	$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg	m.room.create	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	\N	\N	t	f	1	1783627135945	1783627136061	@alipaz:matrix.shikpooshaan.ir	f	master	54		\N
2	$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	m.room.member	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	\N	\N	t	f	2	1783627136167	1783627136239	@alipaz:matrix.shikpooshaan.ir	f	master	55	@alipaz:matrix.shikpooshaan.ir	\N
3	$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	m.room.power_levels	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	\N	\N	t	f	3	1783627136303	1783627136555	@alipaz:matrix.shikpooshaan.ir	f	master	56		\N
4	$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE	m.room.join_rules	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	\N	\N	t	f	4	1783627136340	1783627136555	@alipaz:matrix.shikpooshaan.ir	f	master	57		\N
5	$Z2e6JO81o3A3wHKKBJSTB-q68xOeUakOBJi-6H0er2I	m.room.guest_access	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	\N	\N	t	f	5	1783627136342	1783627136555	@alipaz:matrix.shikpooshaan.ir	f	master	58		\N
6	$oUHPDjqakCWglPegHTY6TC8e_Qaqub-Yoh_XfUKTjjc	m.room.encryption	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	\N	\N	t	f	6	1783627136344	1783627136555	@alipaz:matrix.shikpooshaan.ir	f	master	59		\N
7	$ZaaKYiCE_n9AzqSGJntdPRcRM7BRhym69EHSrFwgdac	m.room.history_visibility	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	\N	\N	t	f	7	1783627136346	1783627136555	@alipaz:matrix.shikpooshaan.ir	f	master	60		\N
8	$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA	m.room.member	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	\N	\N	t	f	8	1783627136677	1783627136825	@alipaz:matrix.shikpooshaan.ir	f	master	61	@alex-taylor:matrix.shikpooshaan.ir	\N
9	$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s	m.room.member	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	\N	\N	t	f	9	1783627138997	1783627139087	@alex-taylor:matrix.shikpooshaan.ir	f	master	62	@alex-taylor:matrix.shikpooshaan.ir	\N
10	$ExyXltZ8XVgCS4zv7cy-lT_wdLHC4I6gFOEe9WIXLxo	m.room.encrypted	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	\N	\N	t	f	10	1783627143288	1783627143362	@alipaz:matrix.shikpooshaan.ir	f	master	63	\N	\N
11	$afVsFJEIQ2l3SduwcVGDn3fVRxWpwp6Z294e_VvMTFc	m.room.encrypted	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	\N	\N	t	f	11	1783627148070	1783627148160	@alipaz:matrix.shikpooshaan.ir	f	master	64	\N	\N
12	$2F_r1QYHaObawQDNr91dUNyPG7vMIy94v6I6KmYFAYk	m.room.encrypted	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	\N	\N	t	f	12	1783627149840	1783627149954	@alipaz:matrix.shikpooshaan.ir	f	master	65	\N	\N
13	$_H2DZoM2QWFOqEQG70J87qAZM3H467C9Jlh4_5gWzzI	m.room.encrypted	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	\N	\N	t	f	13	1783627151124	1783627151207	@alipaz:matrix.shikpooshaan.ir	f	master	66	\N	\N
14	$nOti7xJQKHyROEyoGtsBKtap-hocvso_bgZ53R7EE8U	m.room.encrypted	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	\N	\N	t	f	14	1783627158994	1783627159065	@alipaz:matrix.shikpooshaan.ir	f	master	67	\N	\N
10	$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg	m.room.member	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	\N	\N	t	f	10	1783669885808	1783669886892	@alex-taylor:matrix.shikpooshaan.ir	f	master	68	@alex-taylor:matrix.shikpooshaan.ir	\N
15	$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A	m.room.member	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	\N	\N	t	f	15	1783669888505	1783669888664	@alex-taylor:matrix.shikpooshaan.ir	f	master	69	@alex-taylor:matrix.shikpooshaan.ir	\N
11	$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo	m.room.member	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	\N	\N	t	f	11	1783669997692	1783669997847	@alex-taylor:matrix.shikpooshaan.ir	f	master	70	@alex-taylor:matrix.shikpooshaan.ir	\N
16	$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k	m.room.member	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	\N	\N	t	f	16	1783669998649	1783669998735	@alex-taylor:matrix.shikpooshaan.ir	f	master	71	@alex-taylor:matrix.shikpooshaan.ir	\N
1	$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4	m.room.create	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	\N	\N	t	f	1	1783670156780	1783670156930	@alex-taylor:matrix.shikpooshaan.ir	f	master	72		\N
2	$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	m.room.member	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	\N	\N	t	f	2	1783670157302	1783670157399	@alex-taylor:matrix.shikpooshaan.ir	f	master	73	@alex-taylor:matrix.shikpooshaan.ir	\N
3	$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY	m.room.power_levels	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	\N	\N	t	f	3	1783670157574	1783670158379	@alex-taylor:matrix.shikpooshaan.ir	f	master	74		\N
4	$ekFlSyfMDYeG34nr1qqB9Bi-AbjdiJ_J9bLNNsHuLKs	m.room.join_rules	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	\N	\N	t	f	4	1783670158040	1783670158379	@alex-taylor:matrix.shikpooshaan.ir	f	master	75		\N
5	$zc8tOpOdwrt2LhO6ZIPa8Tv1PyclAu-E3cFNvQTB_rw	m.room.guest_access	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	\N	\N	t	f	5	1783670158042	1783670158379	@alex-taylor:matrix.shikpooshaan.ir	f	master	76		\N
6	$KTjmV6JHWFiwg8JXvrYWGjeMxJtAvzZoRDulWpsNaSw	m.room.encryption	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	\N	\N	t	f	6	1783670158051	1783670158379	@alex-taylor:matrix.shikpooshaan.ir	f	master	77		\N
7	$Dc3jotNRZdjzDW_y7eg_fRWeyXs382gqm43HSX5lbOI	m.room.history_visibility	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	\N	\N	t	f	7	1783670158057	1783670158379	@alex-taylor:matrix.shikpooshaan.ir	f	master	78		\N
8	$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE	m.room.member	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	\N	\N	t	f	8	1783670158534	1783670158719	@alex-taylor:matrix.shikpooshaan.ir	f	master	79	@alextaylor:matrix.shikpooshaan.ir	\N
1	$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U	m.room.create	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	\N	\N	t	f	1	1783670197776	1783670197855	@alex-taylor:matrix.shikpooshaan.ir	f	master	80		\N
2	$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	m.room.member	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	\N	\N	t	f	2	1783670197966	1783670198039	@alex-taylor:matrix.shikpooshaan.ir	f	master	81	@alex-taylor:matrix.shikpooshaan.ir	\N
3	$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo	m.room.power_levels	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	\N	\N	t	f	3	1783670198153	1783670198455	@alex-taylor:matrix.shikpooshaan.ir	f	master	82		\N
4	$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw	m.room.join_rules	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	\N	\N	t	f	4	1783670198216	1783670198455	@alex-taylor:matrix.shikpooshaan.ir	f	master	83		\N
5	$xRkldK4rXGoVy6SNEazvj_642j0z4vnhDKSsno94oMs	m.room.guest_access	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	\N	\N	t	f	5	1783670198219	1783670198455	@alex-taylor:matrix.shikpooshaan.ir	f	master	84		\N
6	$RDmQ4EMxY-FgFox84X5UWejaA1ImHNYssM_nyAlLSbs	m.room.encryption	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	\N	\N	t	f	6	1783670198222	1783670198455	@alex-taylor:matrix.shikpooshaan.ir	f	master	85		\N
7	$YP8LBjVbUpZKdDbx8B7q46a8-CJwDp3EK1qyDJCSoio	m.room.history_visibility	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	\N	\N	t	f	7	1783670198224	1783670198455	@alex-taylor:matrix.shikpooshaan.ir	f	master	86		\N
9	$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk	m.room.member	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	\N	\N	t	f	9	1783670201883	1783670201968	@alextaylor98:matrix.shikpooshaan.ir	f	master	88	@alextaylor98:matrix.shikpooshaan.ir	\N
11	$4X_PjJl7QiE3U7c8UuRUw5-rEt6S9u2f1fEzR5tiWso	m.room.member	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	\N	\N	t	f	11	1783671328719	1783671328812	@alextaylor98:matrix.shikpooshaan.ir	f	master	95	@alextaylor98:matrix.shikpooshaan.ir	\N
8	$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg	m.room.member	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	\N	\N	t	f	8	1783670198622	1783670198721	@alex-taylor:matrix.shikpooshaan.ir	f	master	87	@alextaylor98:matrix.shikpooshaan.ir	\N
10	$Np7L2UpX2tMrmcWkrhqTkIPPQf2JHPiRI9eGpZCUi9k	m.room.encrypted	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	\N	\N	t	f	10	1783670208904	1783670209080	@alextaylor98:matrix.shikpooshaan.ir	f	master	89	\N	\N
12	$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY	m.room.member	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	\N	\N	t	f	12	1783670495857	1783670495962	@alextaylor98:matrix.shikpooshaan.ir	f	master	92	@alextaylor98:matrix.shikpooshaan.ir	\N
9	$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk	m.room.member	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	\N	\N	t	f	9	1783672409722	1783672409801	@alextaylor98:matrix.shikpooshaan.ir	f	master	104	@alextaylor98:matrix.shikpooshaan.ir	\N
11	$Ax7Nf2f62jFM6Iukww-bvFvDhxGkhcDQHJOA8GGe3pg	m.room.encrypted	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	\N	\N	t	f	11	1783670231459	1783670231519	@alextaylor98:matrix.shikpooshaan.ir	f	master	90	\N	\N
10	$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is	m.room.member	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	\N	\N	t	f	10	1783670495456	1783670495579	@alextaylor98:matrix.shikpooshaan.ir	f	master	91	@alextaylor98:matrix.shikpooshaan.ir	\N
14	$zM6vJpoUtsXTUex3viHLPy-oiEKdsGSx6OqizILlFdI	m.room.encrypted	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	\N	\N	t	f	14	1783670515590	1783670515667	@alextaylor98:matrix.shikpooshaan.ir	f	master	94	\N	\N
13	$Er7aPlzKizvAozxf620HpDa-P3Uqu59Re3mkzFi9s8w	m.room.encrypted	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	\N	\N	t	f	13	1783672466067	1783672466135	@brian:matrix.shikpooshaan.ir	f	master	108	\N	\N
14	$1MLqlvYR1hYyOHAgVVxyOygzdyCxZYc0iLQZrXia5Ls	m.room.encrypted	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	\N	\N	t	f	14	1783672534283	1783672534350	@alextaylor98:matrix.shikpooshaan.ir	f	master	109	\N	\N
13	$4FmnE3et4KlX8gqLLuDjSYLUFKZG8CgNq8_OPh3TWYY	m.room.redaction	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	\N	\N	t	f	13	1783670505780	1783670505874	@alextaylor98:matrix.shikpooshaan.ir	f	master	93	\N	\N
1	$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs	m.room.create	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	\N	\N	t	f	1	1783672403407	1783672403521	@brian:matrix.shikpooshaan.ir	f	master	96		\N
2	$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	m.room.member	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	\N	\N	t	f	2	1783672403731	1783672403805	@brian:matrix.shikpooshaan.ir	f	master	97	@brian:matrix.shikpooshaan.ir	\N
3	$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk	m.room.power_levels	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	\N	\N	t	f	3	1783672403907	1783672404277	@brian:matrix.shikpooshaan.ir	f	master	98		\N
4	$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ	m.room.join_rules	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	\N	\N	t	f	4	1783672403943	1783672404277	@brian:matrix.shikpooshaan.ir	f	master	99		\N
5	$lzdi23BC1bOIDnNJnuoZzfFYBb3iv4PDZ1pw9Tg4z1M	m.room.guest_access	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	\N	\N	t	f	5	1783672403945	1783672404277	@brian:matrix.shikpooshaan.ir	f	master	100		\N
6	$d-DLbKD_o_R1rzHrZD8hyXWTZsKArLYnNTv9_1HRatE	m.room.encryption	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	\N	\N	t	f	6	1783672403947	1783672404277	@brian:matrix.shikpooshaan.ir	f	master	101		\N
7	$6UQ-qIZULcBYRTpiEHtIjLH-lHfTx1ipANQeBo3ldw0	m.room.history_visibility	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	\N	\N	t	f	7	1783672403949	1783672404277	@brian:matrix.shikpooshaan.ir	f	master	102		\N
8	$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg	m.room.member	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	\N	\N	t	f	8	1783672404417	1783672404554	@brian:matrix.shikpooshaan.ir	f	master	103	@alextaylor98:matrix.shikpooshaan.ir	\N
10	$oZTAqRbttOiPuTLHUN_H2ptq2VqGzcx4o8urdtkZR9A	m.room.encrypted	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	\N	\N	t	f	10	1783672414307	1783672414389	@alextaylor98:matrix.shikpooshaan.ir	f	master	105	\N	\N
11	$x-laZQjLN_ybbNbLzACqCd1-j4uqjJ9UBDzWYpYGv54	m.room.encrypted	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	\N	\N	t	f	11	1783672423821	1783672423982	@alextaylor98:matrix.shikpooshaan.ir	f	master	106	\N	\N
12	$6kTTzdJWNwDbZB4BZt4uyMdlAegiGE1HtQPgLUpZBbs	m.room.encrypted	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	\N	\N	t	f	12	1783672424590	1783672424697	@brian:matrix.shikpooshaan.ir	f	master	107	\N	\N
\.


--
-- Data for Name: ex_outlier_stream; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.ex_outlier_stream (event_stream_ordering, event_id, state_group, instance_name) FROM stdin;
\.


--
-- Data for Name: federation_inbound_events_staging; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.federation_inbound_events_staging (origin, room_id, event_id, received_ts, event_json, internal_metadata) FROM stdin;
\.


--
-- Data for Name: federation_stream_position; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.federation_stream_position (type, stream_id, instance_name) FROM stdin;
federation	-1	master
events	109	master
\.


--
-- Data for Name: ignored_users; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.ignored_users (ignorer_user_id, ignored_user_id) FROM stdin;
\.


--
-- Data for Name: instance_map; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.instance_map (instance_id, instance_name) FROM stdin;
\.


--
-- Data for Name: local_current_membership; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.local_current_membership (room_id, user_id, event_id, membership, event_stream_ordering) FROM stdin;
!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI	join	10
!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	@brianrockwell:matrix.shikpooshaan.ir	$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU	leave	18
!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	@brianrockwell:matrix.shikpooshaan.ir	$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg	join	27
!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	@brianrockwell:matrix.shikpooshaan.ir	$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	join	29
!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg	join	36
!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA	join	53
!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	@alipaz:matrix.shikpooshaan.ir	$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	join	55
!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo	join	70
!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k	join	71
!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	join	73
!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	@alextaylor:matrix.shikpooshaan.ir	$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE	invite	79
!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	join	81
!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY	join	92
!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	$4X_PjJl7QiE3U7c8UuRUw5-rEt6S9u2f1fEzR5tiWso	leave	95
!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	@brian:matrix.shikpooshaan.ir	$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	join	97
!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk	join	104
\.


--
-- Data for Name: local_media_repository; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.local_media_repository (media_id, media_type, media_length, created_ts, upload_name, user_id, quarantined_by, url_cache, last_access_ts, safe_from_quarantine, authenticated, sha256) FROM stdin;
HXfInbkyHeNFCaFCJYDwTfyU	application/octet-stream	52875	1783670231190	\N	@alextaylor98:matrix.shikpooshaan.ir	\N	\N	1783670270490	f	t	b355f41787090f4320e8a32c504aa39cab7e994ec9c01bee41b792f05b45a385
WYjvRrHdQwXttYBqKVGTNjYo	image/jpeg	186247	1783669990252	\N	@alex-taylor:matrix.shikpooshaan.ir	\N	\N	1783671830491	f	t	2e1328771c0bc6fbba5ec630c74feb87c2344429c8de464bd96fbf3958cb9afd
WAVvzxiChlsNFuJUJcHCpcGa	application/octet-stream	40452	1783672423738	\N	@alextaylor98:matrix.shikpooshaan.ir	\N	\N	1783672430492	f	t	a53351c20ae6537f6c14a60dd2b501c62a2bca1c19a9e0074dd457977e65fb1a
ZvnUeFyFDpHyzXqzuIhncSVg	image/jpeg	540872	1783670494576	\N	@alextaylor98:matrix.shikpooshaan.ir	\N	\N	1783672430492	f	t	abf18bea65b6a9fb64fd47fb9f8ceb7a089f09b6a55ed6a3d95341c30ab1f0f5
nqjOHlTbzhIvqZujaRkwFKkn	application/octet-stream	51650	1783672464718	\N	@brian:matrix.shikpooshaan.ir	\N	\N	1783672490515	f	t	c9eb6f2df1334912e651ad5af042ef6c2fbab9219bbcf4e08320d62849df6661
htWRrhtdkmFZZlvagJfVXZSO	application/octet-stream	283461	1783672534029	\N	@alextaylor98:matrix.shikpooshaan.ir	\N	\N	1783672550493	f	t	005f499b31ded6e24015485a8c8e7d80295b62bd19334f9e6cd6f47ac3206b19
\.


--
-- Data for Name: local_media_repository_thumbnails; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.local_media_repository_thumbnails (media_id, thumbnail_width, thumbnail_height, thumbnail_type, thumbnail_method, thumbnail_length) FROM stdin;
WYjvRrHdQwXttYBqKVGTNjYo	32	32	image/jpeg	crop	980
WYjvRrHdQwXttYBqKVGTNjYo	96	96	image/jpeg	crop	3962
WYjvRrHdQwXttYBqKVGTNjYo	135	240	image/jpeg	scale	11228
WYjvRrHdQwXttYBqKVGTNjYo	270	480	image/jpeg	scale	38391
WYjvRrHdQwXttYBqKVGTNjYo	337	600	image/jpeg	scale	56945
ZvnUeFyFDpHyzXqzuIhncSVg	32	32	image/jpeg	crop	1009
ZvnUeFyFDpHyzXqzuIhncSVg	96	96	image/jpeg	crop	3083
ZvnUeFyFDpHyzXqzuIhncSVg	135	240	image/jpeg	scale	8610
ZvnUeFyFDpHyzXqzuIhncSVg	270	480	image/jpeg	scale	28780
ZvnUeFyFDpHyzXqzuIhncSVg	337	600	image/jpeg	scale	43355
\.


--
-- Data for Name: local_media_repository_url_cache; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.local_media_repository_url_cache (url, response_code, etag, expires_ts, og, media_id, download_ts) FROM stdin;
\.


--
-- Data for Name: login_tokens; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.login_tokens (token, user_id, expiry_ts, used_ts, auth_provider_id, auth_provider_session_id) FROM stdin;
\.


--
-- Data for Name: monthly_active_users; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.monthly_active_users (user_id, "timestamp") FROM stdin;
\.


--
-- Data for Name: msc4242_state_dag_edges; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.msc4242_state_dag_edges (room_id, event_id, prev_state_event_id) FROM stdin;
\.


--
-- Data for Name: msc4242_state_dag_forward_extremities; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.msc4242_state_dag_forward_extremities (room_id, event_id) FROM stdin;
\.


--
-- Data for Name: open_id_tokens; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.open_id_tokens (token, ts_valid_until_ms, user_id) FROM stdin;
\.


--
-- Data for Name: partial_state_events; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.partial_state_events (room_id, event_id) FROM stdin;
\.


--
-- Data for Name: partial_state_rooms; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.partial_state_rooms (room_id, device_lists_stream_id, join_event_id, joined_via) FROM stdin;
\.


--
-- Data for Name: partial_state_rooms_servers; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.partial_state_rooms_servers (room_id, server_name) FROM stdin;
\.


--
-- Data for Name: per_user_experimental_features; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.per_user_experimental_features (user_id, feature, enabled) FROM stdin;
\.


--
-- Data for Name: presence_stream; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.presence_stream (stream_id, user_id, state, last_active_ts, last_federation_update_ts, last_user_sync_ts, status_msg, currently_active, instance_name) FROM stdin;
222	@alipaz:matrix.shikpooshaan.ir	offline	1783627628759	1783628295466	1783628260847	\N	t	master
227	@monir:matrix.shikpooshaan.ir	offline	1783627700797	1783628345467	1783628343598	\N	t	master
67	@brianrockwell:matrix.shikpooshaan.ir	offline	1783626424146	1783626422370	0	\N	f	master
335	@ali:matrix.shikpooshaan.ir	offline	1783671617473	1783671650467	1783671617502	\N	t	master
336	@ali:matrix.shikpooshaan.ir	offline	1783671617473	1783671650467	1783671617502	\N	t	master
294	@alex-taylor:matrix.shikpooshaan.ir	offline	1783670526720	1783670459211	0	\N	f	master
369	@brian:matrix.shikpooshaan.ir	offline	1783672548384	1783672548384	0	\N	f	master
380	@alextaylor98:matrix.shikpooshaan.ir	online	1783673001807	1783673001807	1783673001807	\N	t	master
\.


--
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.profiles (user_id, displayname, avatar_url, full_user_id, fields) FROM stdin;
alextaylor	alextaylor	\N	@alextaylor:matrix.shikpooshaan.ir	\N
brianrockwell	brianrockwell	\N	@brianrockwell:matrix.shikpooshaan.ir	\N
alipaz	alipaz	\N	@alipaz:matrix.shikpooshaan.ir	\N
monir	monir	\N	@monir:matrix.shikpooshaan.ir	\N
aa0922ny	aa0922ny	\N	@aa0922ny:matrix.shikpooshaan.ir	\N
ali	ali	\N	@ali:matrix.shikpooshaan.ir	\N
alex-taylor	Alex98	mxc://matrix.shikpooshaan.ir/WYjvRrHdQwXttYBqKVGTNjYo	@alex-taylor:matrix.shikpooshaan.ir	\N
alextaylor98	alextaylor98	mxc://matrix.shikpooshaan.ir/ZvnUeFyFDpHyzXqzuIhncSVg	@alextaylor98:matrix.shikpooshaan.ir	\N
brian	brian	\N	@brian:matrix.shikpooshaan.ir	\N
\.


--
-- Data for Name: push_rules; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.push_rules (id, user_name, rule_id, priority_class, priority, conditions, actions) FROM stdin;
\.


--
-- Data for Name: push_rules_enable; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.push_rules_enable (id, user_name, rule_id, enabled) FROM stdin;
\.


--
-- Data for Name: push_rules_stream; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.push_rules_stream (stream_id, event_stream_ordering, user_id, rule_id, op, priority_class, priority, conditions, actions, instance_name) FROM stdin;
\.


--
-- Data for Name: pusher_throttle; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.pusher_throttle (pusher, room_id, last_sent_ts, throttle_ms) FROM stdin;
\.


--
-- Data for Name: pushers; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.pushers (id, user_name, access_token, profile_tag, kind, app_id, app_display_name, device_display_name, pushkey, ts, lang, data, last_stream_ordering, last_success, failing_since, enabled, device_id, instance_name) FROM stdin;
23	@alex-taylor:matrix.shikpooshaan.ir	\N	mobile_	http	im.vector.app.android	Element X	MyDevice	cXRzOJQKSF-uUKfMghugq0	1783671102843	en	{"url":"https://matrix.org/_matrix/push/v1/notify","format":"event_id_only","default_payload":{"cs":"013f35fb-bc5d-4020-a157-a2cb1bd12490"}}	94	1783670516880	\N	t	CHFTPUHNYF	master
16	@alextaylor98:matrix.shikpooshaan.ir	\N	OL1jYooNkt7g7x80	http	io.element.elementx.ios.prod	Element X (iOS)	iPhone	nJRFxCRgYcgc6uYh6gTO8RFsdKesp/vz94qwEmrwdcg=	1783629278721	en-US	{"url":"https://matrix.org/_matrix/push/v1/notify","format":"event_id_only","default_payload":{"aps":{"alert":{"loc-args":[],"loc-key":"Notification"},"mutable-content":1},"pusher_notification_client_identifier":"552984e593c5865ea7803a8dda657df11ad82938bf93735eb0989664d5c486d0"}}	108	1783672466553	\N	t	NFLNJMUACW	master
24	@brian:matrix.shikpooshaan.ir	\N	mobile_	http	im.vector.app.android	Element X	MyDevice	cj6NJdBsRF6vlFQf2UD8N5	1783672225268	en	{"url":"https://matrix.org/_matrix/push/v1/notify","format":"event_id_only","default_payload":{"cs":"c87317ba-0141-4c94-98a6-730555cc319f"}}	109	1783672534650	\N	t	YOCYFXUGYQ	master
\.


--
-- Data for Name: quarantined_media_changes; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.quarantined_media_changes (stream_id, instance_name, origin, media_id, quarantined) FROM stdin;
\.


--
-- Data for Name: ratelimit_override; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.ratelimit_override (user_id, messages_per_second, burst_count) FROM stdin;
\.


--
-- Data for Name: receipts_graph; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.receipts_graph (room_id, receipt_type, user_id, event_ids, data, thread_id) FROM stdin;
!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.read	@brianrockwell:matrix.shikpooshaan.ir	["$VDxFUMtILxytmO-s2kFHdkmCGyfSuMGfvtuZK6zZf3Q"]	{"ts":1783625470222}	\N
!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.read	@ali:matrix.shikpooshaan.ir	["$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU"]	{"ts":1783626203632}	main
!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.read	@ali:matrix.shikpooshaan.ir	["$38B-Weejbpnil6mQvy5fn8Vc0qGoDasfdZ5t3hdt-u4"]	{"ts":1783626339454}	main
!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.read	@brianrockwell:matrix.shikpooshaan.ir	["$7683AfvdvVGbujZUglQ3dOVMhLfC5n8sd4USeya9_9A"]	{"ts":1783626422440}	\N
!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.read	@alex-taylor:matrix.shikpooshaan.ir	["$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA"]	{"ts":1783626836028}	\N
!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.read	@alipaz:matrix.shikpooshaan.ir	["$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s"]	{"ts":1783627143767}	main
!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.read	@alex-taylor:matrix.shikpooshaan.ir	["$nOti7xJQKHyROEyoGtsBKtap-hocvso_bgZ53R7EE8U"]	{"ts":1783635483471}	\N
!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.read	@alex-taylor:matrix.shikpooshaan.ir	["$zM6vJpoUtsXTUex3viHLPy-oiEKdsGSx6OqizILlFdI"]	{"ts":1783670516100}	\N
!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.read	@ali:matrix.shikpooshaan.ir	["$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo"]	{"ts":1783670963214}	main
!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.read	@alextaylor98:matrix.shikpooshaan.ir	["$Er7aPlzKizvAozxf620HpDa-P3Uqu59Re3mkzFi9s8w"]	{"ts":1783672466531}	\N
!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.read	@brian:matrix.shikpooshaan.ir	["$1MLqlvYR1hYyOHAgVVxyOygzdyCxZYc0iLQZrXia5Ls"]	{"ts":1783672548476}	\N
\.


--
-- Data for Name: receipts_linearized; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.receipts_linearized (stream_id, room_id, receipt_type, user_id, event_id, data, instance_name, event_stream_ordering, thread_id) FROM stdin;
6	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.read	@brianrockwell:matrix.shikpooshaan.ir	$VDxFUMtILxytmO-s2kFHdkmCGyfSuMGfvtuZK6zZf3Q	{"ts":1783625470222}	master	14	\N
7	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.read	@ali:matrix.shikpooshaan.ir	$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU	{"ts":1783626203632}	master	18	main
10	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.read	@ali:matrix.shikpooshaan.ir	$38B-Weejbpnil6mQvy5fn8Vc0qGoDasfdZ5t3hdt-u4	{"ts":1783626339454}	master	37	main
12	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.read	@brianrockwell:matrix.shikpooshaan.ir	$7683AfvdvVGbujZUglQ3dOVMhLfC5n8sd4USeya9_9A	{"ts":1783626422440}	master	44	\N
13	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.read	@alex-taylor:matrix.shikpooshaan.ir	$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA	{"ts":1783626836028}	master	53	\N
15	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.read	@alipaz:matrix.shikpooshaan.ir	$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s	{"ts":1783627143767}	master	62	main
18	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.read	@alex-taylor:matrix.shikpooshaan.ir	$nOti7xJQKHyROEyoGtsBKtap-hocvso_bgZ53R7EE8U	{"ts":1783635483471}	master	67	\N
23	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.read	@alex-taylor:matrix.shikpooshaan.ir	$zM6vJpoUtsXTUex3viHLPy-oiEKdsGSx6OqizILlFdI	{"ts":1783670516100}	master	94	\N
24	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.read	@ali:matrix.shikpooshaan.ir	$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo	{"ts":1783670963214}	master	70	main
28	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.read	@alextaylor98:matrix.shikpooshaan.ir	$Er7aPlzKizvAozxf620HpDa-P3Uqu59Re3mkzFi9s8w	{"ts":1783672466531}	master	108	\N
29	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.read	@brian:matrix.shikpooshaan.ir	$1MLqlvYR1hYyOHAgVVxyOygzdyCxZYc0iLQZrXia5Ls	{"ts":1783672548476}	master	109	\N
\.


--
-- Data for Name: received_transactions; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.received_transactions (transaction_id, origin, ts, response_code, response_json, has_been_referenced) FROM stdin;
\.


--
-- Data for Name: redactions; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.redactions (event_id, redacts, have_censored, received_ts, recheck) FROM stdin;
$4FmnE3et4KlX8gqLLuDjSYLUFKZG8CgNq8_OPh3TWYY	$Ax7Nf2f62jFM6Iukww-bvFvDhxGkhcDQHJOA8GGe3pg	f	1783670505896	f
\.


--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.refresh_tokens (id, user_id, device_id, token, next_token_id, expiry_ts, ultimate_session_expiry_ts) FROM stdin;
\.


--
-- Data for Name: registration_tokens; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.registration_tokens (token, uses_allowed, pending, completed, expiry_time) FROM stdin;
\.


--
-- Data for Name: rejections; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.rejections (event_id, reason, last_check) FROM stdin;
\.


--
-- Data for Name: remote_media_cache; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.remote_media_cache (media_origin, media_id, media_type, created_ts, upload_name, media_length, filesystem_id, last_access_ts, quarantined_by, authenticated, sha256) FROM stdin;
\.


--
-- Data for Name: remote_media_cache_thumbnails; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.remote_media_cache_thumbnails (media_origin, media_id, thumbnail_width, thumbnail_height, thumbnail_method, thumbnail_type, thumbnail_length, filesystem_id) FROM stdin;
\.


--
-- Data for Name: room_account_data; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.room_account_data (user_id, room_id, account_data_type, stream_id, content, instance_name) FROM stdin;
@brianrockwell:matrix.shikpooshaan.ir	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.fully_read	26	{"event_id":"$OYsK4JS05N5L1dz1HFkKo5nIk3YnZZbM5RB4ZkCos6Q"}	\N
@ali:matrix.shikpooshaan.ir	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.fully_read	29	{"event_id":"$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU"}	\N
@brianrockwell:matrix.shikpooshaan.ir	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.fully_read	30	{"event_id":"$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg"}	\N
@ali:matrix.shikpooshaan.ir	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.fully_read	42	{"event_id":"$7683AfvdvVGbujZUglQ3dOVMhLfC5n8sd4USeya9_9A"}	\N
@brianrockwell:matrix.shikpooshaan.ir	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.fully_read	43	{"event_id":"$7683AfvdvVGbujZUglQ3dOVMhLfC5n8sd4USeya9_9A"}	\N
@alipaz:matrix.shikpooshaan.ir	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.fully_read	63	{"event_id":"$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s"}	\N
@alex-taylor:matrix.shikpooshaan.ir	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.fully_read	64	{"event_id":"$nOti7xJQKHyROEyoGtsBKtap-hocvso_bgZ53R7EE8U"}	\N
@alex-taylor:matrix.shikpooshaan.ir	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.fully_read	73	{"event_id":"$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg"}	\N
@alex-taylor:matrix.shikpooshaan.ir	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.fully_read	75	{"event_id":"$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE"}	\N
@alex-taylor:matrix.shikpooshaan.ir	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.fully_read	81	{"event_id":"$zM6vJpoUtsXTUex3viHLPy-oiEKdsGSx6OqizILlFdI"}	\N
@alextaylor98:matrix.shikpooshaan.ir	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.fully_read	82	{"event_id":"$zM6vJpoUtsXTUex3viHLPy-oiEKdsGSx6OqizILlFdI"}	\N
@ali:matrix.shikpooshaan.ir	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.fully_read	83	{"event_id":"$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo"}	\N
@alextaylor98:matrix.shikpooshaan.ir	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.fully_read	84	{"event_id":"$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is"}	\N
@brian:matrix.shikpooshaan.ir	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.fully_read	98	{"event_id":"$6kTTzdJWNwDbZB4BZt4uyMdlAegiGE1HtQPgLUpZBbs"}	\N
@alextaylor98:matrix.shikpooshaan.ir	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.fully_read	99	{"event_id":"$1MLqlvYR1hYyOHAgVVxyOygzdyCxZYc0iLQZrXia5Ls"}	\N
\.


--
-- Data for Name: room_alias_servers; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.room_alias_servers (room_alias, server) FROM stdin;
\.


--
-- Data for Name: room_aliases; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.room_aliases (room_alias, room_id, creator) FROM stdin;
\.


--
-- Data for Name: room_ban_redactions; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.room_ban_redactions (room_id, user_id, redacting_event_id, redact_end_ordering) FROM stdin;
\.


--
-- Data for Name: room_depth; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.room_depth (room_id, min_depth) FROM stdin;
!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	1
!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	1
!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	1
!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	1
!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	1
!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	1
!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	1
!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	1
\.


--
-- Data for Name: room_forgetter_stream_pos; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.room_forgetter_stream_pos (lock, stream_id) FROM stdin;
X	109
\.


--
-- Data for Name: room_memberships; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.room_memberships (event_id, user_id, sender, room_id, membership, forgotten, display_name, avatar_url, event_stream_ordering, participant) FROM stdin;
$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag	@brianrockwell:matrix.shikpooshaan.ir	@brianrockwell:matrix.shikpooshaan.ir	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	join	0	brianrockwell	\N	3	f
$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA	@ali:matrix.shikpooshaan.ir	@brianrockwell:matrix.shikpooshaan.ir	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	invite	0	ali	\N	9	f
$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI	@ali:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	join	0	ali	\N	10	t
$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU	@brianrockwell:matrix.shikpooshaan.ir	@brianrockwell:matrix.shikpooshaan.ir	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	leave	0	\N	\N	18	f
$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY	@alextaylor98:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	join	0	alextaylor98	\N	20	f
$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU	@brianrockwell:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	invite	0	brianrockwell	\N	26	f
$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg	@brianrockwell:matrix.shikpooshaan.ir	@brianrockwell:matrix.shikpooshaan.ir	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	join	0	brianrockwell	\N	27	f
$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I	@ali:matrix.shikpooshaan.ir	@brianrockwell:matrix.shikpooshaan.ir	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	invite	0	ali	\N	35	f
$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	@brianrockwell:matrix.shikpooshaan.ir	@brianrockwell:matrix.shikpooshaan.ir	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	join	0	brianrockwell	\N	29	t
$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg	@ali:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	join	0	ali	\N	36	t
$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY	@alex-taylor:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	join	0	alex-taylor	\N	46	f
$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA	@ali:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	invite	0	ali	\N	52	f
$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA	@ali:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	join	0	ali	\N	53	f
$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA	@alex-taylor:matrix.shikpooshaan.ir	@alipaz:matrix.shikpooshaan.ir	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	invite	0	alex-taylor	\N	61	f
$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s	@alex-taylor:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	join	0	alex-taylor	\N	62	f
$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	@alipaz:matrix.shikpooshaan.ir	@alipaz:matrix.shikpooshaan.ir	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	join	0	alipaz	\N	55	t
$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg	@alex-taylor:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	join	0	Alex98	\N	68	f
$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A	@alex-taylor:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	join	0	Alex98	\N	69	f
$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo	@alex-taylor:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	join	0	Alex98	mxc://matrix.shikpooshaan.ir/WYjvRrHdQwXttYBqKVGTNjYo	70	f
$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k	@alex-taylor:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	join	0	Alex98	mxc://matrix.shikpooshaan.ir/WYjvRrHdQwXttYBqKVGTNjYo	71	f
$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	@alex-taylor:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	join	0	Alex98	mxc://matrix.shikpooshaan.ir/WYjvRrHdQwXttYBqKVGTNjYo	73	f
$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE	@alextaylor:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	invite	0	alextaylor	\N	79	f
$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	@alex-taylor:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	join	0	Alex98	mxc://matrix.shikpooshaan.ir/WYjvRrHdQwXttYBqKVGTNjYo	81	f
$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg	@alextaylor98:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	invite	0	alextaylor98	\N	87	f
$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk	@alextaylor98:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	join	0	alextaylor98	\N	88	t
$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is	@alextaylor98:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	join	0	alextaylor98	mxc://matrix.shikpooshaan.ir/ZvnUeFyFDpHyzXqzuIhncSVg	91	f
$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY	@alextaylor98:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	join	0	alextaylor98	mxc://matrix.shikpooshaan.ir/ZvnUeFyFDpHyzXqzuIhncSVg	92	t
$4X_PjJl7QiE3U7c8UuRUw5-rEt6S9u2f1fEzR5tiWso	@alextaylor98:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	leave	0	\N	\N	95	f
$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg	@alextaylor98:matrix.shikpooshaan.ir	@brian:matrix.shikpooshaan.ir	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	invite	0	alextaylor98	mxc://matrix.shikpooshaan.ir/ZvnUeFyFDpHyzXqzuIhncSVg	103	f
$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk	@alextaylor98:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	join	0	alextaylor98	mxc://matrix.shikpooshaan.ir/ZvnUeFyFDpHyzXqzuIhncSVg	104	t
$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	@brian:matrix.shikpooshaan.ir	@brian:matrix.shikpooshaan.ir	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	join	0	brian	\N	97	t
\.


--
-- Data for Name: room_reports; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.room_reports (id, received_ts, room_id, user_id, reason) FROM stdin;
\.


--
-- Data for Name: room_retention; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.room_retention (room_id, event_id, min_lifetime, max_lifetime) FROM stdin;
\.


--
-- Data for Name: room_stats_current; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.room_stats_current (room_id, current_state_events, joined_members, invited_members, left_members, banned_members, local_users_in_room, completed_delta_stream_id, knocked_members) FROM stdin;
!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	8	1	0	1	0	1	18	0
!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	8	2	0	0	0	2	36	0
!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	8	2	0	0	0	2	70	0
!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	8	2	0	0	0	2	71	0
!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	8	1	1	0	0	1	79	0
!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	8	2	0	0	0	2	92	0
!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	8	1	0	1	0	1	95	0
!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	8	2	0	0	0	2	104	0
\.


--
-- Data for Name: room_stats_earliest_token; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.room_stats_earliest_token (room_id, token) FROM stdin;
\.


--
-- Data for Name: room_stats_state; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.room_stats_state (room_id, name, canonical_alias, join_rules, history_visibility, encryption, avatar, guest_access, is_federatable, topic, room_type) FROM stdin;
!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	\N	\N	invite	invited	m.megolm.v1.aes-sha2	\N	can_join	t	\N	\N
!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	\N	\N	invite	invited	m.megolm.v1.aes-sha2	\N	can_join	t	\N	\N
!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	\N	\N	invite	invited	m.megolm.v1.aes-sha2	\N	can_join	t	\N	\N
!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	\N	\N	invite	invited	m.megolm.v1.aes-sha2	\N	can_join	t	\N	\N
!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	\N	\N	invite	invited	m.megolm.v1.aes-sha2	\N	can_join	t	\N	\N
!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	\N	\N	invite	invited	m.megolm.v1.aes-sha2	\N	can_join	t	\N	\N
!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	\N	\N	invite	invited	m.megolm.v1.aes-sha2	\N	can_join	t	\N	\N
!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	\N	\N	invite	invited	m.megolm.v1.aes-sha2	\N	can_join	t	\N	\N
\.


--
-- Data for Name: room_tags; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.room_tags (user_id, room_id, tag, content) FROM stdin;
\.


--
-- Data for Name: room_tags_revisions; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.room_tags_revisions (user_id, room_id, stream_id, instance_name) FROM stdin;
\.


--
-- Data for Name: rooms; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.rooms (room_id, is_public, creator, room_version, has_auth_chain_index) FROM stdin;
!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	f	@brianrockwell:matrix.shikpooshaan.ir	10	t
!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	f	@alextaylor98:matrix.shikpooshaan.ir	10	t
!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	f	@brianrockwell:matrix.shikpooshaan.ir	10	t
!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	f	@alex-taylor:matrix.shikpooshaan.ir	10	t
!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	f	@alipaz:matrix.shikpooshaan.ir	10	t
!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	f	@alex-taylor:matrix.shikpooshaan.ir	10	t
!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	f	@alex-taylor:matrix.shikpooshaan.ir	10	t
!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	f	@brian:matrix.shikpooshaan.ir	10	t
\.


--
-- Data for Name: scheduled_tasks; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.scheduled_tasks (id, action, status, "timestamp", resource_id, params, result, error) FROM stdin;
delete_old_otks_task	delete_old_otks	complete	1783624366666	\N	\N	\N	\N
JNpSgCXznpDgXfTu	update_join_states	complete	1783669888896	@alex-taylor:matrix.shikpooshaan.ir	{"requester_authenticated_entity":"@alex-taylor:matrix.shikpooshaan.ir"}	{"last_room_id":"!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir"}	\N
EMXLNOjvsxEwPiXP	update_join_states	complete	1783669998874	@alex-taylor:matrix.shikpooshaan.ir	{"requester_authenticated_entity":"@alex-taylor:matrix.shikpooshaan.ir"}	{"last_room_id":"!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir"}	\N
JULMsjJXNsSNlHgw	update_join_states	complete	1783670496054	@alextaylor98:matrix.shikpooshaan.ir	{"requester_authenticated_entity":"@alextaylor98:matrix.shikpooshaan.ir"}	{"last_room_id":"!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir"}	\N
\.


--
-- Data for Name: schema_compat_version; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.schema_compat_version (lock, compat_version) FROM stdin;
X	84
\.


--
-- Data for Name: schema_version; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.schema_version (lock, version, upgraded) FROM stdin;
X	94	t
\.


--
-- Data for Name: server_keys_json; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.server_keys_json (server_name, key_id, from_server, ts_added_ms, ts_valid_until_ms, key_json) FROM stdin;
\.


--
-- Data for Name: server_signature_keys; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.server_signature_keys (server_name, key_id, from_server, ts_added_ms, verify_key, ts_valid_until_ms) FROM stdin;
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.sessions (session_type, session_id, value, expiry_time_ms) FROM stdin;
\.


--
-- Data for Name: sliding_sync_connection_lazy_members; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.sliding_sync_connection_lazy_members (connection_key, connection_position, room_id, user_id, last_seen_ts) FROM stdin;
1	\N	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	1783625249274
9	\N	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	@brianrockwell:matrix.shikpooshaan.ir	1783625716138
1	\N	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	1783625720921
1	\N	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	1783626315566
17	33	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	1783626359315
19	\N	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	1783626826523
19	\N	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	@alipaz:matrix.shikpooshaan.ir	1783627139286
25	46	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	@alipaz:matrix.shikpooshaan.ir	1783627159704
26	\N	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	1783667624763
26	\N	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	@alipaz:matrix.shikpooshaan.ir	1783669889028
26	\N	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	@alextaylor:matrix.shikpooshaan.ir	1783670159151
26	\N	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	1783670199546
9	\N	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	1783670496191
30	63	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	1783670517199
31	\N	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	1783671834113
31	\N	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	1783671834113
32	\N	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	1783672405575
9	\N	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	@brian:matrix.shikpooshaan.ir	1783672410560
37	75	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	@brian:matrix.shikpooshaan.ir	1783672467207
38	76	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	1783672537477
\.


--
-- Data for Name: sliding_sync_connection_positions; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.sliding_sync_connection_positions (connection_position, connection_key, created_ts) FROM stdin;
63	30	1783670517193
64	31	1783671834094
69	32	1783672406830
71	9	1783672410849
75	37	1783672467200
76	38	1783672537471
26	1	1783626316413
33	17	1783626359310
34	18	1783626825760
40	19	1783627139279
46	25	1783627159698
57	26	1783670200742
\.


--
-- Data for Name: sliding_sync_connection_required_state; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.sliding_sync_connection_required_state (required_state_id, connection_key, required_state) FROM stdin;
2	1	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.history_visibility",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.pinned_events",""],["m.room.power_levels",""],["m.room.tombstone",""],["m.room.topic",""],["m.space.child","*"],["m.space.parent","*"],["org.matrix.msc3401.call.member","*"],["org.matrix.msc3672.beacon_info","*"]]
11	9	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.history_visibility",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.pinned_events",""],["m.room.power_levels",""],["m.room.tombstone",""],["m.room.topic",""],["m.space.child","*"],["m.space.parent","*"],["org.matrix.msc3401.call.member","*"],["org.matrix.msc3672.beacon_info","*"]]
21	17	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.power_levels",""],["org.matrix.msc3401.call.member","*"]]
22	18	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.history_visibility",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.power_levels",""],["m.room.tombstone",""],["m.room.topic",""],["m.space.child","*"],["m.space.parent","*"],["org.matrix.msc3401.call.member","*"],["org.matrix.msc3672.beacon_info","*"]]
24	19	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.history_visibility",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.pinned_events",""],["m.room.power_levels",""],["m.room.tombstone",""],["m.room.topic",""],["m.space.child","*"],["m.space.parent","*"],["org.matrix.msc3401.call.member","*"],["org.matrix.msc3672.beacon_info","*"]]
31	25	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.power_levels",""],["org.matrix.msc3401.call.member","*"]]
33	26	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.history_visibility",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.pinned_events",""],["m.room.power_levels",""],["m.room.tombstone",""],["m.room.topic",""],["m.space.child","*"],["m.space.parent","*"],["org.matrix.msc3401.call.member","*"],["org.matrix.msc3672.beacon_info","*"]]
41	30	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.power_levels",""],["org.matrix.msc3401.call.member","*"]]
42	31	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.history_visibility",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.power_levels",""],["m.room.tombstone",""],["m.room.topic",""],["m.space.child","*"],["m.space.parent","*"],["org.matrix.msc3401.call.member","*"],["org.matrix.msc3672.beacon_info","*"]]
46	32	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.history_visibility",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.pinned_events",""],["m.room.power_levels",""],["m.room.tombstone",""],["m.room.topic",""],["m.space.child","*"],["m.space.parent","*"],["org.matrix.msc3401.call.member","*"],["org.matrix.msc3672.beacon_info","*"]]
50	37	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.power_levels",""],["org.matrix.msc3401.call.member","*"]]
51	38	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.power_levels",""],["org.matrix.msc3401.call.member","*"]]
\.


--
-- Data for Name: sliding_sync_connection_room_configs; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.sliding_sync_connection_room_configs (connection_position, room_id, timeline_limit, required_state_id) FROM stdin;
75	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	16	50
46	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	16	31
76	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	16	51
57	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	20	33
57	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	20	33
57	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	20	33
26	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	20	2
26	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	20	2
57	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	20	33
26	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	20	2
33	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	16	21
34	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	1	22
63	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	16	41
64	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	1	42
64	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	1	42
40	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	20	24
40	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	20	24
69	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	20	46
71	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	20	11
71	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	20	11
71	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	20	11
\.


--
-- Data for Name: sliding_sync_connection_streams; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.sliding_sync_connection_streams (connection_position, stream, room_id, room_status, last_token) FROM stdin;
75	rooms	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	live	\N
75	account_data	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	live	\N
76	rooms	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	live	\N
76	account_data	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	live	\N
40	rooms	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	live	\N
40	receipts	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	live	\N
40	account_data	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	live	\N
40	rooms	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	live	\N
40	receipts	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	live	\N
40	account_data	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	live	\N
63	rooms	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	live	\N
63	account_data	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	live	\N
64	rooms	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	live	\N
26	rooms	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	live	\N
26	account_data	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	live	\N
64	rooms	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	live	\N
64	receipts	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	live	\N
64	receipts	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	live	\N
64	account_data	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	live	\N
46	rooms	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	live	\N
26	rooms	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	live	\N
26	receipts	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	live	\N
26	account_data	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	live	\N
26	receipts	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	previously	6
26	rooms	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	live	\N
26	receipts	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	live	\N
26	account_data	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	live	\N
46	account_data	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	live	\N
64	account_data	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	live	\N
33	rooms	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	live	\N
33	account_data	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	live	\N
34	rooms	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	live	\N
34	receipts	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	live	\N
34	account_data	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	live	\N
69	rooms	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	live	\N
69	receipts	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	live	\N
69	account_data	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	live	\N
71	rooms	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	live	\N
71	receipts	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	live	\N
71	account_data	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	live	\N
71	rooms	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	live	\N
71	receipts	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	live	\N
71	account_data	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	live	\N
71	rooms	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	live	\N
71	receipts	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	live	\N
71	account_data	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	live	\N
57	rooms	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	live	\N
57	rooms	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	live	\N
57	receipts	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	live	\N
57	receipts	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	live	\N
57	account_data	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	live	\N
57	account_data	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	live	\N
57	rooms	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	live	\N
57	receipts	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	live	\N
57	account_data	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	live	\N
57	rooms	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	live	\N
57	receipts	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	live	\N
57	account_data	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	live	\N
\.


--
-- Data for Name: sliding_sync_connections; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.sliding_sync_connections (connection_key, user_id, effective_device_id, conn_id, created_ts, last_used_ts) FROM stdin;
1	@brianrockwell:matrix.shikpooshaan.ir	KYQHVGSULI	room-list	1783625248491	1783626231597
17	@brianrockwell:matrix.shikpooshaan.ir	KYQHVGSULI	notifications	1783626359309	1783626359309
18	@alex-taylor:matrix.shikpooshaan.ir	OFUSOVXTZJ	room-list	1783626825754	1783626825754
25	@alex-taylor:matrix.shikpooshaan.ir	OFUSOVXTZJ	notifications	1783627159696	1783627159696
19	@alex-taylor:matrix.shikpooshaan.ir	OFUSOVXTZJ	room-list	1783626825759	1783667435269
26	@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	room-list	1783667624644	1783670158709
30	@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	notifications	1783670517192	1783670517192
31	@brianrockwell:matrix.shikpooshaan.ir	WRMJDYQTPZ	room-list	1783671834092	1783671834092
32	@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	room-list	1783672404090	1783672404090
9	@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	room-list	1783625715577	1783672405460
37	@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	notifications	1783672467199	1783672467199
38	@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	notifications	1783672537470	1783672537470
\.


--
-- Data for Name: sliding_sync_joined_rooms; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.sliding_sync_joined_rooms (room_id, event_stream_ordering, bump_stamp, room_type, room_name, is_encrypted, tombstone_successor_room_id) FROM stdin;
!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	70	45	\N	\N	t	\N
!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	71	67	\N	\N	t	\N
!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	79	72	\N	\N	t	\N
!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	18	17	\N	\N	t	\N
!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	94	94	\N	\N	t	\N
!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	95	19	\N	\N	t	\N
!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	109	109	\N	\N	t	\N
!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	44	44	\N	\N	t	\N
\.


--
-- Data for Name: sliding_sync_joined_rooms_to_recalculate; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.sliding_sync_joined_rooms_to_recalculate (room_id) FROM stdin;
\.


--
-- Data for Name: sliding_sync_membership_snapshots; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.sliding_sync_membership_snapshots (room_id, user_id, sender, membership_event_id, membership, forgotten, event_stream_ordering, event_instance_name, has_known_state, room_type, room_name, is_encrypted, tombstone_successor_room_id) FROM stdin;
!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI	join	0	10	master	t	\N	\N	t	\N
!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	@brianrockwell:matrix.shikpooshaan.ir	@brianrockwell:matrix.shikpooshaan.ir	$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU	leave	0	18	master	t	\N	\N	t	\N
!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	@brianrockwell:matrix.shikpooshaan.ir	@brianrockwell:matrix.shikpooshaan.ir	$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg	join	0	27	master	t	\N	\N	t	\N
!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	@brianrockwell:matrix.shikpooshaan.ir	@brianrockwell:matrix.shikpooshaan.ir	$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	join	0	29	master	t	\N	\N	f	\N
!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg	join	0	36	master	t	\N	\N	t	\N
!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA	join	0	53	master	t	\N	\N	t	\N
!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	@alipaz:matrix.shikpooshaan.ir	@alipaz:matrix.shikpooshaan.ir	$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	join	0	55	master	t	\N	\N	f	\N
!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo	join	0	70	master	t	\N	\N	t	\N
!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k	join	0	71	master	t	\N	\N	t	\N
!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	join	0	73	master	t	\N	\N	f	\N
!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	@alextaylor:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE	invite	0	79	master	t	\N	\N	t	\N
!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	join	0	81	master	t	\N	\N	f	\N
!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY	join	0	92	master	t	\N	\N	t	\N
!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	$4X_PjJl7QiE3U7c8UuRUw5-rEt6S9u2f1fEzR5tiWso	leave	0	95	master	t	\N	\N	t	\N
!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	@brian:matrix.shikpooshaan.ir	@brian:matrix.shikpooshaan.ir	$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	join	0	97	master	t	\N	\N	f	\N
!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk	join	0	104	master	t	\N	\N	t	\N
\.


--
-- Data for Name: state_events; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.state_events (event_id, room_id, type, state_key, prev_state) FROM stdin;
$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.create		\N
$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.member	@brianrockwell:matrix.shikpooshaan.ir	\N
$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.power_levels		\N
$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.join_rules		\N
$prihY7_PFyGlMWv4ENxfD2iizqJyMNoQbig1eNbs7UY	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.guest_access		\N
$A960r4luhjM4-N8ZlQT_oZvugpHLDMyoL7N8LsvnnlI	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.encryption		\N
$-Yvs0xYmtCB-d_v2Z7zGwQj8jvY11ZDzzMQaPKj3DHw	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.history_visibility		\N
$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	\N
$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	\N
$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.member	@brianrockwell:matrix.shikpooshaan.ir	\N
$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.create		\N
$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	\N
$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.power_levels		\N
$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.join_rules		\N
$pR2OnVDcJjiIYWrhS9nEoocIiQESVvpdsQfYu64Jhp4	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.guest_access		\N
$uPRJ79eQQkEtz9GsgfXr0y-f3JPTNkvLdecu65l13Eo	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.encryption		\N
$h_Aewnb-d3kjnDHdRL1B_3KhQvXaRyb0xNw9N0ctEUM	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.history_visibility		\N
$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.member	@brianrockwell:matrix.shikpooshaan.ir	\N
$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.member	@brianrockwell:matrix.shikpooshaan.ir	\N
$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.create		\N
$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.member	@brianrockwell:matrix.shikpooshaan.ir	\N
$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.power_levels		\N
$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.join_rules		\N
$VWhXTrJ895IdYCilHYuIInhbeUE8rsIzTWUjb7gSL1M	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.guest_access		\N
$egxiNGcQc850qQa01Ox8mP5yoEj1Q5Ex-bzUWtN4W5c	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.encryption		\N
$JrVCAJ9f2DtGYEV120F1HrAvVIjWumvsdBmenypJvNY	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.history_visibility		\N
$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	\N
$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	\N
$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.create		\N
$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	\N
$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.power_levels		\N
$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.join_rules		\N
$14g0e4tQc-4i_Vdo1U2pNGwl-QbxmmrnRRA2DOZjnYs	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.guest_access		\N
$_VnHK-C5uJEI_LtZ6Edmfv4J6T35_tYN-Em2qO-sRyU	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.encryption		\N
$NFsUH4yHF1VWTTF3R7erS73-88ifZ3r1Lk1lrp7s5rI	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.history_visibility		\N
$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	\N
$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	\N
$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.create		\N
$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.member	@alipaz:matrix.shikpooshaan.ir	\N
$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.power_levels		\N
$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.join_rules		\N
$Z2e6JO81o3A3wHKKBJSTB-q68xOeUakOBJi-6H0er2I	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.guest_access		\N
$oUHPDjqakCWglPegHTY6TC8e_Qaqub-Yoh_XfUKTjjc	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.encryption		\N
$ZaaKYiCE_n9AzqSGJntdPRcRM7BRhym69EHSrFwgdac	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.history_visibility		\N
$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	\N
$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	\N
$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	\N
$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	\N
$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	\N
$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	\N
$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.create		\N
$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	\N
$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.power_levels		\N
$ekFlSyfMDYeG34nr1qqB9Bi-AbjdiJ_J9bLNNsHuLKs	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.join_rules		\N
$zc8tOpOdwrt2LhO6ZIPa8Tv1PyclAu-E3cFNvQTB_rw	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.guest_access		\N
$KTjmV6JHWFiwg8JXvrYWGjeMxJtAvzZoRDulWpsNaSw	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.encryption		\N
$Dc3jotNRZdjzDW_y7eg_fRWeyXs382gqm43HSX5lbOI	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.history_visibility		\N
$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.create		\N
$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	\N
$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.power_levels		\N
$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.join_rules		\N
$xRkldK4rXGoVy6SNEazvj_642j0z4vnhDKSsno94oMs	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.guest_access		\N
$RDmQ4EMxY-FgFox84X5UWejaA1ImHNYssM_nyAlLSbs	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.encryption		\N
$YP8LBjVbUpZKdDbx8B7q46a8-CJwDp3EK1qyDJCSoio	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.history_visibility		\N
$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.member	@alextaylor:matrix.shikpooshaan.ir	\N
$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	\N
$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	\N
$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	\N
$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	\N
$4X_PjJl7QiE3U7c8UuRUw5-rEt6S9u2f1fEzR5tiWso	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	\N
$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.create		\N
$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.member	@brian:matrix.shikpooshaan.ir	\N
$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.power_levels		\N
$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.join_rules		\N
$lzdi23BC1bOIDnNJnuoZzfFYBb3iv4PDZ1pw9Tg4z1M	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.guest_access		\N
$d-DLbKD_o_R1rzHrZD8hyXWTZsKArLYnNTv9_1HRatE	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.encryption		\N
$6UQ-qIZULcBYRTpiEHtIjLH-lHfTx1ipANQeBo3ldw0	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.history_visibility		\N
$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	\N
$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	\N
\.


--
-- Data for Name: state_group_edges; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.state_group_edges (state_group, prev_state_group) FROM stdin;
2	1
3	2
4	3
5	4
6	5
7	6
8	7
9	8
10	9
11	10
13	12
14	13
15	14
16	15
17	16
18	17
19	18
20	19
21	20
23	22
24	23
25	24
26	25
27	26
28	27
29	28
30	29
31	30
33	32
34	33
35	34
36	35
37	36
38	37
39	38
40	39
41	40
43	42
44	43
45	44
46	45
47	46
48	47
49	48
50	49
51	50
52	41
53	51
54	52
55	53
57	56
58	57
59	58
60	59
61	60
62	61
63	62
64	63
66	65
67	66
68	67
69	68
70	69
71	70
72	71
73	72
74	73
75	21
76	74
77	75
79	78
80	79
81	80
82	81
83	82
84	83
85	84
86	85
87	86
\.


--
-- Data for Name: state_groups; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.state_groups (id, room_id, event_id) FROM stdin;
1	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE
2	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE
3	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag
4	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4
5	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00
6	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$prihY7_PFyGlMWv4ENxfD2iizqJyMNoQbig1eNbs7UY
7	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$A960r4luhjM4-N8ZlQT_oZvugpHLDMyoL7N8LsvnnlI
8	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$-Yvs0xYmtCB-d_v2Z7zGwQj8jvY11ZDzzMQaPKj3DHw
9	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA
10	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI
11	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU
12	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU
13	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU
14	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY
15	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo
16	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M
17	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$pR2OnVDcJjiIYWrhS9nEoocIiQESVvpdsQfYu64Jhp4
18	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$uPRJ79eQQkEtz9GsgfXr0y-f3JPTNkvLdecu65l13Eo
19	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$h_Aewnb-d3kjnDHdRL1B_3KhQvXaRyb0xNw9N0ctEUM
20	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU
21	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg
22	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY
23	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY
24	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk
25	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM
26	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0
27	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$VWhXTrJ895IdYCilHYuIInhbeUE8rsIzTWUjb7gSL1M
28	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$egxiNGcQc850qQa01Ox8mP5yoEj1Q5Ex-bzUWtN4W5c
29	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$JrVCAJ9f2DtGYEV120F1HrAvVIjWumvsdBmenypJvNY
30	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I
31	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg
32	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg
33	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg
34	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY
35	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw
36	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI
37	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$14g0e4tQc-4i_Vdo1U2pNGwl-QbxmmrnRRA2DOZjnYs
38	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$_VnHK-C5uJEI_LtZ6Edmfv4J6T35_tYN-Em2qO-sRyU
39	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$NFsUH4yHF1VWTTF3R7erS73-88ifZ3r1Lk1lrp7s5rI
40	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA
41	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA
42	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg
43	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg
44	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ
45	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8
46	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE
47	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$Z2e6JO81o3A3wHKKBJSTB-q68xOeUakOBJi-6H0er2I
48	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$oUHPDjqakCWglPegHTY6TC8e_Qaqub-Yoh_XfUKTjjc
49	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$ZaaKYiCE_n9AzqSGJntdPRcRM7BRhym69EHSrFwgdac
50	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA
51	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s
52	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg
53	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A
54	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo
55	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k
56	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4
57	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4
58	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ
59	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY
60	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	$ekFlSyfMDYeG34nr1qqB9Bi-AbjdiJ_J9bLNNsHuLKs
61	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	$zc8tOpOdwrt2LhO6ZIPa8Tv1PyclAu-E3cFNvQTB_rw
62	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	$KTjmV6JHWFiwg8JXvrYWGjeMxJtAvzZoRDulWpsNaSw
63	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	$Dc3jotNRZdjzDW_y7eg_fRWeyXs382gqm43HSX5lbOI
64	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE
65	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U
66	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U
81	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk
82	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ
83	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$lzdi23BC1bOIDnNJnuoZzfFYBb3iv4PDZ1pw9Tg4z1M
84	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$d-DLbKD_o_R1rzHrZD8hyXWTZsKArLYnNTv9_1HRatE
85	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$6UQ-qIZULcBYRTpiEHtIjLH-lHfTx1ipANQeBo3ldw0
67	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14
74	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk
68	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo
69	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw
70	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$xRkldK4rXGoVy6SNEazvj_642j0z4vnhDKSsno94oMs
71	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$RDmQ4EMxY-FgFox84X5UWejaA1ImHNYssM_nyAlLSbs
72	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$YP8LBjVbUpZKdDbx8B7q46a8-CJwDp3EK1qyDJCSoio
73	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg
75	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is
76	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY
77	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$4X_PjJl7QiE3U7c8UuRUw5-rEt6S9u2f1fEzR5tiWso
78	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs
80	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw
79	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs
86	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg
87	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk
\.


--
-- Data for Name: state_groups_pending_deletion; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.state_groups_pending_deletion (sequence_number, state_group, insertion_ts) FROM stdin;
\.


--
-- Data for Name: state_groups_persisting; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.state_groups_persisting (state_group, instance_name) FROM stdin;
\.


--
-- Data for Name: state_groups_state; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.state_groups_state (state_group, room_id, type, state_key, event_id) FROM stdin;
2	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.create		$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE
3	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.member	@brianrockwell:matrix.shikpooshaan.ir	$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag
4	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.power_levels		$GbHRNx72c1zSMBiGv3rUmfu-Od7dOR-sChRbpYJPZZ4
5	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.join_rules		$ShqNy5ePcwCp7ew1TlZecpKf7RcZEL3V5qH18JC6g00
6	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.guest_access		$prihY7_PFyGlMWv4ENxfD2iizqJyMNoQbig1eNbs7UY
7	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.encryption		$A960r4luhjM4-N8ZlQT_oZvugpHLDMyoL7N8LsvnnlI
8	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.history_visibility		$-Yvs0xYmtCB-d_v2Z7zGwQj8jvY11ZDzzMQaPKj3DHw
9	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA
10	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI
11	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	m.room.member	@brianrockwell:matrix.shikpooshaan.ir	$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU
13	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.create		$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU
14	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY
15	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.power_levels		$NHrsL7LxIfjML48FYwUQl3wW4T8PrgM03DkVX8SWElo
16	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.join_rules		$_C4apxv-mbP8ac_qnBOtFhOtAGt2QqQZzk6Lqqq_X5M
17	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.guest_access		$pR2OnVDcJjiIYWrhS9nEoocIiQESVvpdsQfYu64Jhp4
18	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.encryption		$uPRJ79eQQkEtz9GsgfXr0y-f3JPTNkvLdecu65l13Eo
19	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.history_visibility		$h_Aewnb-d3kjnDHdRL1B_3KhQvXaRyb0xNw9N0ctEUM
20	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.member	@brianrockwell:matrix.shikpooshaan.ir	$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU
21	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.member	@brianrockwell:matrix.shikpooshaan.ir	$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg
23	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.create		$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY
24	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.member	@brianrockwell:matrix.shikpooshaan.ir	$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk
25	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.power_levels		$GoDTHfLwuPNZaflYrZ5uEwEUzg3EdCTgXlwkkkkyoZM
26	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.join_rules		$9eRhvVv5034jC37nx9jud5BN0Hm5q2k2lsvwiCMSkZ0
27	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.guest_access		$VWhXTrJ895IdYCilHYuIInhbeUE8rsIzTWUjb7gSL1M
28	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.encryption		$egxiNGcQc850qQa01Ox8mP5yoEj1Q5Ex-bzUWtN4W5c
29	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.history_visibility		$JrVCAJ9f2DtGYEV120F1HrAvVIjWumvsdBmenypJvNY
30	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I
31	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg
33	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.create		$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg
34	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY
35	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.power_levels		$P5NeSv9EaMFrdlwMCxpXsHuvrKZ8OkWV_Wr5hcnhABw
36	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.join_rules		$iPjr6YBB8Bpe9LZtnFihIiHDllDIPif1GWqm0n84oNI
37	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.guest_access		$14g0e4tQc-4i_Vdo1U2pNGwl-QbxmmrnRRA2DOZjnYs
38	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.encryption		$_VnHK-C5uJEI_LtZ6Edmfv4J6T35_tYN-Em2qO-sRyU
39	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.history_visibility		$NFsUH4yHF1VWTTF3R7erS73-88ifZ3r1Lk1lrp7s5rI
40	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA
41	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.member	@ali:matrix.shikpooshaan.ir	$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA
43	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.create		$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg
44	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.member	@alipaz:matrix.shikpooshaan.ir	$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ
45	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.power_levels		$-HOiNnCtPfWi5eFZpktAzDp77dVSTWqPY7HHLfSLRg8
46	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.join_rules		$WJzxNTmMqdRbQ-UoVInG1adL2_F8duNYelTT5YWD_JE
47	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.guest_access		$Z2e6JO81o3A3wHKKBJSTB-q68xOeUakOBJi-6H0er2I
48	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.encryption		$oUHPDjqakCWglPegHTY6TC8e_Qaqub-Yoh_XfUKTjjc
49	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.history_visibility		$ZaaKYiCE_n9AzqSGJntdPRcRM7BRhym69EHSrFwgdac
50	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA
51	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s
52	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg
53	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A
54	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo
55	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k
57	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.create		$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4
58	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ
67	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.member	@alex-taylor:matrix.shikpooshaan.ir	$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14
59	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.power_levels		$tflHkkLJ3-HlfGAWi9Hu4oR3m1aGKbOUJQlkAQScpZY
60	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.join_rules		$ekFlSyfMDYeG34nr1qqB9Bi-AbjdiJ_J9bLNNsHuLKs
61	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.guest_access		$zc8tOpOdwrt2LhO6ZIPa8Tv1PyclAu-E3cFNvQTB_rw
62	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.encryption		$KTjmV6JHWFiwg8JXvrYWGjeMxJtAvzZoRDulWpsNaSw
63	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.history_visibility		$Dc3jotNRZdjzDW_y7eg_fRWeyXs382gqm43HSX5lbOI
68	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.power_levels		$3MKXfAtksiGXnZeTEzs0IiAeZG7k3Vf0VG0TuC5L8Xo
69	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.join_rules		$Rt5AJ4MwXNdUnF0D7leC04DppiXb_1SViplTfQBUNyw
70	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.guest_access		$xRkldK4rXGoVy6SNEazvj_642j0z4vnhDKSsno94oMs
71	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.encryption		$RDmQ4EMxY-FgFox84X5UWejaA1ImHNYssM_nyAlLSbs
72	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.history_visibility		$YP8LBjVbUpZKdDbx8B7q46a8-CJwDp3EK1qyDJCSoio
64	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	m.room.member	@alextaylor:matrix.shikpooshaan.ir	$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE
66	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.create		$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U
73	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg
74	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk
75	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is
76	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY
77	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	$4X_PjJl7QiE3U7c8UuRUw5-rEt6S9u2f1fEzR5tiWso
79	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.create		$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs
80	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.member	@brian:matrix.shikpooshaan.ir	$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw
81	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.power_levels		$gh3-iyVYOLw_9FS847WJ6i2PFK182oQIUUCdhJpS4mk
82	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.join_rules		$9Vl1ylNZsl8OyFHQqxBMRKQ_iIF5iwM4RxVfVbRUpLQ
83	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.guest_access		$lzdi23BC1bOIDnNJnuoZzfFYBb3iv4PDZ1pw9Tg4z1M
84	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.encryption		$d-DLbKD_o_R1rzHrZD8hyXWTZsKArLYnNTv9_1HRatE
85	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.history_visibility		$6UQ-qIZULcBYRTpiEHtIjLH-lHfTx1ipANQeBo3ldw0
86	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg
87	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	m.room.member	@alextaylor98:matrix.shikpooshaan.ir	$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk
\.


--
-- Data for Name: stats_incremental_position; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.stats_incremental_position (lock, stream_id) FROM stdin;
X	109
\.


--
-- Data for Name: sticky_events; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.sticky_events (stream_id, instance_name, event_id, room_id, event_stream_ordering, sender, expires_at) FROM stdin;
\.


--
-- Data for Name: stream_ordering_to_exterm; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.stream_ordering_to_exterm (stream_ordering, room_id, event_id) FROM stdin;
2	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$P_fZ7Sr3pNaRNNQd7iSjwgVotv1YcSOnClNgD8b9tXE
3	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$zjK_bkcIqUhYaBFzgn0PM3OMHW__hsh5nnWtZvuAPag
8	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$-Yvs0xYmtCB-d_v2Z7zGwQj8jvY11ZDzzMQaPKj3DHw
9	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$1c9RcERbphg65byjmNJt8Dy2XKTK2dBeIsr9Lfe4ugA
10	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$C35t9WSqKBag3ZWaMpiRuuL92vj1oagSmq7IF9B-tuI
11	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$X8K_VFEiQvuPoOUsEKgfuQVwB45D2aU4Otzgi42XIKA
12	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$M3CKOhgprwuo0MJ8t87vLcopCe-GbCoKg7i0182GwRY
13	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$QRnyjHg7tbmZzQ96yfYxKL3mWswOmQhqDX8uf-mQqZY
14	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$VDxFUMtILxytmO-s2kFHdkmCGyfSuMGfvtuZK6zZf3Q
15	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$ZzByIqF4yAyhZDP-bd2SHZXxQ5OlHpoF1y4i0fQps0A
16	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$O8ybWunHmG8woUBjshPybaeo067xS8r1LX3jsFYbF_M
17	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$OYsK4JS05N5L1dz1HFkKo5nIk3YnZZbM5RB4ZkCos6Q
18	!KcMqMVEGXgVDtToSQe:matrix.shikpooshaan.ir	$2NVcVx37Om763eJ_RR8mfI9nLCMqhRxG4Y1bK9eB_OU
19	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$2-9hULUM3yiULNBjSqGFUAUKujNzlROB5E2e4LH9VXU
20	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$j2g2u6KanikGqhFMxZTLsZ3W0syhMl5qNbUf4713oeY
25	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$h_Aewnb-d3kjnDHdRL1B_3KhQvXaRyb0xNw9N0ctEUM
26	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$7Kv6WoJzos0CaGTH8MJDayigvUhL2Ep9qutzGVqebfU
27	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$Sjn0tnzcM0DPgJJf5us7z-KHnOqd1nG9U9l4gs-Xizg
28	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$vQ1wZ7THByrN0vyAy8oOahYdJyScYC0y7RecBzKLVbY
29	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$ZiXMNZ_vurGz1kSCP7EycAKV3ei-SBXqzW8xwKK3iVk
34	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$JrVCAJ9f2DtGYEV120F1HrAvVIjWumvsdBmenypJvNY
35	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$kaY1JEDfkzav5TWtDKicTULvnd8VwxhzNe1KM0B8y3I
36	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$n1CR7W6C3EaqjeYIL1zFS9aErMKNxtFoEDEerOqhVsg
37	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$38B-Weejbpnil6mQvy5fn8Vc0qGoDasfdZ5t3hdt-u4
38	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$uMZ-ZidlxCHhXanXLN1-ytrhTVb9h1j1K2u-ZEvFmLI
39	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$5P00VdpT2xziYLl8SJGwC9nL-vpZPERv25JcU1tQEy4
40	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$bJp5268AbMlSvGSOLwL1QuROb-6Q8w3--hz5R4shhsE
41	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$nX0BIvxzfiMjoGPKmnp3zaDJ_Lwe4buCfaVfv4wKHAA
42	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$MKIG_xPNWt7pAeRQie1-ff8u79mcVuNrOYFINP7GYb8
43	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$C3PYkudwbc1C1vhjMWGEuUhQS2SwdWK2dFzNgexrfug
44	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir	$7683AfvdvVGbujZUglQ3dOVMhLfC5n8sd4USeya9_9A
45	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$UBs1Gh_ONEb2yNIqK-gYBDfS7KNsckusZ-Ht2iN2FPg
46	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$haNu-rQ9rVN4lZ05QLAWtznir07nS4M6K3a3ktTe2BY
51	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$NFsUH4yHF1VWTTF3R7erS73-88ifZ3r1Lk1lrp7s5rI
52	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$SgPlYHrVg86r1ciLAStBeVJvgXcleJYPTlZfxSeaaSA
53	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$5fN_l34pGtGPykcqoQsPgkq3DL1Kh1U1_evcJHlNuJA
54	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$G0PYRDPYkjO6ROUUztlFSPC_1HTc-0bax7Vf8d2U0Vg
55	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$pyQtUGLOekG3LZMYXhrxVOsl8uTX1a8nPOiVcwTPDGQ
60	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$ZaaKYiCE_n9AzqSGJntdPRcRM7BRhym69EHSrFwgdac
61	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$-f0TaVbkQmXVOvDm5EC-qbPMNR8Kz5BP3BJBGaZk_WA
62	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$SDfp6dI7fZ060UQpEcn0OuljO3cG4dsXHdvlIipF70s
63	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$ExyXltZ8XVgCS4zv7cy-lT_wdLHC4I6gFOEe9WIXLxo
64	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$afVsFJEIQ2l3SduwcVGDn3fVRxWpwp6Z294e_VvMTFc
65	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$2F_r1QYHaObawQDNr91dUNyPG7vMIy94v6I6KmYFAYk
66	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$_H2DZoM2QWFOqEQG70J87qAZM3H467C9Jlh4_5gWzzI
67	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$nOti7xJQKHyROEyoGtsBKtap-hocvso_bgZ53R7EE8U
68	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$K6g-v-PD0whq0RdiydaCQhAuDGQ-y-RHa6V8vZkp4dg
69	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$jewTzVKGeKSp9yf8xxvenRuo8bHWV7RhUV5fytt8L9A
70	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir	$kCUtRA3-PJnsv8NxWze2Tb8VFUzHz6qiFcNsW6wuZGo
71	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir	$GKarxQGO1Zf2SOLnVdoTn8JRtkxGDqgTwbnNkZsb63k
72	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	$P1tc2UPqxYRD1GEAAbrtxOlXsBOdpxpTqh5l9H8oUb4
73	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	$T-NMx-DjGqeRzlO5xlZqL_TXVysbAVqhkYtTZ33I8zQ
78	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	$Dc3jotNRZdjzDW_y7eg_fRWeyXs382gqm43HSX5lbOI
79	!OOyjDCgcgSNbMkQQFj:matrix.shikpooshaan.ir	$nU_nLwTCv7arbvK2Lo-bj_qwInCMUW2RV2IbQQGegAE
80	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$ng91vq4k6sz6yCxAi6BK97EjqTLCo67rrjcub4zFo8U
81	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$zgFV94eAIG2XMAkokG4J1Sy14NM-iZX_12ZUXs79x14
86	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$YP8LBjVbUpZKdDbx8B7q46a8-CJwDp3EK1qyDJCSoio
87	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$bFlAnkXCDNmwtIuJmIQvSwURTFQRGiFMsEAriIVxXNg
88	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$QI4c52uz9lHSuXjd0y5Ja2UeoBhK_zqRVthe19HPrBk
89	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$Np7L2UpX2tMrmcWkrhqTkIPPQf2JHPiRI9eGpZCUi9k
90	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$Ax7Nf2f62jFM6Iukww-bvFvDhxGkhcDQHJOA8GGe3pg
91	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$CMhqsPLbVtTtTUSF7rwrbxlL7ZGkxP8k706Q4Ge-7is
92	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$xfJ5DqLcCT4ggUEPum2uSek2Tf2byr_0S0gpWVvnBWY
93	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$4FmnE3et4KlX8gqLLuDjSYLUFKZG8CgNq8_OPh3TWYY
94	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir	$zM6vJpoUtsXTUex3viHLPy-oiEKdsGSx6OqizILlFdI
95	!KXYdQCvtLSrCINYWtD:matrix.shikpooshaan.ir	$4X_PjJl7QiE3U7c8UuRUw5-rEt6S9u2f1fEzR5tiWso
96	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$9CO14spUtAre6HgyvKmUAJKT0_nclC9jf4MIiuYeXNs
97	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$15oPOjLRrvEv-EUdHOHgM7u8s1hmsfYpMzjua42s6Kw
102	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$6UQ-qIZULcBYRTpiEHtIjLH-lHfTx1ipANQeBo3ldw0
103	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$ukEL9xKQiKjlqcyXkEADwNaH7Fr8qA9s8s3BqaRhvTg
105	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$oZTAqRbttOiPuTLHUN_H2ptq2VqGzcx4o8urdtkZR9A
106	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$x-laZQjLN_ybbNbLzACqCd1-j4uqjJ9UBDzWYpYGv54
104	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$MrCeLAP5gjrsgCnERFRdVhy2Sg9vEG3_mupTk5Z_GZk
107	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$6kTTzdJWNwDbZB4BZt4uyMdlAegiGE1HtQPgLUpZBbs
108	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$Er7aPlzKizvAozxf620HpDa-P3Uqu59Re3mkzFi9s8w
109	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir	$1MLqlvYR1hYyOHAgVVxyOygzdyCxZYc0iLQZrXia5Ls
\.


--
-- Data for Name: stream_positions; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.stream_positions (stream_name, instance_name, stream_id) FROM stdin;
to_device	master	49
events	master	109
receipts	master	29
presence_stream	master	380
account_data	master	101
device_lists_stream	master	75
pushers	master	24
\.


--
-- Data for Name: thread_subscriptions; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.thread_subscriptions (stream_id, instance_name, room_id, event_id, user_id, subscribed, automatic, unsubscribed_at_stream_ordering, unsubscribed_at_topological_ordering) FROM stdin;
\.


--
-- Data for Name: threads; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.threads (room_id, thread_id, latest_event_id, topological_ordering, stream_ordering) FROM stdin;
\.


--
-- Data for Name: threepid_guest_access_tokens; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.threepid_guest_access_tokens (medium, address, guest_access_token, first_inviter) FROM stdin;
\.


--
-- Data for Name: threepid_validation_session; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.threepid_validation_session (session_id, medium, address, client_secret, last_send_attempt, validated_at) FROM stdin;
\.


--
-- Data for Name: threepid_validation_token; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.threepid_validation_token (token, session_id, next_link, expires) FROM stdin;
\.


--
-- Data for Name: timeline_gaps; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.timeline_gaps (room_id, instance_name, stream_ordering) FROM stdin;
\.


--
-- Data for Name: ui_auth_sessions; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.ui_auth_sessions (session_id, creation_time, serverdict, clientdict, uri, method, description) FROM stdin;
TzfzcZrxHhQrrKZgbtuPFXbz	1783626786067	{"request_user_id":"@alex-taylor:matrix.shikpooshaan.ir"}	{"master_key":{"user_id":"@alex-taylor:matrix.shikpooshaan.ir","usage":["master"],"keys":{"ed25519:9rBlDG6qTbTubxNp3++LEV1m/Z4nww7OA8SMeIJzRkk":"9rBlDG6qTbTubxNp3++LEV1m/Z4nww7OA8SMeIJzRkk"},"signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:9rBlDG6qTbTubxNp3++LEV1m/Z4nww7OA8SMeIJzRkk":"P831PUpcy/GWWwE2p4AlSvOZXCEAUEwVvIkMM0Yp2FcHnboTRKfeUXE0nBgG85lmzZGpbLO2zPpNNRyASlk0Ag","ed25519:OFUSOVXTZJ":"rH/xgu9npBuXO+b/5yb7LURVgq2rcJAUWNr4m2EevIqAuzACqxqCR/Y+pfPweWgfs4sPkSpeRrJNdm4OHZMMAw"}}},"self_signing_key":{"user_id":"@alex-taylor:matrix.shikpooshaan.ir","usage":["self_signing"],"keys":{"ed25519:j8Q/cqkuuRUqrYDUFsx4q2rXayMtTZHCFD34Xv+Rkgw":"j8Q/cqkuuRUqrYDUFsx4q2rXayMtTZHCFD34Xv+Rkgw"},"signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:9rBlDG6qTbTubxNp3++LEV1m/Z4nww7OA8SMeIJzRkk":"wekCpK6cbS6NW+HvLv4HiSS9QCnYAg8h1lQksf9cxc+VII4rIN/y1SfwA5pmcZB5cr/cdH69Gqa4VvYvu8T1Dw"}}},"user_signing_key":{"user_id":"@alex-taylor:matrix.shikpooshaan.ir","usage":["user_signing"],"keys":{"ed25519:2c5xO3QJFV3H5v6GYzi7oHYm9fP8vvGmcPZzTsTPrOU":"2c5xO3QJFV3H5v6GYzi7oHYm9fP8vvGmcPZzTsTPrOU"},"signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:9rBlDG6qTbTubxNp3++LEV1m/Z4nww7OA8SMeIJzRkk":"nq4nPnk4VtHftE0p3Pw3B+i+XcfHTO7XFMk/oDmwkkiOCdY85SS95jlPuUyuI95K+eHJtS05QUgL1QwBl1iCAA"}}}}	/_matrix/client/v3/keys/device_signing/upload	POST	reset the device signing key on your account
GnBdDpGVVKMXKUMptirPMxko	1783626797295	{"request_user_id":"@alex-taylor:matrix.shikpooshaan.ir"}	{"master_key":{"user_id":"@alex-taylor:matrix.shikpooshaan.ir","usage":["master"],"keys":{"ed25519:9rBlDG6qTbTubxNp3++LEV1m/Z4nww7OA8SMeIJzRkk":"9rBlDG6qTbTubxNp3++LEV1m/Z4nww7OA8SMeIJzRkk"},"signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:9rBlDG6qTbTubxNp3++LEV1m/Z4nww7OA8SMeIJzRkk":"P831PUpcy/GWWwE2p4AlSvOZXCEAUEwVvIkMM0Yp2FcHnboTRKfeUXE0nBgG85lmzZGpbLO2zPpNNRyASlk0Ag","ed25519:OFUSOVXTZJ":"rH/xgu9npBuXO+b/5yb7LURVgq2rcJAUWNr4m2EevIqAuzACqxqCR/Y+pfPweWgfs4sPkSpeRrJNdm4OHZMMAw"}}},"self_signing_key":{"user_id":"@alex-taylor:matrix.shikpooshaan.ir","usage":["self_signing"],"keys":{"ed25519:j8Q/cqkuuRUqrYDUFsx4q2rXayMtTZHCFD34Xv+Rkgw":"j8Q/cqkuuRUqrYDUFsx4q2rXayMtTZHCFD34Xv+Rkgw"},"signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:9rBlDG6qTbTubxNp3++LEV1m/Z4nww7OA8SMeIJzRkk":"wekCpK6cbS6NW+HvLv4HiSS9QCnYAg8h1lQksf9cxc+VII4rIN/y1SfwA5pmcZB5cr/cdH69Gqa4VvYvu8T1Dw"}}},"user_signing_key":{"user_id":"@alex-taylor:matrix.shikpooshaan.ir","usage":["user_signing"],"keys":{"ed25519:2c5xO3QJFV3H5v6GYzi7oHYm9fP8vvGmcPZzTsTPrOU":"2c5xO3QJFV3H5v6GYzi7oHYm9fP8vvGmcPZzTsTPrOU"},"signatures":{"@alex-taylor:matrix.shikpooshaan.ir":{"ed25519:9rBlDG6qTbTubxNp3++LEV1m/Z4nww7OA8SMeIJzRkk":"nq4nPnk4VtHftE0p3Pw3B+i+XcfHTO7XFMk/oDmwkkiOCdY85SS95jlPuUyuI95K+eHJtS05QUgL1QwBl1iCAA"}}}}	/_matrix/client/v3/keys/device_signing/upload	POST	reset the device signing key on your account
tqpLjBUqFcOoGhmbDGEbRtdD	1783626995397	{}	{}	/_matrix/client/v3/register	POST	register a new account
udjwiwVAlRgcsNFWXptKrPlg	1783671828774	{"request_user_id":"@alextaylor98:matrix.shikpooshaan.ir"}	{"master_key":{"keys":{"ed25519:a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY":"a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY"},"signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"LajeCSEQmA8IJlUsXM6ap7uFeqTmMK8u8kI0AI9iLnuHbuCcLXc23tHXdrr0FPtK5edT+pggXCOILLbsU5jQDw","ed25519:a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY":"uQ9WFeg7r2BGHwZUC+yNvExB1SeEJs7ewqQiAZVzbFgw8lyEAAj2FYdXpqLSvtdbfL/GLEWWIujR8diTMd+kCA"}},"usage":["master"],"user_id":"@alextaylor98:matrix.shikpooshaan.ir"},"self_signing_key":{"keys":{"ed25519:JEWJByMqHvdRd45VbQ89uTuPUUPlJ1EBYuEdQqVuG+c":"JEWJByMqHvdRd45VbQ89uTuPUUPlJ1EBYuEdQqVuG+c"},"signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY":"LGhBb7X3FDvCCVNik+CFNxyMwkSMG3t8VMSrTBrRbHQG38tzaerobynu1lyfoqULHE7INoALgSm7FmOkd6P/AA"}},"usage":["self_signing"],"user_id":"@alextaylor98:matrix.shikpooshaan.ir"},"user_signing_key":{"keys":{"ed25519:tl/tOabB4e6Bu6YBjeVMKsdET92ViX7yBfLyhskIHH8":"tl/tOabB4e6Bu6YBjeVMKsdET92ViX7yBfLyhskIHH8"},"signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY":"Xnccqe7r2KF2r5vYbS6a64mzE/lZbwdQSlzzFHc7IRFVWYAGIhdwC9MaeCAzWb/ePBFug+w4fDSUpPgEknBBAQ"}},"usage":["user_signing"],"user_id":"@alextaylor98:matrix.shikpooshaan.ir"}}	/_matrix/client/v3/keys/device_signing/upload	POST	reset the device signing key on your account
KMzMMJmrnNJLxPPQFFWseWwo	1783627039595	{"password_hash":"$2b$12$Vco3q/gTIJsQeyb35uPTNO3iw.znitt1lCciieUfgW2ZwAoqldcpu","registered_user_id":"@alipaz:matrix.shikpooshaan.ir"}	{"username":"alipaz","initial_device_display_name":"chatapp.shikpooshaan.ir: Chrome on Windows"}	/_matrix/client/v3/register	POST	register a new account
RwgyxQVNITuAlIqEHzpUMOua	1783671829362	{"request_user_id":"@alextaylor98:matrix.shikpooshaan.ir"}	{"master_key":{"keys":{"ed25519:a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY":"a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY"},"signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:CEAAYOLHOD":"LajeCSEQmA8IJlUsXM6ap7uFeqTmMK8u8kI0AI9iLnuHbuCcLXc23tHXdrr0FPtK5edT+pggXCOILLbsU5jQDw","ed25519:a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY":"uQ9WFeg7r2BGHwZUC+yNvExB1SeEJs7ewqQiAZVzbFgw8lyEAAj2FYdXpqLSvtdbfL/GLEWWIujR8diTMd+kCA"}},"usage":["master"],"user_id":"@alextaylor98:matrix.shikpooshaan.ir"},"self_signing_key":{"keys":{"ed25519:JEWJByMqHvdRd45VbQ89uTuPUUPlJ1EBYuEdQqVuG+c":"JEWJByMqHvdRd45VbQ89uTuPUUPlJ1EBYuEdQqVuG+c"},"signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY":"LGhBb7X3FDvCCVNik+CFNxyMwkSMG3t8VMSrTBrRbHQG38tzaerobynu1lyfoqULHE7INoALgSm7FmOkd6P/AA"}},"usage":["self_signing"],"user_id":"@alextaylor98:matrix.shikpooshaan.ir"},"user_signing_key":{"keys":{"ed25519:tl/tOabB4e6Bu6YBjeVMKsdET92ViX7yBfLyhskIHH8":"tl/tOabB4e6Bu6YBjeVMKsdET92ViX7yBfLyhskIHH8"},"signatures":{"@alextaylor98:matrix.shikpooshaan.ir":{"ed25519:a+65gyJOF0AenODvHtW+PQCVkRDPFujHrliif4LwtNY":"Xnccqe7r2KF2r5vYbS6a64mzE/lZbwdQSlzzFHc7IRFVWYAGIhdwC9MaeCAzWb/ePBFug+w4fDSUpPgEknBBAQ"}},"usage":["user_signing"],"user_id":"@alextaylor98:matrix.shikpooshaan.ir"}}	/_matrix/client/v3/keys/device_signing/upload	POST	reset the device signing key on your account
\.


--
-- Data for Name: ui_auth_sessions_credentials; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.ui_auth_sessions_credentials (session_id, stage_type, result) FROM stdin;
GnBdDpGVVKMXKUMptirPMxko	m.login.password	"@alex-taylor:matrix.shikpooshaan.ir"
KMzMMJmrnNJLxPPQFFWseWwo	m.login.dummy	true
RwgyxQVNITuAlIqEHzpUMOua	m.login.password	"@alextaylor98:matrix.shikpooshaan.ir"
\.


--
-- Data for Name: ui_auth_sessions_ips; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.ui_auth_sessions_ips (session_id, ip, user_agent) FROM stdin;
TzfzcZrxHhQrrKZgbtuPFXbz	168.222.49.232	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)
GnBdDpGVVKMXKUMptirPMxko	168.222.49.232	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)
tqpLjBUqFcOoGhmbDGEbRtdD	217.28.137.165	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36
KMzMMJmrnNJLxPPQFFWseWwo	217.28.137.165	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36
udjwiwVAlRgcsNFWXptKrPlg	217.28.137.165	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Element/1.12.23 Chrome/148.0.7778.265 Electron/42.4.1 Safari/537.36
RwgyxQVNITuAlIqEHzpUMOua	217.28.137.165	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Element/1.12.23 Chrome/148.0.7778.265 Electron/42.4.1 Safari/537.36
\.


--
-- Data for Name: un_partial_stated_event_stream; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.un_partial_stated_event_stream (stream_id, instance_name, event_id, rejection_status_changed) FROM stdin;
\.


--
-- Data for Name: un_partial_stated_room_stream; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.un_partial_stated_room_stream (stream_id, instance_name, room_id) FROM stdin;
\.


--
-- Data for Name: user_daily_visits; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.user_daily_visits (user_id, device_id, "timestamp", user_agent) FROM stdin;
@alex-taylor:matrix.shikpooshaan.ir	HPQGRDHEVK	1783555200000	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)
@ali:matrix.shikpooshaan.ir	WGYBGBWZQI	1783555200000	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Element/1.12.23 Chrome/148.0.7778.265 Electron/42.4.1 Safari/537.36
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	1783555200000	Element X/26.06.1 (iPhone 14 Pro Max; iOS 26.5.2; Scale/3.00)
@brianrockwell:matrix.shikpooshaan.ir	KYQHVGSULI	1783555200000	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)
@alex-taylor:matrix.shikpooshaan.ir	OFUSOVXTZJ	1783555200000	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)
@alipaz:matrix.shikpooshaan.ir	SPEPVPSHPR	1783555200000	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36
@monir:matrix.shikpooshaan.ir	WGFMZTWZEK	1783555200000	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36
@alex-taylor:matrix.shikpooshaan.ir	CHFTPUHNYF	1783641600000	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)
@alex-taylor:matrix.shikpooshaan.ir	OFUSOVXTZJ	1783641600000	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)
@ali:matrix.shikpooshaan.ir	WGYBGBWZQI	1783641600000	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Element/1.12.23 Chrome/148.0.7778.265 Electron/42.4.1 Safari/537.36
@alextaylor98:matrix.shikpooshaan.ir	NFLNJMUACW	1783641600000	Element X/26.06.1 (iPhone 14 Pro Max; iOS 26.5.2; Scale/3.00)
@alextaylor98:matrix.shikpooshaan.ir	CEAAYOLHOD	1783641600000	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Element/1.12.23 Chrome/148.0.7778.265 Electron/42.4.1 Safari/537.36
@brian:matrix.shikpooshaan.ir	YOCYFXUGYQ	1783641600000	Element X/26.07.0 (Xiaomi 23021RAAEG; Android 15; AQ3A.240829.003; Sdk 023f5bdce)
\.


--
-- Data for Name: user_directory; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.user_directory (user_id, room_id, display_name, avatar_url) FROM stdin;
@alextaylor:matrix.shikpooshaan.ir	\N	alextaylor	\N
@ali:matrix.shikpooshaan.ir	\N	ali	\N
@brianrockwell:matrix.shikpooshaan.ir	\N	brianrockwell	\N
@alipaz:matrix.shikpooshaan.ir	\N	alipaz	\N
@monir:matrix.shikpooshaan.ir	\N	monir	\N
@aa0922ny:matrix.shikpooshaan.ir	\N	aa0922ny	\N
@alex-taylor:matrix.shikpooshaan.ir	\N	Alex98	mxc://matrix.shikpooshaan.ir/WYjvRrHdQwXttYBqKVGTNjYo
@alextaylor98:matrix.shikpooshaan.ir	\N	alextaylor98	mxc://matrix.shikpooshaan.ir/ZvnUeFyFDpHyzXqzuIhncSVg
@brian:matrix.shikpooshaan.ir	\N	brian	\N
\.


--
-- Data for Name: user_directory_search; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.user_directory_search (user_id, vector) FROM stdin;
@alextaylor:matrix.shikpooshaan.ir	'alextaylor':1A,3B 'matrix.shikpooshaan.ir':2
@ali:matrix.shikpooshaan.ir	'ali':1A,3B 'matrix.shikpooshaan.ir':2
@brianrockwell:matrix.shikpooshaan.ir	'brianrockwell':1A,3B 'matrix.shikpooshaan.ir':2
@alipaz:matrix.shikpooshaan.ir	'alipaz':1A,3B 'matrix.shikpooshaan.ir':2
@monir:matrix.shikpooshaan.ir	'matrix.shikpooshaan.ir':2 'monir':1A,3B
@aa0922ny:matrix.shikpooshaan.ir	'aa0922ny':1A,3B 'matrix.shikpooshaan.ir':2
@alex-taylor:matrix.shikpooshaan.ir	'alex':2A 'alex-taylor':1A 'alex98':5B 'matrix.shikpooshaan.ir':4 'taylor':3A
@alextaylor98:matrix.shikpooshaan.ir	'alextaylor98':1A,3B 'matrix.shikpooshaan.ir':2
@brian:matrix.shikpooshaan.ir	'brian':1A,3B 'matrix.shikpooshaan.ir':2
\.


--
-- Data for Name: user_directory_stale_remote_users; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.user_directory_stale_remote_users (user_id, user_server_name, next_try_at_ts, retry_counter) FROM stdin;
\.


--
-- Data for Name: user_directory_stream_pos; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.user_directory_stream_pos (lock, stream_id) FROM stdin;
X	109
\.


--
-- Data for Name: user_external_ids; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.user_external_ids (auth_provider, external_id, user_id) FROM stdin;
\.


--
-- Data for Name: user_filters; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.user_filters (user_id, filter_id, filter_json, full_user_id) FROM stdin;
ali	0	\\x7b22726f6f6d223a7b227374617465223a7b226c617a795f6c6f61645f6d656d62657273223a747275657d2c2274696d656c696e65223a7b22756e726561645f7468726561645f6e6f74696669636174696f6e73223a747275657d7d7d	@ali:matrix.shikpooshaan.ir
alipaz	0	\\x7b22726f6f6d223a7b227374617465223a7b226c617a795f6c6f61645f6d656d62657273223a747275657d2c2274696d656c696e65223a7b22756e726561645f7468726561645f6e6f74696669636174696f6e73223a747275657d7d7d	@alipaz:matrix.shikpooshaan.ir
monir	0	\\x7b22726f6f6d223a7b227374617465223a7b226c617a795f6c6f61645f6d656d62657273223a747275657d2c2274696d656c696e65223a7b22756e726561645f7468726561645f6e6f74696669636174696f6e73223a747275657d7d7d	@monir:matrix.shikpooshaan.ir
alextaylor98	0	\\x7b22726f6f6d223a7b227374617465223a7b226c617a795f6c6f61645f6d656d62657273223a747275657d2c2274696d656c696e65223a7b22756e726561645f7468726561645f6e6f74696669636174696f6e73223a747275657d7d7d	@alextaylor98:matrix.shikpooshaan.ir
\.


--
-- Data for Name: user_ips; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.user_ips (user_id, access_token, device_id, ip, user_agent, last_seen) FROM stdin;
@alex-taylor:matrix.shikpooshaan.ir	syt_YWxleC10YXlsb3I_MzbdOSwHsgrWWPoTjuzQ_337zkC	HPQGRDHEVK	168.222.49.232	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)	1783625109981
@brianrockwell:matrix.shikpooshaan.ir	syt_YnJpYW5yb2Nrd2VsbA_ugVZqsfWmCMbpPnuRzmR_4gSDFo	WRMJDYQTPZ	217.28.137.165	Element X/26.07.0 (Xiaomi 23021RAAEG; Android 15; AQ3A.240829.003; Sdk 023f5bdce)	1783671973132
@alipaz:matrix.shikpooshaan.ir	syt_YWxpcGF6_LPgkFYTguydoyiTYTumo_3GUZ3Z	SPEPVPSHPR	217.28.137.165	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36	1783628229728
@monir:matrix.shikpooshaan.ir	syt_bW9uaXI_ThRpFyvLvmUlyTkGNgOC_0oZflN	WGFMZTWZEK	217.28.137.165	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36	1783628269767
@monir:matrix.shikpooshaan.ir	syt_bW9uaXI_ThRpFyvLvmUlyTkGNgOC_0oZflN	WGFMZTWZEK	94.24.18.95	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36	1783628283319
@alex-taylor:matrix.shikpooshaan.ir	syt_YWxleC10YXlsb3I_TYsjHasChExFPdRvYTFY_0auyiV	OFUSOVXTZJ	168.222.49.232	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)	1783628386388
@alex-taylor:matrix.shikpooshaan.ir	syt_YWxleC10YXlsb3I_pLQjkRkxGWMsucXnoIiB_4dI8LT	CHFTPUHNYF	93.114.98.127	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)	1783672206052
@alextaylor98:matrix.shikpooshaan.ir	syt_YWxleHRheWxvcjk4_IXeZrfDMuGZGDEHFzjZM_0aT6mb	NFLNJMUACW	93.114.98.127	Element X/26.06.1 (iPhone 14 Pro Max; iOS 26.5.2; Scale/3.00)	1783630249071
@alextaylor98:matrix.shikpooshaan.ir	syt_YWxleHRheWxvcjk4_RxhGRYLCjJMTuYkJENro_0vujPJ	CEAAYOLHOD	217.28.137.165	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Element/1.12.23 Chrome/148.0.7778.265 Electron/42.4.1 Safari/537.36	1783672311527
@alextaylor98:matrix.shikpooshaan.ir	syt_YWxleHRheWxvcjk4_IXeZrfDMuGZGDEHFzjZM_0aT6mb	NFLNJMUACW	217.28.137.165	Element X/26.06.1 (iPhone 14 Pro Max; iOS 26.5.2; Scale/3.00)	1783631262210
@alex-taylor:matrix.shikpooshaan.ir	syt_YWxleC10YXlsb3I_TYsjHasChExFPdRvYTFY_0auyiV	OFUSOVXTZJ	5.122.235.136	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)	1783635465316
@alex-taylor:matrix.shikpooshaan.ir	syt_YWxleC10YXlsb3I_TYsjHasChExFPdRvYTFY_0auyiV	OFUSOVXTZJ	93.114.98.127	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)	1783667563429
@brianrockwell:matrix.shikpooshaan.ir	syt_YnJpYW5yb2Nrd2VsbA_YMQnaUBzwbWbOFkyBBcO_24gRQQ	KYQHVGSULI	168.222.49.232	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)	1783626313523
@brian:matrix.shikpooshaan.ir	syt_YnJpYW4_DfefGINhIqmpDrPzocmq_4GCYMs	YOCYFXUGYQ	217.28.137.165	Element X/26.07.0 (Xiaomi 23021RAAEG; Android 15; AQ3A.240829.003; Sdk 023f5bdce)	1783672600327
@alextaylor98:matrix.shikpooshaan.ir	syt_YWxleHRheWxvcjk4_IXeZrfDMuGZGDEHFzjZM_0aT6mb	NFLNJMUACW	94.24.18.95	Element X/26.06.1 (iPhone 14 Pro Max; iOS 26.5.2; Scale/3.00)	1783672856923
@alex-taylor:matrix.shikpooshaan.ir	syt_YWxleC10YXlsb3I_pLQjkRkxGWMsucXnoIiB_4dI8LT	CHFTPUHNYF	94.24.18.95	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)	1783669888375
@alextaylor98:matrix.shikpooshaan.ir	syt_YWxleHRheWxvcjk4_RxhGRYLCjJMTuYkJENro_0vujPJ	CEAAYOLHOD	94.24.18.95	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Element/1.12.23 Chrome/148.0.7778.265 Electron/42.4.1 Safari/537.36	1783672942646
@ali:matrix.shikpooshaan.ir	syt_YWxp_gJELLPHxEfAqNykGIbFf_040SC8	WGYBGBWZQI	217.28.137.165	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Element/1.12.23 Chrome/148.0.7778.265 Electron/42.4.1 Safari/537.36	1783671375054
@ali:matrix.shikpooshaan.ir	syt_YWxp_gJELLPHxEfAqNykGIbFf_040SC8	WGYBGBWZQI	94.24.18.95	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Element/1.12.23 Chrome/148.0.7778.265 Electron/42.4.1 Safari/537.36	1783671526910
\.


--
-- Data for Name: user_reports; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.user_reports (id, received_ts, target_user_id, user_id, reason) FROM stdin;
\.


--
-- Data for Name: user_signature_stream; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.user_signature_stream (stream_id, from_user_id, user_ids, instance_name) FROM stdin;
7	@ali:matrix.shikpooshaan.ir	["@ali:matrix.shikpooshaan.ir"]	master
15	@alex-taylor:matrix.shikpooshaan.ir	["@alex-taylor:matrix.shikpooshaan.ir"]	master
22	@brianrockwell:matrix.shikpooshaan.ir	["@brianrockwell:matrix.shikpooshaan.ir"]	master
29	@alextaylor98:matrix.shikpooshaan.ir	["@alextaylor98:matrix.shikpooshaan.ir"]	master
35	@alex-taylor:matrix.shikpooshaan.ir	["@alex-taylor:matrix.shikpooshaan.ir"]	master
42	@alipaz:matrix.shikpooshaan.ir	["@alipaz:matrix.shikpooshaan.ir"]	master
49	@monir:matrix.shikpooshaan.ir	["@monir:matrix.shikpooshaan.ir"]	master
63	@alextaylor98:matrix.shikpooshaan.ir	["@alextaylor98:matrix.shikpooshaan.ir"]	master
73	@brian:matrix.shikpooshaan.ir	["@brian:matrix.shikpooshaan.ir"]	master
\.


--
-- Data for Name: user_stats_current; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.user_stats_current (user_id, joined_rooms, completed_delta_stream_id) FROM stdin;
@alextaylor:matrix.shikpooshaan.ir	0	-1
@brianrockwell:matrix.shikpooshaan.ir	2	29
@ali:matrix.shikpooshaan.ir	3	53
@alipaz:matrix.shikpooshaan.ir	1	55
@monir:matrix.shikpooshaan.ir	0	62
@aa0922ny:matrix.shikpooshaan.ir	0	62
@alex-taylor:matrix.shikpooshaan.ir	4	81
@brian:matrix.shikpooshaan.ir	1	97
@alextaylor98:matrix.shikpooshaan.ir	2	104
\.


--
-- Data for Name: user_threepid_id_server; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.user_threepid_id_server (user_id, medium, address, id_server) FROM stdin;
\.


--
-- Data for Name: user_threepids; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.user_threepids (user_id, medium, address, validated_at, added_at) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.users (name, password_hash, creation_ts, admin, upgrade_ts, is_guest, appservice_id, consent_version, consent_server_notice_sent, user_type, deactivated, shadow_banned, consent_ts, approved, locked, suspended) FROM stdin;
@alextaylor98:matrix.shikpooshaan.ir	$2b$12$x.ieQSfGZ9Yx8sDA6IjPU.qDWUXuutuSCnF.pw2nP/wU81gEZzjXC	1783625564	1	\N	0	\N	\N	\N	\N	0	f	\N	t	f	f
@brian:matrix.shikpooshaan.ir	$2b$12$SLNtfSVtu/Yf1qeVslS2veqkKlYnapRwLj.d.oZkiVJvl9yfOPZzu	1783672033	0	\N	0	\N	\N	\N	\N	0	f	\N	t	f	f
\.


--
-- Data for Name: users_in_public_rooms; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.users_in_public_rooms (user_id, room_id) FROM stdin;
\.


--
-- Data for Name: users_pending_deactivation; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.users_pending_deactivation (user_id) FROM stdin;
\.


--
-- Data for Name: users_to_send_full_presence_to; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.users_to_send_full_presence_to (user_id, presence_stream_id) FROM stdin;
\.


--
-- Data for Name: users_who_share_private_rooms; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.users_who_share_private_rooms (user_id, other_user_id, room_id) FROM stdin;
@ali:matrix.shikpooshaan.ir	@brianrockwell:matrix.shikpooshaan.ir	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
@brianrockwell:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	!eEKKabHRFZoDoKWWdJ:matrix.shikpooshaan.ir
@ali:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
@alex-taylor:matrix.shikpooshaan.ir	@ali:matrix.shikpooshaan.ir	!QHjEscKZeXuLOOVCRb:matrix.shikpooshaan.ir
@alex-taylor:matrix.shikpooshaan.ir	@alipaz:matrix.shikpooshaan.ir	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
@alipaz:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	!ZTBchDCYnFcOlMgXKy:matrix.shikpooshaan.ir
@alex-taylor:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
@alextaylor98:matrix.shikpooshaan.ir	@alex-taylor:matrix.shikpooshaan.ir	!XdHIyQrZplpaKxwmjD:matrix.shikpooshaan.ir
@brian:matrix.shikpooshaan.ir	@alextaylor98:matrix.shikpooshaan.ir	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
@alextaylor98:matrix.shikpooshaan.ir	@brian:matrix.shikpooshaan.ir	!uAeMSWEXMXyNciyGZV:matrix.shikpooshaan.ir
\.


--
-- Data for Name: worker_locks; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.worker_locks (lock_name, lock_key, instance_name, token, last_renewed_ts) FROM stdin;
\.


--
-- Data for Name: worker_read_write_locks; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.worker_read_write_locks (lock_name, lock_key, instance_name, write_lock, token, last_renewed_ts) FROM stdin;
\.


--
-- Data for Name: worker_read_write_locks_mode; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.worker_read_write_locks_mode (lock_name, lock_key, write_lock, token) FROM stdin;
\.


--
-- Name: account_data_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.account_data_sequence', 101, true);


--
-- Name: application_services_txn_id_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.application_services_txn_id_seq', 1, false);


--
-- Name: cache_invalidation_stream_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.cache_invalidation_stream_seq', 246, true);


--
-- Name: device_inbox_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.device_inbox_sequence', 49, true);


--
-- Name: device_lists_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.device_lists_sequence', 75, true);


--
-- Name: e2e_cross_signing_keys_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.e2e_cross_signing_keys_sequence', 28, true);


--
-- Name: event_auth_chain_id; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.event_auth_chain_id', 64, true);


--
-- Name: events_backfill_stream_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.events_backfill_stream_seq', 1, true);


--
-- Name: events_stream_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.events_stream_seq', 109, true);


--
-- Name: instance_map_instance_id_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.instance_map_instance_id_seq', 1, false);


--
-- Name: presence_stream_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.presence_stream_sequence', 380, true);


--
-- Name: push_rules_stream_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.push_rules_stream_sequence', 1, true);


--
-- Name: pushers_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.pushers_sequence', 24, true);


--
-- Name: quarantined_media_id_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.quarantined_media_id_seq', 1, true);


--
-- Name: receipts_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.receipts_sequence', 29, true);


--
-- Name: sliding_sync_connection_positions_connection_position_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.sliding_sync_connection_positions_connection_position_seq', 76, true);


--
-- Name: sliding_sync_connection_required_state_required_state_id_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.sliding_sync_connection_required_state_required_state_id_seq', 51, true);


--
-- Name: sliding_sync_connections_connection_key_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.sliding_sync_connections_connection_key_seq', 38, true);


--
-- Name: state_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.state_group_id_seq', 87, true);


--
-- Name: state_groups_pending_deletion_sequence_number_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.state_groups_pending_deletion_sequence_number_seq', 1, false);


--
-- Name: sticky_events_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.sticky_events_sequence', 1, true);


--
-- Name: thread_subscriptions_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.thread_subscriptions_sequence', 2, true);


--
-- Name: un_partial_stated_event_stream_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.un_partial_stated_event_stream_sequence', 1, true);


--
-- Name: un_partial_stated_room_stream_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.un_partial_stated_room_stream_sequence', 1, true);


--
-- Name: user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.user_id_seq', 1, false);


--
-- Name: access_tokens access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.access_tokens
    ADD CONSTRAINT access_tokens_pkey PRIMARY KEY (id);


--
-- Name: access_tokens access_tokens_token_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.access_tokens
    ADD CONSTRAINT access_tokens_token_key UNIQUE (token);


--
-- Name: account_data account_data_uniqueness; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.account_data
    ADD CONSTRAINT account_data_uniqueness UNIQUE (user_id, account_data_type);


--
-- Name: account_validity account_validity_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.account_validity
    ADD CONSTRAINT account_validity_pkey PRIMARY KEY (user_id);


--
-- Name: application_services_state application_services_state_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.application_services_state
    ADD CONSTRAINT application_services_state_pkey PRIMARY KEY (as_id);


--
-- Name: application_services_txns application_services_txns_as_id_txn_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.application_services_txns
    ADD CONSTRAINT application_services_txns_as_id_txn_id_key UNIQUE (as_id, txn_id);


--
-- Name: applied_module_schemas applied_module_schemas_module_name_file_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.applied_module_schemas
    ADD CONSTRAINT applied_module_schemas_module_name_file_key UNIQUE (module_name, file);


--
-- Name: applied_schema_deltas applied_schema_deltas_version_file_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.applied_schema_deltas
    ADD CONSTRAINT applied_schema_deltas_version_file_key UNIQUE (version, file);


--
-- Name: appservice_stream_position appservice_stream_position_lock_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.appservice_stream_position
    ADD CONSTRAINT appservice_stream_position_lock_key UNIQUE (lock);


--
-- Name: background_updates background_updates_uniqueness; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.background_updates
    ADD CONSTRAINT background_updates_uniqueness UNIQUE (update_name);


--
-- Name: current_state_events current_state_events_event_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.current_state_events
    ADD CONSTRAINT current_state_events_event_id_key UNIQUE (event_id);


--
-- Name: current_state_events current_state_events_room_id_type_state_key_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.current_state_events
    ADD CONSTRAINT current_state_events_room_id_type_state_key_key UNIQUE (room_id, type, state_key);


--
-- Name: dehydrated_devices dehydrated_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.dehydrated_devices
    ADD CONSTRAINT dehydrated_devices_pkey PRIMARY KEY (user_id);


--
-- Name: delayed_events delayed_events_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.delayed_events
    ADD CONSTRAINT delayed_events_pkey PRIMARY KEY (user_localpart, delay_id);


--
-- Name: delayed_events_stream_pos delayed_events_stream_pos_lock_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.delayed_events_stream_pos
    ADD CONSTRAINT delayed_events_stream_pos_lock_key UNIQUE (lock);


--
-- Name: destination_rooms destination_rooms_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.destination_rooms
    ADD CONSTRAINT destination_rooms_pkey PRIMARY KEY (destination, room_id);


--
-- Name: destinations destinations_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.destinations
    ADD CONSTRAINT destinations_pkey PRIMARY KEY (destination);


--
-- Name: device_lists_changes_converted_stream_position device_lists_changes_converted_stream_position_lock_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.device_lists_changes_converted_stream_position
    ADD CONSTRAINT device_lists_changes_converted_stream_position_lock_key UNIQUE (lock);


--
-- Name: device_lists_changes_in_room_max_pruned_stream_id device_lists_changes_in_room_max_pruned_stream_id_lock_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.device_lists_changes_in_room_max_pruned_stream_id
    ADD CONSTRAINT device_lists_changes_in_room_max_pruned_stream_id_lock_key UNIQUE (lock);


--
-- Name: device_lists_remote_pending device_lists_remote_pending_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.device_lists_remote_pending
    ADD CONSTRAINT device_lists_remote_pending_pkey PRIMARY KEY (stream_id);


--
-- Name: devices device_uniqueness; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT device_uniqueness UNIQUE (user_id, device_id);


--
-- Name: e2e_device_keys_json e2e_device_keys_json_uniqueness; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.e2e_device_keys_json
    ADD CONSTRAINT e2e_device_keys_json_uniqueness UNIQUE (user_id, device_id);


--
-- Name: e2e_fallback_keys_json e2e_fallback_keys_json_uniqueness; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.e2e_fallback_keys_json
    ADD CONSTRAINT e2e_fallback_keys_json_uniqueness UNIQUE (user_id, device_id, algorithm);


--
-- Name: e2e_one_time_keys_json e2e_one_time_keys_json_uniqueness; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.e2e_one_time_keys_json
    ADD CONSTRAINT e2e_one_time_keys_json_uniqueness UNIQUE (user_id, device_id, algorithm, key_id);


--
-- Name: event_auth_chain_to_calculate event_auth_chain_to_calculate_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.event_auth_chain_to_calculate
    ADD CONSTRAINT event_auth_chain_to_calculate_pkey PRIMARY KEY (event_id);


--
-- Name: event_auth_chains event_auth_chains_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.event_auth_chains
    ADD CONSTRAINT event_auth_chains_pkey PRIMARY KEY (event_id);


--
-- Name: event_backward_extremities event_backward_extremities_event_id_room_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.event_backward_extremities
    ADD CONSTRAINT event_backward_extremities_event_id_room_id_key UNIQUE (event_id, room_id);


--
-- Name: event_expiry event_expiry_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.event_expiry
    ADD CONSTRAINT event_expiry_pkey PRIMARY KEY (event_id);


--
-- Name: event_failed_pull_attempts event_failed_pull_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.event_failed_pull_attempts
    ADD CONSTRAINT event_failed_pull_attempts_pkey PRIMARY KEY (room_id, event_id);


--
-- Name: event_forward_extremities event_forward_extremities_event_id_room_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.event_forward_extremities
    ADD CONSTRAINT event_forward_extremities_event_id_room_id_key UNIQUE (event_id, room_id);


--
-- Name: event_push_actions event_id_user_id_profile_tag_uniqueness; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.event_push_actions
    ADD CONSTRAINT event_id_user_id_profile_tag_uniqueness UNIQUE (room_id, event_id, user_id, profile_tag);


--
-- Name: event_json event_json_event_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.event_json
    ADD CONSTRAINT event_json_event_id_key UNIQUE (event_id);


--
-- Name: event_labels event_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.event_labels
    ADD CONSTRAINT event_labels_pkey PRIMARY KEY (event_id, label);


--
-- Name: event_push_summary_last_receipt_stream_id event_push_summary_last_receipt_stream_id_lock_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.event_push_summary_last_receipt_stream_id
    ADD CONSTRAINT event_push_summary_last_receipt_stream_id_lock_key UNIQUE (lock);


--
-- Name: event_push_summary_stream_ordering event_push_summary_stream_ordering_lock_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.event_push_summary_stream_ordering
    ADD CONSTRAINT event_push_summary_stream_ordering_lock_key UNIQUE (lock);


--
-- Name: event_reports event_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.event_reports
    ADD CONSTRAINT event_reports_pkey PRIMARY KEY (id);


--
-- Name: event_to_state_groups event_to_state_groups_event_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.event_to_state_groups
    ADD CONSTRAINT event_to_state_groups_event_id_key UNIQUE (event_id);


--
-- Name: events events_event_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_event_id_key UNIQUE (event_id);


--
-- Name: ex_outlier_stream ex_outlier_stream_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.ex_outlier_stream
    ADD CONSTRAINT ex_outlier_stream_pkey PRIMARY KEY (event_stream_ordering);


--
-- Name: instance_map instance_map_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.instance_map
    ADD CONSTRAINT instance_map_pkey PRIMARY KEY (instance_id);


--
-- Name: local_media_repository local_media_repository_media_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.local_media_repository
    ADD CONSTRAINT local_media_repository_media_id_key UNIQUE (media_id);


--
-- Name: login_tokens login_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.login_tokens
    ADD CONSTRAINT login_tokens_pkey PRIMARY KEY (token);


--
-- Name: user_threepids medium_address; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.user_threepids
    ADD CONSTRAINT medium_address UNIQUE (medium, address);


--
-- Name: msc4242_state_dag_forward_extremities msc4242_state_dag_forward_extremities_event_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.msc4242_state_dag_forward_extremities
    ADD CONSTRAINT msc4242_state_dag_forward_extremities_event_id_key UNIQUE (event_id);


--
-- Name: open_id_tokens open_id_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.open_id_tokens
    ADD CONSTRAINT open_id_tokens_pkey PRIMARY KEY (token);


--
-- Name: partial_state_events partial_state_events_event_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.partial_state_events
    ADD CONSTRAINT partial_state_events_event_id_key UNIQUE (event_id);


--
-- Name: partial_state_rooms partial_state_rooms_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.partial_state_rooms
    ADD CONSTRAINT partial_state_rooms_pkey PRIMARY KEY (room_id);


--
-- Name: partial_state_rooms_servers partial_state_rooms_servers_room_id_server_name_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.partial_state_rooms_servers
    ADD CONSTRAINT partial_state_rooms_servers_room_id_server_name_key UNIQUE (room_id, server_name);


--
-- Name: per_user_experimental_features per_user_experimental_features_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.per_user_experimental_features
    ADD CONSTRAINT per_user_experimental_features_pkey PRIMARY KEY (user_id, feature);


--
-- Name: profiles profiles_user_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_user_id_key UNIQUE (user_id);


--
-- Name: push_rules_enable push_rules_enable_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.push_rules_enable
    ADD CONSTRAINT push_rules_enable_pkey PRIMARY KEY (id);


--
-- Name: push_rules_enable push_rules_enable_user_name_rule_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.push_rules_enable
    ADD CONSTRAINT push_rules_enable_user_name_rule_id_key UNIQUE (user_name, rule_id);


--
-- Name: push_rules push_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.push_rules
    ADD CONSTRAINT push_rules_pkey PRIMARY KEY (id);


--
-- Name: push_rules push_rules_user_name_rule_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.push_rules
    ADD CONSTRAINT push_rules_user_name_rule_id_key UNIQUE (user_name, rule_id);


--
-- Name: pusher_throttle pusher_throttle_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.pusher_throttle
    ADD CONSTRAINT pusher_throttle_pkey PRIMARY KEY (pusher, room_id);


--
-- Name: pushers pushers2_app_id_pushkey_user_name_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.pushers
    ADD CONSTRAINT pushers2_app_id_pushkey_user_name_key UNIQUE (app_id, pushkey, user_name);


--
-- Name: pushers pushers2_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.pushers
    ADD CONSTRAINT pushers2_pkey PRIMARY KEY (id);


--
-- Name: quarantined_media_changes quarantined_media_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.quarantined_media_changes
    ADD CONSTRAINT quarantined_media_changes_pkey PRIMARY KEY (stream_id);


--
-- Name: receipts_graph receipts_graph_uniqueness_thread; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.receipts_graph
    ADD CONSTRAINT receipts_graph_uniqueness_thread UNIQUE (room_id, receipt_type, user_id, thread_id);


--
-- Name: receipts_linearized receipts_linearized_uniqueness_thread; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.receipts_linearized
    ADD CONSTRAINT receipts_linearized_uniqueness_thread UNIQUE (room_id, receipt_type, user_id, thread_id);


--
-- Name: received_transactions received_transactions_transaction_id_origin_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.received_transactions
    ADD CONSTRAINT received_transactions_transaction_id_origin_key UNIQUE (transaction_id, origin);


--
-- Name: redactions redactions_event_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.redactions
    ADD CONSTRAINT redactions_event_id_key UNIQUE (event_id);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_token_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_token_key UNIQUE (token);


--
-- Name: registration_tokens registration_tokens_token_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.registration_tokens
    ADD CONSTRAINT registration_tokens_token_key UNIQUE (token);


--
-- Name: rejections rejections_event_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.rejections
    ADD CONSTRAINT rejections_event_id_key UNIQUE (event_id);


--
-- Name: remote_media_cache remote_media_cache_media_origin_media_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.remote_media_cache
    ADD CONSTRAINT remote_media_cache_media_origin_media_id_key UNIQUE (media_origin, media_id);


--
-- Name: room_account_data room_account_data_uniqueness; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.room_account_data
    ADD CONSTRAINT room_account_data_uniqueness UNIQUE (user_id, room_id, account_data_type);


--
-- Name: room_aliases room_aliases_room_alias_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.room_aliases
    ADD CONSTRAINT room_aliases_room_alias_key UNIQUE (room_alias);


--
-- Name: room_ban_redactions room_ban_redaction_uniqueness; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.room_ban_redactions
    ADD CONSTRAINT room_ban_redaction_uniqueness UNIQUE (room_id, user_id);


--
-- Name: room_depth room_depth_room_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.room_depth
    ADD CONSTRAINT room_depth_room_id_key UNIQUE (room_id);


--
-- Name: room_forgetter_stream_pos room_forgetter_stream_pos_lock_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.room_forgetter_stream_pos
    ADD CONSTRAINT room_forgetter_stream_pos_lock_key UNIQUE (lock);


--
-- Name: room_memberships room_memberships_event_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.room_memberships
    ADD CONSTRAINT room_memberships_event_id_key UNIQUE (event_id);


--
-- Name: room_reports room_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.room_reports
    ADD CONSTRAINT room_reports_pkey PRIMARY KEY (id);


--
-- Name: room_retention room_retention_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.room_retention
    ADD CONSTRAINT room_retention_pkey PRIMARY KEY (room_id, event_id);


--
-- Name: room_stats_current room_stats_current_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.room_stats_current
    ADD CONSTRAINT room_stats_current_pkey PRIMARY KEY (room_id);


--
-- Name: room_tags_revisions room_tag_revisions_uniqueness; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.room_tags_revisions
    ADD CONSTRAINT room_tag_revisions_uniqueness UNIQUE (user_id, room_id);


--
-- Name: room_tags room_tag_uniqueness; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.room_tags
    ADD CONSTRAINT room_tag_uniqueness UNIQUE (user_id, room_id, tag);


--
-- Name: rooms rooms_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_pkey PRIMARY KEY (room_id);


--
-- Name: scheduled_tasks scheduled_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.scheduled_tasks
    ADD CONSTRAINT scheduled_tasks_pkey PRIMARY KEY (id);


--
-- Name: schema_compat_version schema_compat_version_lock_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.schema_compat_version
    ADD CONSTRAINT schema_compat_version_lock_key UNIQUE (lock);


--
-- Name: schema_version schema_version_lock_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.schema_version
    ADD CONSTRAINT schema_version_lock_key UNIQUE (lock);


--
-- Name: server_keys_json server_keys_json_uniqueness; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.server_keys_json
    ADD CONSTRAINT server_keys_json_uniqueness UNIQUE (server_name, key_id, from_server);


--
-- Name: server_signature_keys server_signature_keys_server_name_key_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.server_signature_keys
    ADD CONSTRAINT server_signature_keys_server_name_key_id_key UNIQUE (server_name, key_id);


--
-- Name: sessions sessions_session_type_session_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_session_type_session_id_key UNIQUE (session_type, session_id);


--
-- Name: sliding_sync_connection_positions sliding_sync_connection_positions_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_connection_positions
    ADD CONSTRAINT sliding_sync_connection_positions_pkey PRIMARY KEY (connection_position);


--
-- Name: sliding_sync_connection_required_state sliding_sync_connection_required_state_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_connection_required_state
    ADD CONSTRAINT sliding_sync_connection_required_state_pkey PRIMARY KEY (required_state_id);


--
-- Name: sliding_sync_connections sliding_sync_connections_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_connections
    ADD CONSTRAINT sliding_sync_connections_pkey PRIMARY KEY (connection_key);


--
-- Name: sliding_sync_joined_rooms sliding_sync_joined_rooms_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_joined_rooms
    ADD CONSTRAINT sliding_sync_joined_rooms_pkey PRIMARY KEY (room_id);


--
-- Name: sliding_sync_joined_rooms_to_recalculate sliding_sync_joined_rooms_to_recalculate_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_joined_rooms_to_recalculate
    ADD CONSTRAINT sliding_sync_joined_rooms_to_recalculate_pkey PRIMARY KEY (room_id);


--
-- Name: sliding_sync_membership_snapshots sliding_sync_membership_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_membership_snapshots
    ADD CONSTRAINT sliding_sync_membership_snapshots_pkey PRIMARY KEY (room_id, user_id);


--
-- Name: state_events state_events_event_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.state_events
    ADD CONSTRAINT state_events_event_id_key UNIQUE (event_id);


--
-- Name: state_groups_pending_deletion state_groups_pending_deletion_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.state_groups_pending_deletion
    ADD CONSTRAINT state_groups_pending_deletion_pkey PRIMARY KEY (sequence_number);


--
-- Name: state_groups_persisting state_groups_persisting_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.state_groups_persisting
    ADD CONSTRAINT state_groups_persisting_pkey PRIMARY KEY (state_group, instance_name);


--
-- Name: state_groups state_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.state_groups
    ADD CONSTRAINT state_groups_pkey PRIMARY KEY (id);


--
-- Name: stats_incremental_position stats_incremental_position_lock_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.stats_incremental_position
    ADD CONSTRAINT stats_incremental_position_lock_key UNIQUE (lock);


--
-- Name: sticky_events sticky_events_event_stream_ordering_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sticky_events
    ADD CONSTRAINT sticky_events_event_stream_ordering_key UNIQUE (event_stream_ordering);


--
-- Name: sticky_events sticky_events_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sticky_events
    ADD CONSTRAINT sticky_events_pkey PRIMARY KEY (stream_id);


--
-- Name: thread_subscriptions thread_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.thread_subscriptions
    ADD CONSTRAINT thread_subscriptions_pkey PRIMARY KEY (stream_id);


--
-- Name: thread_subscriptions thread_subscriptions_room_id_event_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.thread_subscriptions
    ADD CONSTRAINT thread_subscriptions_room_id_event_id_user_id_key UNIQUE (room_id, event_id, user_id);


--
-- Name: threads threads_uniqueness; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.threads
    ADD CONSTRAINT threads_uniqueness UNIQUE (room_id, thread_id);


--
-- Name: threepid_validation_session threepid_validation_session_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.threepid_validation_session
    ADD CONSTRAINT threepid_validation_session_pkey PRIMARY KEY (session_id);


--
-- Name: threepid_validation_token threepid_validation_token_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.threepid_validation_token
    ADD CONSTRAINT threepid_validation_token_pkey PRIMARY KEY (token);


--
-- Name: ui_auth_sessions_credentials ui_auth_sessions_credentials_session_id_stage_type_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.ui_auth_sessions_credentials
    ADD CONSTRAINT ui_auth_sessions_credentials_session_id_stage_type_key UNIQUE (session_id, stage_type);


--
-- Name: ui_auth_sessions_ips ui_auth_sessions_ips_session_id_ip_user_agent_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.ui_auth_sessions_ips
    ADD CONSTRAINT ui_auth_sessions_ips_session_id_ip_user_agent_key UNIQUE (session_id, ip, user_agent);


--
-- Name: ui_auth_sessions ui_auth_sessions_session_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.ui_auth_sessions
    ADD CONSTRAINT ui_auth_sessions_session_id_key UNIQUE (session_id);


--
-- Name: un_partial_stated_event_stream un_partial_stated_event_stream_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.un_partial_stated_event_stream
    ADD CONSTRAINT un_partial_stated_event_stream_pkey PRIMARY KEY (stream_id);


--
-- Name: un_partial_stated_room_stream un_partial_stated_room_stream_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.un_partial_stated_room_stream
    ADD CONSTRAINT un_partial_stated_room_stream_pkey PRIMARY KEY (stream_id);


--
-- Name: user_directory_stale_remote_users user_directory_stale_remote_users_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.user_directory_stale_remote_users
    ADD CONSTRAINT user_directory_stale_remote_users_pkey PRIMARY KEY (user_id);


--
-- Name: user_directory_stream_pos user_directory_stream_pos_lock_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.user_directory_stream_pos
    ADD CONSTRAINT user_directory_stream_pos_lock_key UNIQUE (lock);


--
-- Name: user_external_ids user_external_ids_auth_provider_external_id_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.user_external_ids
    ADD CONSTRAINT user_external_ids_auth_provider_external_id_key UNIQUE (auth_provider, external_id);


--
-- Name: user_reports user_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.user_reports
    ADD CONSTRAINT user_reports_pkey PRIMARY KEY (id);


--
-- Name: user_stats_current user_stats_current_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.user_stats_current
    ADD CONSTRAINT user_stats_current_pkey PRIMARY KEY (user_id);


--
-- Name: users users_name_key; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_name_key UNIQUE (name);


--
-- Name: users_to_send_full_presence_to users_to_send_full_presence_to_pkey; Type: CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.users_to_send_full_presence_to
    ADD CONSTRAINT users_to_send_full_presence_to_pkey PRIMARY KEY (user_id);


--
-- Name: access_tokens_device_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX access_tokens_device_id ON public.access_tokens USING btree (user_id, device_id);


--
-- Name: access_tokens_refresh_token_id_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX access_tokens_refresh_token_id_idx ON public.access_tokens USING btree (refresh_token_id);


--
-- Name: account_data_stream_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX account_data_stream_id ON public.account_data USING btree (user_id, stream_id);


--
-- Name: application_services_txns_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX application_services_txns_id ON public.application_services_txns USING btree (as_id);


--
-- Name: appservice_room_list_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX appservice_room_list_idx ON public.appservice_room_list USING btree (appservice_id, network_id, room_id);


--
-- Name: blocked_rooms_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX blocked_rooms_idx ON public.blocked_rooms USING btree (room_id);


--
-- Name: cache_invalidation_stream_by_instance_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX cache_invalidation_stream_by_instance_id ON public.cache_invalidation_stream_by_instance USING btree (stream_id);


--
-- Name: cache_invalidation_stream_by_instance_instance_index; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX cache_invalidation_stream_by_instance_instance_index ON public.cache_invalidation_stream_by_instance USING btree (instance_name, stream_id);


--
-- Name: current_state_delta_stream_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX current_state_delta_stream_idx ON public.current_state_delta_stream USING btree (stream_id);


--
-- Name: current_state_delta_stream_room_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX current_state_delta_stream_room_idx ON public.current_state_delta_stream USING btree (room_id, stream_id);


--
-- Name: current_state_events_member_index; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX current_state_events_member_index ON public.current_state_events USING btree (state_key) WHERE (type = 'm.room.member'::text);


--
-- Name: current_state_events_members_room_index; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX current_state_events_members_room_index ON public.current_state_events USING btree (room_id, membership) WHERE (type = 'm.room.member'::text);


--
-- Name: current_state_events_stream_ordering_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX current_state_events_stream_ordering_idx ON public.current_state_events USING btree (event_stream_ordering);


--
-- Name: delayed_events_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX delayed_events_idx ON public.delayed_events USING btree (delay_id);


--
-- Name: delayed_events_is_processed; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX delayed_events_is_processed ON public.delayed_events USING btree (is_processed);


--
-- Name: delayed_events_room_state_event_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX delayed_events_room_state_event_idx ON public.delayed_events USING btree (room_id, event_type, state_key) WHERE (state_key IS NOT NULL);


--
-- Name: delayed_events_send_ts; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX delayed_events_send_ts ON public.delayed_events USING btree (send_ts);


--
-- Name: deleted_pushers_stream_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX deleted_pushers_stream_id ON public.deleted_pushers USING btree (stream_id);


--
-- Name: destination_rooms_room_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX destination_rooms_room_id ON public.destination_rooms USING btree (room_id);


--
-- Name: device_auth_providers_devices; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX device_auth_providers_devices ON public.device_auth_providers USING btree (user_id, device_id);


--
-- Name: device_auth_providers_sessions; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX device_auth_providers_sessions ON public.device_auth_providers USING btree (auth_provider_id, auth_provider_session_id);


--
-- Name: device_federation_inbox_received_ts_index; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX device_federation_inbox_received_ts_index ON public.device_federation_inbox USING btree (received_ts);


--
-- Name: device_federation_inbox_sender_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX device_federation_inbox_sender_id ON public.device_federation_inbox USING btree (origin, message_id);


--
-- Name: device_federation_outbox_destination_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX device_federation_outbox_destination_id ON public.device_federation_outbox USING btree (destination, stream_id);


--
-- Name: device_federation_outbox_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX device_federation_outbox_id ON public.device_federation_outbox USING btree (stream_id);


--
-- Name: device_inbox_stream_id_user_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX device_inbox_stream_id_user_id ON public.device_inbox USING btree (stream_id, user_id);


--
-- Name: device_inbox_user_stream_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX device_inbox_user_stream_id ON public.device_inbox USING btree (user_id, device_id, stream_id);


--
-- Name: device_lists_changes_in_room_by_room_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX device_lists_changes_in_room_by_room_idx ON public.device_lists_changes_in_room USING btree (room_id, stream_id);


--
-- Name: device_lists_changes_in_room_inserted_ts_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX device_lists_changes_in_room_inserted_ts_idx ON public.device_lists_changes_in_room USING btree (inserted_ts) WHERE (inserted_ts IS NOT NULL);


--
-- Name: device_lists_changes_in_stream_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX device_lists_changes_in_stream_id ON public.device_lists_changes_in_room USING btree (stream_id, room_id);


--
-- Name: device_lists_changes_in_stream_id_unconverted; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX device_lists_changes_in_stream_id_unconverted ON public.device_lists_changes_in_room USING btree (stream_id) WHERE (NOT converted_to_destinations);


--
-- Name: device_lists_outbound_last_success_unique_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX device_lists_outbound_last_success_unique_idx ON public.device_lists_outbound_last_success USING btree (destination, user_id);


--
-- Name: device_lists_outbound_pokes_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX device_lists_outbound_pokes_id ON public.device_lists_outbound_pokes USING btree (destination, stream_id);


--
-- Name: device_lists_outbound_pokes_stream; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX device_lists_outbound_pokes_stream ON public.device_lists_outbound_pokes USING btree (stream_id);


--
-- Name: device_lists_outbound_pokes_user; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX device_lists_outbound_pokes_user ON public.device_lists_outbound_pokes USING btree (destination, user_id);


--
-- Name: device_lists_remote_cache_unique_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX device_lists_remote_cache_unique_id ON public.device_lists_remote_cache USING btree (user_id, device_id);


--
-- Name: device_lists_remote_extremeties_unique_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX device_lists_remote_extremeties_unique_idx ON public.device_lists_remote_extremeties USING btree (user_id);


--
-- Name: device_lists_remote_pending_user_device_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX device_lists_remote_pending_user_device_id ON public.device_lists_remote_pending USING btree (user_id, device_id);


--
-- Name: device_lists_remote_resync_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX device_lists_remote_resync_idx ON public.device_lists_remote_resync USING btree (user_id);


--
-- Name: device_lists_remote_resync_ts_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX device_lists_remote_resync_ts_idx ON public.device_lists_remote_resync USING btree (added_ts);


--
-- Name: device_lists_stream_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX device_lists_stream_id ON public.device_lists_stream USING btree (stream_id, user_id);


--
-- Name: device_lists_stream_user_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX device_lists_stream_user_id ON public.device_lists_stream USING btree (user_id, device_id);


--
-- Name: e2e_cross_signing_keys_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX e2e_cross_signing_keys_idx ON public.e2e_cross_signing_keys USING btree (user_id, keytype, stream_id);


--
-- Name: e2e_cross_signing_keys_stream_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX e2e_cross_signing_keys_stream_idx ON public.e2e_cross_signing_keys USING btree (stream_id);


--
-- Name: e2e_cross_signing_signatures2_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX e2e_cross_signing_signatures2_idx ON public.e2e_cross_signing_signatures USING btree (user_id, target_user_id, target_device_id);


--
-- Name: e2e_one_time_keys_json_user_id_device_id_algorithm_ts_added_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX e2e_one_time_keys_json_user_id_device_id_algorithm_ts_added_idx ON public.e2e_one_time_keys_json USING btree (user_id, device_id, algorithm, ts_added_ms);


--
-- Name: e2e_room_keys_room_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX e2e_room_keys_room_id ON public.e2e_room_keys USING btree (room_id);


--
-- Name: e2e_room_keys_versions_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX e2e_room_keys_versions_idx ON public.e2e_room_keys_versions USING btree (user_id, version);


--
-- Name: e2e_room_keys_with_version_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX e2e_room_keys_with_version_idx ON public.e2e_room_keys USING btree (user_id, version, room_id, session_id);


--
-- Name: erased_users_user; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX erased_users_user ON public.erased_users USING btree (user_id);


--
-- Name: ev_b_extrem_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX ev_b_extrem_id ON public.event_backward_extremities USING btree (event_id);


--
-- Name: ev_b_extrem_room; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX ev_b_extrem_room ON public.event_backward_extremities USING btree (room_id);


--
-- Name: ev_edges_prev_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX ev_edges_prev_id ON public.event_edges USING btree (prev_event_id);


--
-- Name: ev_extrem_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX ev_extrem_id ON public.event_forward_extremities USING btree (event_id);


--
-- Name: ev_extrem_room; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX ev_extrem_room ON public.event_forward_extremities USING btree (room_id);


--
-- Name: evauth_edges_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX evauth_edges_id ON public.event_auth USING btree (event_id);


--
-- Name: event_auth_chain_links_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_auth_chain_links_idx ON public.event_auth_chain_links USING btree (origin_chain_id, target_chain_id);


--
-- Name: event_auth_chain_links_origin_index; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_auth_chain_links_origin_index ON public.event_auth_chain_links USING btree (origin_chain_id, origin_sequence_number);


--
-- Name: event_auth_chain_to_calculate_rm_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_auth_chain_to_calculate_rm_id ON public.event_auth_chain_to_calculate USING btree (room_id);


--
-- Name: event_auth_chains_c_seq_index; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX event_auth_chains_c_seq_index ON public.event_auth_chains USING btree (chain_id, sequence_number);


--
-- Name: event_contains_url_index; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_contains_url_index ON public.events USING btree (room_id, topological_ordering, stream_ordering) WHERE ((contains_url = true) AND (outlier = false));


--
-- Name: event_edges_event_id_prev_event_id_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX event_edges_event_id_prev_event_id_idx ON public.event_edges USING btree (event_id, prev_event_id);


--
-- Name: event_expiry_expiry_ts_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_expiry_expiry_ts_idx ON public.event_expiry USING btree (expiry_ts);


--
-- Name: event_failed_pull_attempts_room_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_failed_pull_attempts_room_id ON public.event_failed_pull_attempts USING btree (room_id);


--
-- Name: event_labels_room_id_label_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_labels_room_id_label_idx ON public.event_labels USING btree (room_id, label, topological_ordering);


--
-- Name: event_push_actions_highlights_index; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_push_actions_highlights_index ON public.event_push_actions USING btree (user_id, room_id, topological_ordering, stream_ordering) WHERE (highlight = 1);


--
-- Name: event_push_actions_rm_tokens; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_push_actions_rm_tokens ON public.event_push_actions USING btree (user_id, room_id, topological_ordering, stream_ordering);


--
-- Name: event_push_actions_room_id_user_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_push_actions_room_id_user_id ON public.event_push_actions USING btree (room_id, user_id);


--
-- Name: event_push_actions_staging_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_push_actions_staging_id ON public.event_push_actions_staging USING btree (event_id);


--
-- Name: event_push_actions_stream_highlight_index; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_push_actions_stream_highlight_index ON public.event_push_actions USING btree (highlight, stream_ordering) WHERE (highlight = 0);


--
-- Name: event_push_actions_stream_ordering; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_push_actions_stream_ordering ON public.event_push_actions USING btree (stream_ordering, user_id);


--
-- Name: event_push_actions_u_highlight; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_push_actions_u_highlight ON public.event_push_actions USING btree (user_id, stream_ordering);


--
-- Name: event_push_summary_index_room_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_push_summary_index_room_id ON public.event_push_summary USING btree (room_id);


--
-- Name: event_push_summary_unique_index2; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX event_push_summary_unique_index2 ON public.event_push_summary USING btree (user_id, room_id, thread_id);


--
-- Name: event_relations_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX event_relations_id ON public.event_relations USING btree (event_id);


--
-- Name: event_relations_relates; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_relations_relates ON public.event_relations USING btree (relates_to_id, relation_type, aggregation_key);


--
-- Name: event_search_ev_ridx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_search_ev_ridx ON public.event_search USING btree (room_id);


--
-- Name: event_search_event_id_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX event_search_event_id_idx ON public.event_search USING btree (event_id);


--
-- Name: event_search_fts_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_search_fts_idx ON public.event_search USING gin (vector);


--
-- Name: event_to_state_groups_sg_index; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_to_state_groups_sg_index ON public.event_to_state_groups USING btree (state_group);


--
-- Name: event_txn_id_device_id_event_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX event_txn_id_device_id_event_id ON public.event_txn_id_device_id USING btree (event_id);


--
-- Name: event_txn_id_device_id_ts; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX event_txn_id_device_id_ts ON public.event_txn_id_device_id USING btree (inserted_ts);


--
-- Name: event_txn_id_device_id_txn_id2; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX event_txn_id_device_id_txn_id2 ON public.event_txn_id_device_id USING btree (user_id, device_id, room_id, txn_id);


--
-- Name: events_jump_to_date_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX events_jump_to_date_idx ON public.events USING btree (room_id, origin_server_ts) WHERE (NOT outlier);


--
-- Name: events_order_room; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX events_order_room ON public.events USING btree (room_id, topological_ordering, stream_ordering);


--
-- Name: events_room_stream; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX events_room_stream ON public.events USING btree (room_id, stream_ordering);


--
-- Name: events_stream_ordering; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX events_stream_ordering ON public.events USING btree (stream_ordering);


--
-- Name: events_ts; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX events_ts ON public.events USING btree (origin_server_ts, stream_ordering);


--
-- Name: federation_inbound_events_staging_instance_event; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX federation_inbound_events_staging_instance_event ON public.federation_inbound_events_staging USING btree (origin, event_id);


--
-- Name: federation_inbound_events_staging_room; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX federation_inbound_events_staging_room ON public.federation_inbound_events_staging USING btree (room_id, received_ts);


--
-- Name: federation_stream_position_instance; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX federation_stream_position_instance ON public.federation_stream_position USING btree (type, instance_name);


--
-- Name: full_users_unique_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX full_users_unique_idx ON public.user_filters USING btree (full_user_id, filter_id);


--
-- Name: ignored_users_ignored_user_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX ignored_users_ignored_user_id ON public.ignored_users USING btree (ignored_user_id);


--
-- Name: ignored_users_uniqueness; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX ignored_users_uniqueness ON public.ignored_users USING btree (ignorer_user_id, ignored_user_id);


--
-- Name: instance_map_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX instance_map_idx ON public.instance_map USING btree (instance_name);


--
-- Name: local_current_membership_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX local_current_membership_idx ON public.local_current_membership USING btree (user_id, room_id);


--
-- Name: local_current_membership_room_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX local_current_membership_room_idx ON public.local_current_membership USING btree (room_id);


--
-- Name: local_current_membership_stream_ordering_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX local_current_membership_stream_ordering_idx ON public.local_current_membership USING btree (event_stream_ordering);


--
-- Name: local_media_repository_sha256; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX local_media_repository_sha256 ON public.local_media_repository USING btree (sha256) WHERE (sha256 IS NOT NULL);


--
-- Name: local_media_repository_thumbn_media_id_width_height_method_key; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX local_media_repository_thumbn_media_id_width_height_method_key ON public.local_media_repository_thumbnails USING btree (media_id, thumbnail_width, thumbnail_height, thumbnail_type, thumbnail_method);


--
-- Name: local_media_repository_thumbnails_media_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX local_media_repository_thumbnails_media_id ON public.local_media_repository_thumbnails USING btree (media_id);


--
-- Name: local_media_repository_url_cache_by_url_download_ts; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX local_media_repository_url_cache_by_url_download_ts ON public.local_media_repository_url_cache USING btree (url, download_ts);


--
-- Name: local_media_repository_url_cache_expires_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX local_media_repository_url_cache_expires_idx ON public.local_media_repository_url_cache USING btree (expires_ts);


--
-- Name: local_media_repository_url_cache_media_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX local_media_repository_url_cache_media_idx ON public.local_media_repository_url_cache USING btree (media_id);


--
-- Name: local_media_repository_url_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX local_media_repository_url_idx ON public.local_media_repository USING btree (created_ts) WHERE (url_cache IS NOT NULL);


--
-- Name: login_tokens_auth_provider_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX login_tokens_auth_provider_idx ON public.login_tokens USING btree (auth_provider_id, auth_provider_session_id);


--
-- Name: login_tokens_expiry_time_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX login_tokens_expiry_time_idx ON public.login_tokens USING btree (expiry_ts);


--
-- Name: monthly_active_users_time_stamp; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX monthly_active_users_time_stamp ON public.monthly_active_users USING btree ("timestamp");


--
-- Name: monthly_active_users_users; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX monthly_active_users_users ON public.monthly_active_users USING btree (user_id);


--
-- Name: msc4242_state_dag_edges_key; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX msc4242_state_dag_edges_key ON public.msc4242_state_dag_edges USING btree (room_id, event_id, prev_state_event_id);


--
-- Name: msc4242_state_dag_room; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX msc4242_state_dag_room ON public.msc4242_state_dag_forward_extremities USING btree (room_id);


--
-- Name: open_id_tokens_ts_valid_until_ms; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX open_id_tokens_ts_valid_until_ms ON public.open_id_tokens USING btree (ts_valid_until_ms);


--
-- Name: partial_state_events_room_id_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX partial_state_events_room_id_idx ON public.partial_state_events USING btree (room_id);


--
-- Name: presence_stream_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX presence_stream_id ON public.presence_stream USING btree (stream_id, user_id);


--
-- Name: presence_stream_state_not_offline_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX presence_stream_state_not_offline_idx ON public.presence_stream USING btree (state) WHERE (state <> 'offline'::text);


--
-- Name: presence_stream_user_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX presence_stream_user_id ON public.presence_stream USING btree (user_id);


--
-- Name: profiles_full_user_id_key; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX profiles_full_user_id_key ON public.profiles USING btree (full_user_id);


--
-- Name: public_room_index; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX public_room_index ON public.rooms USING btree (is_public);


--
-- Name: push_rules_enable_user_name; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX push_rules_enable_user_name ON public.push_rules_enable USING btree (user_name);


--
-- Name: push_rules_stream_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX push_rules_stream_id ON public.push_rules_stream USING btree (stream_id);


--
-- Name: push_rules_stream_user_stream_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX push_rules_stream_user_stream_id ON public.push_rules_stream USING btree (user_id, stream_id);


--
-- Name: push_rules_user_name; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX push_rules_user_name ON public.push_rules USING btree (user_name);


--
-- Name: ratelimit_override_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX ratelimit_override_idx ON public.ratelimit_override USING btree (user_id);


--
-- Name: receipts_graph_unique_index; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX receipts_graph_unique_index ON public.receipts_graph USING btree (room_id, receipt_type, user_id) WHERE (thread_id IS NULL);


--
-- Name: receipts_linearized_event_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX receipts_linearized_event_id ON public.receipts_linearized USING btree (room_id, event_id);


--
-- Name: receipts_linearized_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX receipts_linearized_id ON public.receipts_linearized USING btree (stream_id);


--
-- Name: receipts_linearized_room_stream; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX receipts_linearized_room_stream ON public.receipts_linearized USING btree (room_id, stream_id);


--
-- Name: receipts_linearized_unique_index; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX receipts_linearized_unique_index ON public.receipts_linearized USING btree (room_id, receipt_type, user_id) WHERE (thread_id IS NULL);


--
-- Name: receipts_linearized_user; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX receipts_linearized_user ON public.receipts_linearized USING btree (user_id);


--
-- Name: received_transactions_ts; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX received_transactions_ts ON public.received_transactions USING btree (ts);


--
-- Name: received_ts_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX received_ts_idx ON public.events USING btree (received_ts) WHERE (type = 'm.room.member'::text);


--
-- Name: redactions_have_censored_ts; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX redactions_have_censored_ts ON public.redactions USING btree (received_ts) WHERE (NOT have_censored);


--
-- Name: redactions_redacts; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX redactions_redacts ON public.redactions USING btree (redacts);


--
-- Name: refresh_tokens_next_token_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX refresh_tokens_next_token_id ON public.refresh_tokens USING btree (next_token_id) WHERE (next_token_id IS NOT NULL);


--
-- Name: remote_media_cache_sha256; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX remote_media_cache_sha256 ON public.remote_media_cache USING btree (sha256) WHERE (sha256 IS NOT NULL);


--
-- Name: remote_media_repository_thumbn_media_origin_id_width_height_met; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX remote_media_repository_thumbn_media_origin_id_width_height_met ON public.remote_media_cache_thumbnails USING btree (media_origin, media_id, thumbnail_width, thumbnail_height, thumbnail_type, thumbnail_method);


--
-- Name: room_account_data_room_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX room_account_data_room_id ON public.room_account_data USING btree (room_id);


--
-- Name: room_account_data_stream_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX room_account_data_stream_id ON public.room_account_data USING btree (user_id, stream_id);


--
-- Name: room_alias_servers_alias; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX room_alias_servers_alias ON public.room_alias_servers USING btree (room_alias);


--
-- Name: room_aliases_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX room_aliases_id ON public.room_aliases USING btree (room_id);


--
-- Name: room_membership_user_room_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX room_membership_user_room_idx ON public.room_memberships USING btree (user_id, room_id);


--
-- Name: room_memberships_room_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX room_memberships_room_id ON public.room_memberships USING btree (room_id);


--
-- Name: room_memberships_stream_ordering_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX room_memberships_stream_ordering_idx ON public.room_memberships USING btree (event_stream_ordering);


--
-- Name: room_memberships_user_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX room_memberships_user_id ON public.room_memberships USING btree (user_id);


--
-- Name: room_memberships_user_room_forgotten; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX room_memberships_user_room_forgotten ON public.room_memberships USING btree (user_id, room_id) WHERE (forgotten = 1);


--
-- Name: room_retention_max_lifetime_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX room_retention_max_lifetime_idx ON public.room_retention USING btree (max_lifetime);


--
-- Name: room_stats_earliest_token_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX room_stats_earliest_token_idx ON public.room_stats_earliest_token USING btree (room_id);


--
-- Name: room_stats_state_room; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX room_stats_state_room ON public.room_stats_state USING btree (room_id);


--
-- Name: scheduled_tasks_status; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX scheduled_tasks_status ON public.scheduled_tasks USING btree (status);


--
-- Name: scheduled_tasks_timestamp; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX scheduled_tasks_timestamp ON public.scheduled_tasks USING btree ("timestamp");


--
-- Name: sliding_sync_connection_lazy_members_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX sliding_sync_connection_lazy_members_idx ON public.sliding_sync_connection_lazy_members USING btree (connection_key, room_id, user_id);


--
-- Name: sliding_sync_connection_lazy_members_pos_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX sliding_sync_connection_lazy_members_pos_idx ON public.sliding_sync_connection_lazy_members USING btree (connection_key, connection_position) WHERE (connection_position IS NOT NULL);


--
-- Name: sliding_sync_connection_positions_key; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX sliding_sync_connection_positions_key ON public.sliding_sync_connection_positions USING btree (connection_key);


--
-- Name: sliding_sync_connection_positions_ts_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX sliding_sync_connection_positions_ts_idx ON public.sliding_sync_connection_positions USING btree (created_ts);


--
-- Name: sliding_sync_connection_required_state_conn_pos; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX sliding_sync_connection_required_state_conn_pos ON public.sliding_sync_connection_required_state USING btree (connection_key);


--
-- Name: sliding_sync_connection_room_configs_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX sliding_sync_connection_room_configs_idx ON public.sliding_sync_connection_room_configs USING btree (connection_position, room_id);


--
-- Name: sliding_sync_connection_room_configs_required_state_id_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX sliding_sync_connection_room_configs_required_state_id_idx ON public.sliding_sync_connection_room_configs USING btree (required_state_id);


--
-- Name: sliding_sync_connection_streams_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX sliding_sync_connection_streams_idx ON public.sliding_sync_connection_streams USING btree (connection_position, room_id, stream);


--
-- Name: sliding_sync_connections_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX sliding_sync_connections_idx ON public.sliding_sync_connections USING btree (user_id, effective_device_id, conn_id);


--
-- Name: sliding_sync_connections_ts_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX sliding_sync_connections_ts_idx ON public.sliding_sync_connections USING btree (created_ts);


--
-- Name: sliding_sync_joined_rooms_event_stream_ordering; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX sliding_sync_joined_rooms_event_stream_ordering ON public.sliding_sync_joined_rooms USING btree (event_stream_ordering);


--
-- Name: sliding_sync_membership_snapshots_event_stream_ordering; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX sliding_sync_membership_snapshots_event_stream_ordering ON public.sliding_sync_membership_snapshots USING btree (event_stream_ordering);


--
-- Name: sliding_sync_membership_snapshots_membership_event_id_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX sliding_sync_membership_snapshots_membership_event_id_idx ON public.sliding_sync_membership_snapshots USING btree (membership_event_id);


--
-- Name: sliding_sync_membership_snapshots_user_id_stream_ordering; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX sliding_sync_membership_snapshots_user_id_stream_ordering ON public.sliding_sync_membership_snapshots USING btree (user_id, event_stream_ordering);


--
-- Name: state_group_edges_prev_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX state_group_edges_prev_idx ON public.state_group_edges USING btree (prev_state_group);


--
-- Name: state_group_edges_unique_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX state_group_edges_unique_idx ON public.state_group_edges USING btree (state_group, prev_state_group);


--
-- Name: state_groups_pending_deletion_insertion_ts; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX state_groups_pending_deletion_insertion_ts ON public.state_groups_pending_deletion USING btree (insertion_ts);


--
-- Name: state_groups_pending_deletion_state_group; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX state_groups_pending_deletion_state_group ON public.state_groups_pending_deletion USING btree (state_group);


--
-- Name: state_groups_persisting_instance_name; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX state_groups_persisting_instance_name ON public.state_groups_persisting USING btree (instance_name);


--
-- Name: state_groups_room_id_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX state_groups_room_id_idx ON public.state_groups USING btree (room_id);


--
-- Name: state_groups_state_type_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX state_groups_state_type_idx ON public.state_groups_state USING btree (state_group, type, state_key);


--
-- Name: sticky_events_room_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX sticky_events_room_idx ON public.sticky_events USING btree (room_id, event_stream_ordering);


--
-- Name: stream_ordering_to_exterm_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX stream_ordering_to_exterm_idx ON public.stream_ordering_to_exterm USING btree (stream_ordering);


--
-- Name: stream_ordering_to_exterm_rm_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX stream_ordering_to_exterm_rm_idx ON public.stream_ordering_to_exterm USING btree (room_id, stream_ordering);


--
-- Name: stream_positions_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX stream_positions_idx ON public.stream_positions USING btree (stream_name, instance_name);


--
-- Name: thread_subscriptions_by_event; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX thread_subscriptions_by_event ON public.thread_subscriptions USING btree (event_id);


--
-- Name: thread_subscriptions_by_user; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX thread_subscriptions_by_user ON public.thread_subscriptions USING btree (user_id, stream_id);


--
-- Name: thread_subscriptions_user_room; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX thread_subscriptions_user_room ON public.thread_subscriptions USING btree (user_id, room_id);


--
-- Name: threads_ordering_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX threads_ordering_idx ON public.threads USING btree (room_id, topological_ordering, stream_ordering);


--
-- Name: threepid_guest_access_tokens_index; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX threepid_guest_access_tokens_index ON public.threepid_guest_access_tokens USING btree (medium, address);


--
-- Name: threepid_validation_token_session_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX threepid_validation_token_session_id ON public.threepid_validation_token USING btree (session_id);


--
-- Name: timeline_gaps_room_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX timeline_gaps_room_id ON public.timeline_gaps USING btree (room_id, stream_ordering);


--
-- Name: un_partial_stated_event_stream_room_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX un_partial_stated_event_stream_room_id ON public.un_partial_stated_event_stream USING btree (event_id);


--
-- Name: un_partial_stated_room_stream_room_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX un_partial_stated_room_stream_room_id ON public.un_partial_stated_room_stream USING btree (room_id);


--
-- Name: user_daily_visits_ts_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX user_daily_visits_ts_idx ON public.user_daily_visits USING btree ("timestamp");


--
-- Name: user_daily_visits_uts_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX user_daily_visits_uts_idx ON public.user_daily_visits USING btree (user_id, "timestamp");


--
-- Name: user_directory_room_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX user_directory_room_idx ON public.user_directory USING btree (room_id);


--
-- Name: user_directory_search_fts_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX user_directory_search_fts_idx ON public.user_directory_search USING gin (vector);


--
-- Name: user_directory_search_user_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX user_directory_search_user_idx ON public.user_directory_search USING btree (user_id);


--
-- Name: user_directory_stale_remote_users_next_try_by_server_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX user_directory_stale_remote_users_next_try_by_server_idx ON public.user_directory_stale_remote_users USING btree (user_server_name, next_try_at_ts);


--
-- Name: user_directory_stale_remote_users_next_try_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX user_directory_stale_remote_users_next_try_idx ON public.user_directory_stale_remote_users USING btree (next_try_at_ts, user_server_name);


--
-- Name: user_directory_user_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX user_directory_user_idx ON public.user_directory USING btree (user_id);


--
-- Name: user_external_ids_user_id_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX user_external_ids_user_id_idx ON public.user_external_ids USING btree (user_id);


--
-- Name: user_filters_unique; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX user_filters_unique ON public.user_filters USING btree (user_id, filter_id);


--
-- Name: user_ips_device_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX user_ips_device_id ON public.user_ips USING btree (user_id, device_id, last_seen);


--
-- Name: user_ips_last_seen; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX user_ips_last_seen ON public.user_ips USING btree (user_id, last_seen);


--
-- Name: user_ips_last_seen_only; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX user_ips_last_seen_only ON public.user_ips USING btree (last_seen);


--
-- Name: user_ips_user_token_ip_unique_index; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX user_ips_user_token_ip_unique_index ON public.user_ips USING btree (user_id, access_token, ip);


--
-- Name: user_reports_target_user_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX user_reports_target_user_id ON public.user_reports USING btree (target_user_id);


--
-- Name: user_reports_user_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX user_reports_user_id ON public.user_reports USING btree (user_id);


--
-- Name: user_signature_stream_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX user_signature_stream_idx ON public.user_signature_stream USING btree (stream_id);


--
-- Name: user_threepid_id_server_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX user_threepid_id_server_idx ON public.user_threepid_id_server USING btree (user_id, medium, address, id_server);


--
-- Name: user_threepids_medium_address; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX user_threepids_medium_address ON public.user_threepids USING btree (medium, address);


--
-- Name: user_threepids_user_id; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX user_threepids_user_id ON public.user_threepids USING btree (user_id);


--
-- Name: users_creation_ts; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX users_creation_ts ON public.users USING btree (creation_ts);


--
-- Name: users_have_local_media; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX users_have_local_media ON public.local_media_repository USING btree (user_id, created_ts);


--
-- Name: users_in_public_rooms_r_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX users_in_public_rooms_r_idx ON public.users_in_public_rooms USING btree (room_id);


--
-- Name: users_in_public_rooms_u_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX users_in_public_rooms_u_idx ON public.users_in_public_rooms USING btree (user_id, room_id);


--
-- Name: users_who_share_private_rooms_o_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX users_who_share_private_rooms_o_idx ON public.users_who_share_private_rooms USING btree (other_user_id);


--
-- Name: users_who_share_private_rooms_r_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE INDEX users_who_share_private_rooms_r_idx ON public.users_who_share_private_rooms USING btree (room_id);


--
-- Name: users_who_share_private_rooms_u_idx; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX users_who_share_private_rooms_u_idx ON public.users_who_share_private_rooms USING btree (user_id, other_user_id, room_id);


--
-- Name: worker_locks_key; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX worker_locks_key ON public.worker_locks USING btree (lock_name, lock_key);


--
-- Name: worker_read_write_locks_key; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX worker_read_write_locks_key ON public.worker_read_write_locks USING btree (lock_name, lock_key, token);


--
-- Name: worker_read_write_locks_mode_key; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX worker_read_write_locks_mode_key ON public.worker_read_write_locks_mode USING btree (lock_name, lock_key);


--
-- Name: worker_read_write_locks_mode_type; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX worker_read_write_locks_mode_type ON public.worker_read_write_locks_mode USING btree (lock_name, lock_key, write_lock);


--
-- Name: worker_read_write_locks_write; Type: INDEX; Schema: public; Owner: synapse
--

CREATE UNIQUE INDEX worker_read_write_locks_write ON public.worker_read_write_locks USING btree (lock_name, lock_key) WHERE write_lock;


--
-- Name: current_state_events check_event_stream_ordering; Type: TRIGGER; Schema: public; Owner: synapse
--

CREATE TRIGGER check_event_stream_ordering BEFORE INSERT OR UPDATE ON public.current_state_events FOR EACH ROW EXECUTE FUNCTION public.check_event_stream_ordering();


--
-- Name: local_current_membership check_event_stream_ordering; Type: TRIGGER; Schema: public; Owner: synapse
--

CREATE TRIGGER check_event_stream_ordering BEFORE INSERT OR UPDATE ON public.local_current_membership FOR EACH ROW EXECUTE FUNCTION public.check_event_stream_ordering();


--
-- Name: room_memberships check_event_stream_ordering; Type: TRIGGER; Schema: public; Owner: synapse
--

CREATE TRIGGER check_event_stream_ordering BEFORE INSERT OR UPDATE ON public.room_memberships FOR EACH ROW EXECUTE FUNCTION public.check_event_stream_ordering();


--
-- Name: partial_state_events check_partial_state_events; Type: TRIGGER; Schema: public; Owner: synapse
--

CREATE TRIGGER check_partial_state_events BEFORE INSERT OR UPDATE ON public.partial_state_events FOR EACH ROW EXECUTE FUNCTION public.check_partial_state_events();


--
-- Name: worker_read_write_locks delete_read_write_lock_parent_trigger; Type: TRIGGER; Schema: public; Owner: synapse
--

CREATE TRIGGER delete_read_write_lock_parent_trigger AFTER DELETE ON public.worker_read_write_locks FOR EACH ROW EXECUTE FUNCTION public.delete_read_write_lock_parent();


--
-- Name: worker_read_write_locks upsert_read_write_lock_parent_trigger; Type: TRIGGER; Schema: public; Owner: synapse
--

CREATE TRIGGER upsert_read_write_lock_parent_trigger BEFORE INSERT ON public.worker_read_write_locks FOR EACH ROW EXECUTE FUNCTION public.upsert_read_write_lock_parent();


--
-- Name: access_tokens access_tokens_refresh_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.access_tokens
    ADD CONSTRAINT access_tokens_refresh_token_id_fkey FOREIGN KEY (refresh_token_id) REFERENCES public.refresh_tokens(id) ON DELETE CASCADE;


--
-- Name: destination_rooms destination_rooms_destination_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.destination_rooms
    ADD CONSTRAINT destination_rooms_destination_fkey FOREIGN KEY (destination) REFERENCES public.destinations(destination);


--
-- Name: destination_rooms destination_rooms_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.destination_rooms
    ADD CONSTRAINT destination_rooms_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(room_id);


--
-- Name: event_edges event_edges_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.event_edges
    ADD CONSTRAINT event_edges_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(event_id);


--
-- Name: event_failed_pull_attempts event_failed_pull_attempts_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.event_failed_pull_attempts
    ADD CONSTRAINT event_failed_pull_attempts_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(room_id);


--
-- Name: event_forward_extremities event_forward_extremities_event_id; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.event_forward_extremities
    ADD CONSTRAINT event_forward_extremities_event_id FOREIGN KEY (event_id) REFERENCES public.events(event_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: current_state_events event_stream_ordering_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.current_state_events
    ADD CONSTRAINT event_stream_ordering_fkey FOREIGN KEY (event_stream_ordering) REFERENCES public.events(stream_ordering) NOT VALID;


--
-- Name: local_current_membership event_stream_ordering_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.local_current_membership
    ADD CONSTRAINT event_stream_ordering_fkey FOREIGN KEY (event_stream_ordering) REFERENCES public.events(stream_ordering) NOT VALID;


--
-- Name: room_memberships event_stream_ordering_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.room_memberships
    ADD CONSTRAINT event_stream_ordering_fkey FOREIGN KEY (event_stream_ordering) REFERENCES public.events(stream_ordering) NOT VALID;


--
-- Name: event_txn_id_device_id event_txn_id_device_id_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.event_txn_id_device_id
    ADD CONSTRAINT event_txn_id_device_id_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(event_id) ON DELETE CASCADE;


--
-- Name: event_txn_id_device_id event_txn_id_device_id_user_id_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.event_txn_id_device_id
    ADD CONSTRAINT event_txn_id_device_id_user_id_device_id_fkey FOREIGN KEY (user_id, device_id) REFERENCES public.devices(user_id, device_id) ON DELETE CASCADE;


--
-- Name: msc4242_state_dag_edges msc4242_state_dag_edges_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.msc4242_state_dag_edges
    ADD CONSTRAINT msc4242_state_dag_edges_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(event_id);


--
-- Name: msc4242_state_dag_edges msc4242_state_dag_edges_prev_state_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.msc4242_state_dag_edges
    ADD CONSTRAINT msc4242_state_dag_edges_prev_state_event_id_fkey FOREIGN KEY (prev_state_event_id) REFERENCES public.events(event_id);


--
-- Name: msc4242_state_dag_edges msc4242_state_dag_edges_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.msc4242_state_dag_edges
    ADD CONSTRAINT msc4242_state_dag_edges_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(room_id) ON DELETE CASCADE;


--
-- Name: msc4242_state_dag_forward_extremities msc4242_state_dag_forward_extremities_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.msc4242_state_dag_forward_extremities
    ADD CONSTRAINT msc4242_state_dag_forward_extremities_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(event_id) ON DELETE CASCADE;


--
-- Name: msc4242_state_dag_forward_extremities msc4242_state_dag_forward_extremities_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.msc4242_state_dag_forward_extremities
    ADD CONSTRAINT msc4242_state_dag_forward_extremities_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(room_id) ON DELETE CASCADE;


--
-- Name: partial_state_events partial_state_events_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.partial_state_events
    ADD CONSTRAINT partial_state_events_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(event_id);


--
-- Name: partial_state_events partial_state_events_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.partial_state_events
    ADD CONSTRAINT partial_state_events_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.partial_state_rooms(room_id);


--
-- Name: partial_state_rooms partial_state_rooms_join_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.partial_state_rooms
    ADD CONSTRAINT partial_state_rooms_join_event_id_fkey FOREIGN KEY (join_event_id) REFERENCES public.events(event_id);


--
-- Name: partial_state_rooms partial_state_rooms_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.partial_state_rooms
    ADD CONSTRAINT partial_state_rooms_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(room_id);


--
-- Name: partial_state_rooms_servers partial_state_rooms_servers_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.partial_state_rooms_servers
    ADD CONSTRAINT partial_state_rooms_servers_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.partial_state_rooms(room_id);


--
-- Name: per_user_experimental_features per_user_experimental_features_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.per_user_experimental_features
    ADD CONSTRAINT per_user_experimental_features_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(name);


--
-- Name: refresh_tokens refresh_tokens_next_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_next_token_id_fkey FOREIGN KEY (next_token_id) REFERENCES public.refresh_tokens(id) ON DELETE CASCADE;


--
-- Name: sliding_sync_connection_lazy_members sliding_sync_connection_lazy_members_connection_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_connection_lazy_members
    ADD CONSTRAINT sliding_sync_connection_lazy_members_connection_key_fkey FOREIGN KEY (connection_key) REFERENCES public.sliding_sync_connections(connection_key) ON DELETE CASCADE;


--
-- Name: sliding_sync_connection_lazy_members sliding_sync_connection_lazy_members_connection_position_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_connection_lazy_members
    ADD CONSTRAINT sliding_sync_connection_lazy_members_connection_position_fkey FOREIGN KEY (connection_position) REFERENCES public.sliding_sync_connection_positions(connection_position) ON DELETE CASCADE;


--
-- Name: sliding_sync_connection_positions sliding_sync_connection_positions_connection_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_connection_positions
    ADD CONSTRAINT sliding_sync_connection_positions_connection_key_fkey FOREIGN KEY (connection_key) REFERENCES public.sliding_sync_connections(connection_key) ON DELETE CASCADE;


--
-- Name: sliding_sync_connection_required_state sliding_sync_connection_required_state_connection_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_connection_required_state
    ADD CONSTRAINT sliding_sync_connection_required_state_connection_key_fkey FOREIGN KEY (connection_key) REFERENCES public.sliding_sync_connections(connection_key) ON DELETE CASCADE;


--
-- Name: sliding_sync_connection_room_configs sliding_sync_connection_room_configs_connection_position_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_connection_room_configs
    ADD CONSTRAINT sliding_sync_connection_room_configs_connection_position_fkey FOREIGN KEY (connection_position) REFERENCES public.sliding_sync_connection_positions(connection_position) ON DELETE CASCADE;


--
-- Name: sliding_sync_connection_room_configs sliding_sync_connection_room_configs_required_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_connection_room_configs
    ADD CONSTRAINT sliding_sync_connection_room_configs_required_state_id_fkey FOREIGN KEY (required_state_id) REFERENCES public.sliding_sync_connection_required_state(required_state_id);


--
-- Name: sliding_sync_connection_streams sliding_sync_connection_streams_connection_position_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_connection_streams
    ADD CONSTRAINT sliding_sync_connection_streams_connection_position_fkey FOREIGN KEY (connection_position) REFERENCES public.sliding_sync_connection_positions(connection_position) ON DELETE CASCADE;


--
-- Name: sliding_sync_joined_rooms sliding_sync_joined_rooms_event_stream_ordering_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_joined_rooms
    ADD CONSTRAINT sliding_sync_joined_rooms_event_stream_ordering_fkey FOREIGN KEY (event_stream_ordering) REFERENCES public.events(stream_ordering);


--
-- Name: sliding_sync_joined_rooms sliding_sync_joined_rooms_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_joined_rooms
    ADD CONSTRAINT sliding_sync_joined_rooms_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(room_id);


--
-- Name: sliding_sync_joined_rooms_to_recalculate sliding_sync_joined_rooms_to_recalculate_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_joined_rooms_to_recalculate
    ADD CONSTRAINT sliding_sync_joined_rooms_to_recalculate_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(room_id);


--
-- Name: sliding_sync_membership_snapshots sliding_sync_membership_snapshots_event_stream_ordering_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_membership_snapshots
    ADD CONSTRAINT sliding_sync_membership_snapshots_event_stream_ordering_fkey FOREIGN KEY (event_stream_ordering) REFERENCES public.events(stream_ordering);


--
-- Name: sliding_sync_membership_snapshots sliding_sync_membership_snapshots_membership_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_membership_snapshots
    ADD CONSTRAINT sliding_sync_membership_snapshots_membership_event_id_fkey FOREIGN KEY (membership_event_id) REFERENCES public.events(event_id);


--
-- Name: sliding_sync_membership_snapshots sliding_sync_membership_snapshots_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.sliding_sync_membership_snapshots
    ADD CONSTRAINT sliding_sync_membership_snapshots_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(room_id);


--
-- Name: thread_subscriptions thread_subscriptions_fk_events; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.thread_subscriptions
    ADD CONSTRAINT thread_subscriptions_fk_events FOREIGN KEY (event_id) REFERENCES public.events(event_id) ON DELETE CASCADE;


--
-- Name: thread_subscriptions thread_subscriptions_fk_rooms; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.thread_subscriptions
    ADD CONSTRAINT thread_subscriptions_fk_rooms FOREIGN KEY (room_id) REFERENCES public.rooms(room_id) ON DELETE CASCADE;


--
-- Name: thread_subscriptions thread_subscriptions_fk_users; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.thread_subscriptions
    ADD CONSTRAINT thread_subscriptions_fk_users FOREIGN KEY (user_id) REFERENCES public.users(name);


--
-- Name: ui_auth_sessions_credentials ui_auth_sessions_credentials_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.ui_auth_sessions_credentials
    ADD CONSTRAINT ui_auth_sessions_credentials_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.ui_auth_sessions(session_id);


--
-- Name: ui_auth_sessions_ips ui_auth_sessions_ips_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.ui_auth_sessions_ips
    ADD CONSTRAINT ui_auth_sessions_ips_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.ui_auth_sessions(session_id);


--
-- Name: un_partial_stated_event_stream un_partial_stated_event_stream_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.un_partial_stated_event_stream
    ADD CONSTRAINT un_partial_stated_event_stream_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(event_id) ON DELETE CASCADE;


--
-- Name: un_partial_stated_room_stream un_partial_stated_room_stream_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.un_partial_stated_room_stream
    ADD CONSTRAINT un_partial_stated_room_stream_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(room_id) ON DELETE CASCADE;


--
-- Name: users_to_send_full_presence_to users_to_send_full_presence_to_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.users_to_send_full_presence_to
    ADD CONSTRAINT users_to_send_full_presence_to_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(name);


--
-- Name: worker_read_write_locks worker_read_write_locks_lock_name_lock_key_write_lock_fkey; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.worker_read_write_locks
    ADD CONSTRAINT worker_read_write_locks_lock_name_lock_key_write_lock_fkey FOREIGN KEY (lock_name, lock_key, write_lock) REFERENCES public.worker_read_write_locks_mode(lock_name, lock_key, write_lock);


--
-- Name: worker_read_write_locks_mode worker_read_write_locks_mode_foreign; Type: FK CONSTRAINT; Schema: public; Owner: synapse
--

ALTER TABLE ONLY public.worker_read_write_locks_mode
    ADD CONSTRAINT worker_read_write_locks_mode_foreign FOREIGN KEY (lock_name, lock_key, token) REFERENCES public.worker_read_write_locks(lock_name, lock_key, token) DEFERRABLE INITIALLY DEFERRED;


--
-- PostgreSQL database dump complete
--

\unrestrict 19JJZLIzXbqtx6O47hXZE0Hm5fSH3yrcVZKuI6eTyj9jWvAcm3WAglsBRbggtup

