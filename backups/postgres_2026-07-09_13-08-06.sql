--
-- PostgreSQL database dump
--

\restrict 8DWfkbK7nSP9pL5BE5DDnorsbpF5S3MFIEnye6XgcZ7vpQL8kCUU94uhAEZ9dHh

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
4	@root:shikpooshaan.ir	KJUSUOQBZF	syt_cm9vdA_SQxPzQSRKhQCzOYASCqn_2qVp1V	\N	\N	1783580129713	\N	f
9	@brian:shikpooshaan.ir	UDYMGJCKJI	syt_YnJpYW4_lNBlgCEyckyGNpxzdkOE_4P8dq3	\N	\N	1783582359463	\N	f
11	@ali:shikpooshaan.ir	HEAPZNPWHZ	syt_YWxp_AGghIPypbChAgJXGANCH_0R1LjY	\N	\N	1783582816317	\N	f
3	@alextaylor:shikpooshaan.ir	HKTASTBOAS	syt_YWxleHRheWxvcg_kxBflEEVbQtDsWSfPzMj_0dzEQq	\N	\N	1783579305082	\N	t
8	@alextaylor:shikpooshaan.ir	UJHQSRLCJP	syt_YWxleHRheWxvcg_gKhXjovodtgFzQRVcQPc_07hlv8	\N	\N	1783581930733	\N	t
10	@alextaylor:shikpooshaan.ir	NBQWFWVCQE	syt_YWxleHRheWxvcg_XxMdgbFXDaYoWfheXumt_06005E	\N	\N	1783582639375	\N	t
12	@ali:shikpooshaan.ir	AOKSEIYZIB	syt_YWxp_iksAmmNrgJKCMhAvfZhn_02ul38	\N	\N	1783582881966	\N	t
\.


--
-- Data for Name: account_data; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.account_data (user_id, account_data_type, stream_id, content, instance_name) FROM stdin;
@alextaylor:shikpooshaan.ir	org.matrix.msc3890.local_notification_settings.HKTASTBOAS	3	{"is_silenced":false}	\N
@alextaylor:shikpooshaan.ir	m.secret_storage.key.UYImgtEr4WMaj6ijvCpftJCBpc7VIKr2	4	{"algorithm":"m.secret_storage.v1.aes-hmac-sha2","iv":"KSx1RoZEnK0VRiF/QgEsqQ==","mac":"EOJZT7hz9Vk9BsgQ9ysljzE0/Ys8juK2WdV5QJ6qbj8="}	\N
@alextaylor:shikpooshaan.ir	io.element.recovery	10	{"enabled":true}	\N
@alextaylor:shikpooshaan.ir	org.matrix.msc3890.local_notification_settings.UJHQSRLCJP	21	{"is_silenced":false}	\N
@alextaylor:shikpooshaan.ir	m.secret_storage.key.Xkd197cZe3jM28atSHRhcQrc4FNOLb8x	22	{"algorithm":"m.secret_storage.v1.aes-hmac-sha2","iv":"e/to2bIdYtIoWdITE2JyEA==","mac":"HIu+y44/ycSFdj06qxYa8llEiwYQqOeQ9/yPfVfP7ek="}	\N
@alextaylor:shikpooshaan.ir	m.secret_storage.default_key	23	{"key":"Xkd197cZe3jM28atSHRhcQrc4FNOLb8x"}	\N
@alextaylor:shikpooshaan.ir	m.cross_signing.master	24	{"encrypted":{"Xkd197cZe3jM28atSHRhcQrc4FNOLb8x":{"iv":"DCRjhXj8oLt3h2yqy1MT+w==","ciphertext":"+RI3ecJQUSO29cRG6NWV6r4EkwQ4zKhbh0M62kv8se+XxDcJacDgCbpN1g==","mac":"Lf/jgEvzO1AxwZmqAwoz40tA2zFOmJXgIF+JYV945lg="}}}	\N
@alextaylor:shikpooshaan.ir	m.cross_signing.user_signing	25	{"encrypted":{"Xkd197cZe3jM28atSHRhcQrc4FNOLb8x":{"iv":"qzFaspbudktVL6aJwH8ahw==","ciphertext":"/xH78I9FjyExCiubbMwZSJx3YhRDHTYUrP5wIBJeLDV63Cok7soFEUbcdQ==","mac":"AH5LnRuIRIpgNbUu6XM7rzUcAZXr/C7zgmWGPBvLUa0="}}}	\N
@alextaylor:shikpooshaan.ir	m.cross_signing.self_signing	26	{"encrypted":{"Xkd197cZe3jM28atSHRhcQrc4FNOLb8x":{"iv":"2Z4g1Q/sCL8AhWPyj/DUdg==","ciphertext":"oLv/RforZX32BPSADXsdYLVs9Njs9BJcLwihaiN3qozUOBfhPWpomZZd+Q==","mac":"+65OzsoPIwi70B6Lyl8uSMycs/btlN3W2vaqFxDBiRY="}}}	\N
@alextaylor:shikpooshaan.ir	m.megolm_backup.v1	27	{"encrypted":{"Xkd197cZe3jM28atSHRhcQrc4FNOLb8x":{"iv":"Rbn8wkK9XkNLS7/rLzC9Gg==","ciphertext":"leCUy9LH24SfHBxs5AuzLa4YuWDy4VCh6X/h9tqMLdFbraol6WXffcEQ2g==","mac":"uQbPq1Tks3FJyVPS8a0GXEe1LMEFIGmk1O7Mvc5jJBs="}}}	\N
@ali:shikpooshaan.ir	m.key_backup	39	{"enabled":true}	\N
@ali:shikpooshaan.ir	m.org.matrix.custom.backup_disabled	40	{"disabled":false}	\N
@alextaylor:shikpooshaan.ir	m.accepted_terms	44	{"accepted":["https://vector.im/identity-server-privacy-notice-1"]}	\N
@alextaylor:shikpooshaan.ir	im.vector.analytics	45	{"id":"9f85301679d4ddcfc6c9c1822985816","pseudonymousAnalyticsOptIn":false}	\N
@alextaylor:shikpooshaan.ir	im.vector.web.settings	47	{"releaseAnnouncementData":{"room_list_section":true},"Spaces.allRoomsInHome":true,"Spaces.enabledMetaSpaces":{"home-space":true,"orphans-space":true},"MessageComposerInput.insertTrailingColon":true,"showTwelveHourTimestamps":true,"alwaysShowTimestamps":true,"deviceClientInformationOptIn":true}	\N
@alextaylor:shikpooshaan.ir	io.element.matrix_client_information.UJHQSRLCJP	48	{"name":"Element","version":"1.12.23"}	\N
@alextaylor:shikpooshaan.ir	io.element.matrix_client_information.HKTASTBOAS	49	{"name":"ChatApp","version":"1.12.23","url":"chatapp.shikpooshaan.ir"}	\N
@ali:shikpooshaan.ir	m.direct	50	{"@alextaylor:shikpooshaan.ir":["!DDSQZabMGckQpzuTFl:shikpooshaan.ir"]}	\N
@alextaylor:shikpooshaan.ir	m.direct	52	{"@ali:shikpooshaan.ir":["!DDSQZabMGckQpzuTFl:shikpooshaan.ir"]}	\N
@alextaylor:shikpooshaan.ir	im.vector.setting.breadcrumbs	54	{"recent_rooms":["!DDSQZabMGckQpzuTFl:shikpooshaan.ir","!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir"]}	\N
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
2	master	user_last_seen_monthly_active	\N	1783576978661
3	master	get_monthly_active_count	{}	1783576978664
4	master	get_user_by_id	{@alextaylor:shikpooshaan.ir}	1783577190395
5	master	get_device	{@alextaylor:shikpooshaan.ir,WMVHAWVONL}	1783577190466
6	master	get_device	{@alextaylor:shikpooshaan.ir,HKTASTBOAS}	1783577557495
7	master	get_device	{@alextaylor:shikpooshaan.ir,HKTASTBOAS}	1783577576044
8	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,HKTASTBOAS}	1783577576094
9	master	get_e2e_unused_fallback_key_types	{@alextaylor:shikpooshaan.ir,HKTASTBOAS}	1783577576118
10	master	_get_bare_e2e_cross_signing_keys	{@alextaylor:shikpooshaan.ir}	1783577576414
11	master	_get_bare_e2e_cross_signing_keys	{@alextaylor:shikpooshaan.ir}	1783577576435
12	master	_get_bare_e2e_cross_signing_keys	{@alextaylor:shikpooshaan.ir}	1783577576458
13	master	_get_e2e_cross_signing_signatures_for_device	{"[\\"@alextaylor:shikpooshaan.ir\\", \\"HKTASTBOAS\\"]"}	1783577576629
14	master	user_last_seen_monthly_active	\N	1783577877433
15	master	get_monthly_active_count	{}	1783577877434
16	master	get_device	{@alextaylor:shikpooshaan.ir}	1783579305095
17	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir}	1783579305096
18	master	get_e2e_unused_fallback_key_types	{@alextaylor:shikpooshaan.ir}	1783579305097
19	master	get_user_by_access_token	{syt_YWxleHRheWxvcg_ZiGBtWTSLHIkgZMjmtRg_1peRGs}	1783579305122
20	master	cs_cache_fake	{!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir}	1783579928406
21	master	cs_cache_fake	{!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir,@alextaylor:shikpooshaan.ir}	1783579928619
22	master	cs_cache_fake	{!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir}	1783579929128
23	master	get_user_by_id	{@root:shikpooshaan.ir}	1783580129645
24	master	get_device	{@root:shikpooshaan.ir,KJUSUOQBZF}	1783580129684
25	master	get_device	{@alextaylor:shikpooshaan.ir,INWEZSCLYH}	1783580459195
26	master	get_device	{@alextaylor:shikpooshaan.ir,INWEZSCLYH}	1783580461057
27	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,INWEZSCLYH}	1783580461132
28	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,INWEZSCLYH}	1783580461733
29	master	get_e2e_unused_fallback_key_types	{@alextaylor:shikpooshaan.ir,INWEZSCLYH}	1783580461766
30	master	_get_e2e_cross_signing_signatures_for_device	{"[\\"@alextaylor:shikpooshaan.ir\\", \\"INWEZSCLYH\\"]"}	1783580544298
31	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,INWEZSCLYH}	1783580545368
32	master	get_if_user_has_pusher	{@alextaylor:shikpooshaan.ir}	1783580553213
33	master	cs_cache_fake	{!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir}	1783580573249
34	master	get_if_user_has_pusher	{@alextaylor:shikpooshaan.ir}	1783580796992
35	master	user_last_seen_monthly_active	\N	1783581393829
36	master	get_monthly_active_count	{}	1783581393832
37	master	get_user_by_id	{@testuser:shikpooshaan.ir}	1783581744612
38	master	get_device	{@testuser:shikpooshaan.ir,WCLMNVQCBU}	1783581744674
39	master	get_device	{@testuser:shikpooshaan.ir,LLRGRFFCEG}	1783581844695
40	master	get_device	{@testuser:shikpooshaan.ir,LLRGRFFCEG}	1783581845176
41	master	count_e2e_one_time_keys	{@testuser:shikpooshaan.ir,LLRGRFFCEG}	1783581845246
42	master	get_device	{@testuser:shikpooshaan.ir,LLRGRFFCEG}	1783581845295
43	master	count_e2e_one_time_keys	{@testuser:shikpooshaan.ir,LLRGRFFCEG}	1783581845371
44	master	count_e2e_one_time_keys	{@testuser:shikpooshaan.ir,LLRGRFFCEG}	1783581845446
45	master	get_e2e_unused_fallback_key_types	{@testuser:shikpooshaan.ir,LLRGRFFCEG}	1783581845470
46	master	_get_bare_e2e_cross_signing_keys	{@testuser:shikpooshaan.ir}	1783581845511
47	master	_get_bare_e2e_cross_signing_keys	{@testuser:shikpooshaan.ir}	1783581845531
48	master	_get_bare_e2e_cross_signing_keys	{@testuser:shikpooshaan.ir}	1783581845547
49	master	get_if_user_has_pusher	{@testuser:shikpooshaan.ir}	1783581851604
50	master	get_device	{@alextaylor:shikpooshaan.ir,UJHQSRLCJP}	1783581930697
51	master	get_device	{@alextaylor:shikpooshaan.ir,UJHQSRLCJP}	1783581939518
52	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,UJHQSRLCJP}	1783581939553
53	master	get_e2e_unused_fallback_key_types	{@alextaylor:shikpooshaan.ir,UJHQSRLCJP}	1783581939577
54	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,UJHQSRLCJP}	1783581942282
55	master	_get_e2e_cross_signing_signatures_for_device	{"[\\"@alextaylor:shikpooshaan.ir\\", \\"UJHQSRLCJP\\"]"}	1783582070202
56	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,UJHQSRLCJP}	1783582071321
57	master	cs_cache_fake	{!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir,@testuser:shikpooshaan.ir}	1783582212026
58	master	cs_cache_fake	{!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir,@testuser:shikpooshaan.ir}	1783582218946
59	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,UJHQSRLCJP}	1783582226201
60	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,INWEZSCLYH}	1783582226201
61	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,HKTASTBOAS}	1783582226201
62	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,HKTASTBOAS}	1783582227504
63	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,UJHQSRLCJP}	1783582230429
64	master	get_user_by_id	{@brian:shikpooshaan.ir}	1783582359369
65	master	get_device	{@brian:shikpooshaan.ir,UDYMGJCKJI}	1783582359408
66	master	get_if_user_has_pusher	{@testuser:shikpooshaan.ir}	1783582569709
89	master	cs_cache_fake	{!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir,@testuser:shikpooshaan.ir}	1783582590887
94	master	get_if_user_has_pusher	{@alextaylor:shikpooshaan.ir}	1783582639833
98	master	get_e2e_unused_fallback_key_types	{@alextaylor:shikpooshaan.ir,NBQWFWVCQE}	1783582640179
106	master	get_user_by_access_token	{syt_YWxleHRheWxvcg_LEthJJLigshrZihUhQVj_1ljIdP}	1783582834987
110	master	get_device	{@ali:shikpooshaan.ir,AOKSEIYZIB}	1783582882521
112	master	count_e2e_one_time_keys	{@ali:shikpooshaan.ir,AOKSEIYZIB}	1783582882702
117	master	get_e2e_unused_fallback_key_types	{@ali:shikpooshaan.ir,AOKSEIYZIB}	1783582882937
67	master	get_device	{@testuser:shikpooshaan.ir}	1783582590266
68	master	count_e2e_one_time_keys	{@testuser:shikpooshaan.ir}	1783582590268
69	master	get_e2e_unused_fallback_key_types	{@testuser:shikpooshaan.ir}	1783582590269
70	master	get_user_by_access_token	{syt_dGVzdHVzZXI_sNetgUVJYyqovfZkbLyA_1xNJ7c}	1783582590298
71	master	get_user_by_access_token	{syt_dGVzdHVzZXI_GLyMyObmyOPPHFSBCYcj_2EZTsJ}	1783582590298
75	master	is_user_erased	{@testuser:shikpooshaan.ir}	1783582590512
76	master	get_user_deactivated_status	{@testuser:shikpooshaan.ir}	1783582590538
77	master	get_user_by_id	{@testuser:shikpooshaan.ir}	1783582590540
78	master	is_guest	{@testuser:shikpooshaan.ir}	1783582590544
87	master	_get_event_cache	{$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM}	1783582590673
96	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,NBQWFWVCQE}	1783582639926
97	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,NBQWFWVCQE}	1783582640141
99	master	_get_e2e_cross_signing_signatures_for_device	{"[\\"@alextaylor:shikpooshaan.ir\\", \\"NBQWFWVCQE\\"]"}	1783582667611
100	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,NBQWFWVCQE}	1783582668710
115	master	_get_bare_e2e_cross_signing_keys	{@ali:shikpooshaan.ir}	1783582882768
72	master	get_if_user_has_pusher	{@testuser:shikpooshaan.ir}	1783582590321
108	master	get_device	{@ali:shikpooshaan.ir,AOKSEIYZIB}	1783582881953
111	master	count_e2e_one_time_keys	{@ali:shikpooshaan.ir,AOKSEIYZIB}	1783582882568
118	master	get_if_user_has_pusher	{@ali:shikpooshaan.ir}	1783582885837
73	master	get_user_by_id	{@testuser:shikpooshaan.ir}	1783582590417
74	master	get_if_user_has_pusher	{@testuser:shikpooshaan.ir}	1783582590465
79	master	get_account_data_for_room_and_type	{@testuser:shikpooshaan.ir}	1783582590568
80	master	get_global_account_data_for_user	{@testuser:shikpooshaan.ir}	1783582590570
81	master	get_room_account_data_for_user	{@testuser:shikpooshaan.ir}	1783582590570
82	master	get_global_account_data_by_type_for_user	{@testuser:shikpooshaan.ir}	1783582590571
83	master	get_account_data_for_room	{@testuser:shikpooshaan.ir}	1783582590572
84	master	get_push_rules_for_user	{@testuser:shikpooshaan.ir}	1783582590573
85	master	ignored_by	\N	1783582590574
86	master	get_subscription_for_thread	{@testuser:shikpooshaan.ir}	1783582590610
88	master	_get_event_cache	{$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8}	1783582590693
90	master	did_forget	{@testuser:shikpooshaan.ir,!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir}	1783582590986
91	master	get_forgotten_rooms_for_user	{@testuser:shikpooshaan.ir}	1783582590988
92	master	get_sliding_sync_rooms_for_user_from_membership_snapshots	{@testuser:shikpooshaan.ir}	1783582590998
93	master	get_device	{@alextaylor:shikpooshaan.ir,NBQWFWVCQE}	1783582639353
95	master	get_device	{@alextaylor:shikpooshaan.ir,NBQWFWVCQE}	1783582639830
101	master	get_user_by_id	{@ali:shikpooshaan.ir}	1783582816257
102	master	get_device	{@ali:shikpooshaan.ir,HEAPZNPWHZ}	1783582816289
103	master	get_device	{@alextaylor:shikpooshaan.ir}	1783582834960
104	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir}	1783582834961
105	master	get_e2e_unused_fallback_key_types	{@alextaylor:shikpooshaan.ir}	1783582834962
107	master	get_if_user_has_pusher	{@alextaylor:shikpooshaan.ir}	1783582835009
109	master	get_device	{@ali:shikpooshaan.ir,AOKSEIYZIB}	1783582882513
113	master	_get_bare_e2e_cross_signing_keys	{@ali:shikpooshaan.ir}	1783582882723
114	master	_get_bare_e2e_cross_signing_keys	{@ali:shikpooshaan.ir}	1783582882749
116	master	count_e2e_one_time_keys	{@ali:shikpooshaan.ir,AOKSEIYZIB}	1783582882916
119	master	cs_cache_fake	{!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir}	1783582978496
120	master	cs_cache_fake	{!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir}	1783583005148
121	master	get_aliases_for_room	{!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir}	1783583168545
122	master	cs_cache_fake	{!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir}	1783583169743
123	master	cs_cache_fake	{!DDSQZabMGckQpzuTFl:shikpooshaan.ir}	1783583512422
124	master	cs_cache_fake	{!DDSQZabMGckQpzuTFl:shikpooshaan.ir,@ali:shikpooshaan.ir}	1783583512616
125	master	cs_cache_fake	{!DDSQZabMGckQpzuTFl:shikpooshaan.ir}	1783583513047
126	master	cs_cache_fake	{!DDSQZabMGckQpzuTFl:shikpooshaan.ir,@alextaylor:shikpooshaan.ir}	1783583513318
127	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,UJHQSRLCJP}	1783583519633
128	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,NBQWFWVCQE}	1783583519633
129	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,HKTASTBOAS}	1783583519633
130	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,HKTASTBOAS}	1783583521051
131	master	cs_cache_fake	{!DDSQZabMGckQpzuTFl:shikpooshaan.ir,@alextaylor:shikpooshaan.ir}	1783583542287
132	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,HKTASTBOAS}	1783583561238
133	master	count_e2e_one_time_keys	{@alextaylor:shikpooshaan.ir,HKTASTBOAS}	1783583563461
134	master	user_last_seen_monthly_active	\N	1783584993545
135	master	get_monthly_active_count	{}	1783584993549
136	master	user_last_seen_monthly_active	\N	1783585152426
137	master	get_monthly_active_count	{}	1783585152433
138	master	user_last_seen_monthly_active	\N	1783585236531
139	master	get_monthly_active_count	{}	1783585236538
140	master	get_if_user_has_pusher	{@alextaylor:shikpooshaan.ir}	1783586101702
141	master	user_last_seen_monthly_active	\N	1783588836362
142	master	get_monthly_active_count	{}	1783588836364
\.


--
-- Data for Name: current_state_delta_stream; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.current_state_delta_stream (stream_id, room_id, type, state_key, event_id, prev_event_id, instance_name) FROM stdin;
2	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.create		$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	\N	master
3	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.member	@alextaylor:shikpooshaan.ir	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	\N	master
4	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.encryption		$aGYMEi1KO534ezshtH0n3_XRs3OZXgi_DY26XrWFLTE	\N	master
4	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.guest_access		$ovWXMhcqZ51rR0-mmT_ebzrZ3c9XWpr256lElWATA5g	\N	master
4	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.history_visibility		$4WW-qYRENg7ChGX-khhMVKLO2asWf8I7EKJWgnuEnMI	\N	master
4	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.join_rules		$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs	\N	master
4	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.name		$E97pMjZjzmrDM-hFyRwC6aqENPN3ixJigBn50-VhHEQ	\N	master
4	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.power_levels		$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	\N	master
10	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.avatar		$owPa_25ew4CsxHc1lZakZoynscO0PsDgfqWSWzt7GA0	\N	master
12	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.member	@testuser:shikpooshaan.ir	$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8	\N	master
13	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.member	@testuser:shikpooshaan.ir	$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM	$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8	master
15	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.member	@testuser:shikpooshaan.ir	$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4	$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM	master
18	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.power_levels		$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g	$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	master
19	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.history_visibility		$KSmWWmQkmzexNXwiaQhMG6Ec2JDmy7jmZgmlGyXySL8	$4WW-qYRENg7ChGX-khhMVKLO2asWf8I7EKJWgnuEnMI	master
20	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.canonical_alias		$B-bfbB05RV8t1MKB6YKPsn7xa-KawJRYs-lLGP2CEDI	\N	master
21	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.create		$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ	\N	master
22	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.member	@ali:shikpooshaan.ir	$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	\N	master
23	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.encryption		$AM_7A_tNjjaTM9klUn_6ZPT43TZaWkerNTyPWRr1wWA	\N	master
23	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.guest_access		$9bQLGiDMN6cfZTQFKMEwuFSUDUIkIAELgVXodLQCCgg	\N	master
23	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.history_visibility		$q11DmpDEFKgMjbP76SMow-33zfL47mOYIebpAXwj7Yo	\N	master
23	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.join_rules		$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs	\N	master
23	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.power_levels		$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY	\N	master
28	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.member	@alextaylor:shikpooshaan.ir	$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk	\N	master
31	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.member	@alextaylor:shikpooshaan.ir	$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE	$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk	master
\.


--
-- Data for Name: current_state_events; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.current_state_events (event_id, room_id, type, state_key, membership, event_stream_ordering) FROM stdin;
$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.create		\N	2
$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.member	@alextaylor:shikpooshaan.ir	join	3
$aGYMEi1KO534ezshtH0n3_XRs3OZXgi_DY26XrWFLTE	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.encryption		\N	7
$ovWXMhcqZ51rR0-mmT_ebzrZ3c9XWpr256lElWATA5g	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.guest_access		\N	6
$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.join_rules		\N	5
$E97pMjZjzmrDM-hFyRwC6aqENPN3ixJigBn50-VhHEQ	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.name		\N	9
$owPa_25ew4CsxHc1lZakZoynscO0PsDgfqWSWzt7GA0	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.avatar		\N	10
$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.member	@testuser:shikpooshaan.ir	leave	15
$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.power_levels		\N	18
$KSmWWmQkmzexNXwiaQhMG6Ec2JDmy7jmZgmlGyXySL8	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.history_visibility		\N	19
$B-bfbB05RV8t1MKB6YKPsn7xa-KawJRYs-lLGP2CEDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.canonical_alias		\N	20
$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.create		\N	21
$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.member	@ali:shikpooshaan.ir	join	22
$AM_7A_tNjjaTM9klUn_6ZPT43TZaWkerNTyPWRr1wWA	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.encryption		\N	26
$9bQLGiDMN6cfZTQFKMEwuFSUDUIkIAELgVXodLQCCgg	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.guest_access		\N	25
$q11DmpDEFKgMjbP76SMow-33zfL47mOYIebpAXwj7Yo	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.history_visibility		\N	27
$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.join_rules		\N	24
$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.power_levels		\N	23
$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.member	@alextaylor:shikpooshaan.ir	join	31
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
X	34
\.


--
-- Data for Name: deleted_pushers; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.deleted_pushers (stream_id, app_id, pushkey, user_id, instance_name) FROM stdin;
6	io.element.elementx.ios.prod	hKG6DZx7hrQU/9j+2YE7riMWj88do1jYLq/GZXRFu2M=	@testuser:shikpooshaan.ir	master
9	im.vector.app.android	cXRzOJQKSF-uUKfMghugq0	@alextaylor:shikpooshaan.ir	master
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
\.


--
-- Data for Name: device_lists_changes_converted_stream_position; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.device_lists_changes_converted_stream_position (lock, stream_id, room_id, instance_name) FROM stdin;
X	37		master
\.


--
-- Data for Name: device_lists_changes_in_room; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.device_lists_changes_in_room (user_id, device_id, room_id, stream_id, converted_to_destinations, opentracing_context, instance_name, inserted_ts) FROM stdin;
@alextaylor:shikpooshaan.ir	INWEZSCLYH	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	11	f	{}	master	1783580459208
@alextaylor:shikpooshaan.ir	INWEZSCLYH	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	12	f	{}	master	1783580461026
@alextaylor:shikpooshaan.ir	INWEZSCLYH	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	13	f	{}	master	1783580544311
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	21	f	{}	master	1783581930716
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	22	f	{}	master	1783581939493
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	23	f	{}	master	1783582070225
@testuser:shikpooshaan.ir	WCLMNVQCBU	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	25	f	{}	master	1783582590341
@testuser:shikpooshaan.ir	LLRGRFFCEG	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	26	f	{}	master	1783582590341
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	27	f	{}	master	1783582639365
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	28	f	{}	master	1783582639793
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	29	f	{}	master	1783582667629
@alextaylor:shikpooshaan.ir	INWEZSCLYH	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	31	f	{}	master	1783582835030
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
6	@alextaylor:shikpooshaan.ir	nL5wwk5HfbsXyutol/z72QntD9yOvMf5lZUHGm9J4fc	master
7	@alextaylor:shikpooshaan.ir	QEKDtp4sBqU318wcbel/r2C1PUgsOCTEdfkgxJE8Pfw	master
8	@alextaylor:shikpooshaan.ir	HKTASTBOAS	master
9	@alextaylor:shikpooshaan.ir	WMVHAWVONL	master
10	@root:shikpooshaan.ir	KJUSUOQBZF	master
19	@testuser:shikpooshaan.ir	L2xVW6+Lw2tqrM6ltDKI8uv6qvF5U9j7kdRyXhmKV6c	master
20	@testuser:shikpooshaan.ir	gHJS81vMOgwIZtAAnMvwIKyQMcl0Q/aiMEWL0m+JB8I	master
23	@alextaylor:shikpooshaan.ir	UJHQSRLCJP	master
24	@brian:shikpooshaan.ir	UDYMGJCKJI	master
25	@testuser:shikpooshaan.ir	WCLMNVQCBU	master
26	@testuser:shikpooshaan.ir	LLRGRFFCEG	master
29	@alextaylor:shikpooshaan.ir	NBQWFWVCQE	master
30	@ali:shikpooshaan.ir	HEAPZNPWHZ	master
31	@alextaylor:shikpooshaan.ir	INWEZSCLYH	master
34	@ali:shikpooshaan.ir	AOKSEIYZIB	master
36	@ali:shikpooshaan.ir	kh8e9XwuXd/lSLjW2mcxNNvEFvx3ritwu9GaHDHiw54	master
37	@ali:shikpooshaan.ir	9/b9uGVKUHxto5S9mgW3XwtGXJhohU7J1//3maDnp/4	master
\.


--
-- Data for Name: devices; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.devices (user_id, device_id, display_name, last_seen, ip, user_agent, hidden) FROM stdin;
@alextaylor:shikpooshaan.ir	nL5wwk5HfbsXyutol/z72QntD9yOvMf5lZUHGm9J4fc	master signing key	\N	\N	\N	t
@alextaylor:shikpooshaan.ir	QEKDtp4sBqU318wcbel/r2C1PUgsOCTEdfkgxJE8Pfw	self_signing signing key	\N	\N	\N	t
@alextaylor:shikpooshaan.ir	CfxK4aQke2AvtIR/+pW3ABSZZCjJOGAimv+4PHDnfA4	user_signing signing key	\N	\N	\N	t
@ali:shikpooshaan.ir	HEAPZNPWHZ	\N	\N	\N	\N	f
@testuser:shikpooshaan.ir	L2xVW6+Lw2tqrM6ltDKI8uv6qvF5U9j7kdRyXhmKV6c	master signing key	\N	\N	\N	t
@testuser:shikpooshaan.ir	gHJS81vMOgwIZtAAnMvwIKyQMcl0Q/aiMEWL0m+JB8I	self_signing signing key	\N	\N	\N	t
@testuser:shikpooshaan.ir	r4DNwSNf+A1felepD4odYpnEdIP4bUhOyO7S1rqP1ws	user_signing signing key	\N	\N	\N	t
@ali:shikpooshaan.ir	kh8e9XwuXd/lSLjW2mcxNNvEFvx3ritwu9GaHDHiw54	master signing key	\N	\N	\N	t
@ali:shikpooshaan.ir	9/b9uGVKUHxto5S9mgW3XwtGXJhohU7J1//3maDnp/4	self_signing signing key	\N	\N	\N	t
@ali:shikpooshaan.ir	+UPnSBrOVQ3TCYX/rh7HgomZIeoypiAXmCH2kcCQ2LI	user_signing signing key	\N	\N	\N	t
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	Element X iOS	1783587842303	94.24.18.95	Element X/26.06.1 (iPhone 14 Pro Max; iOS 26.5.2; Scale/3.00)	f
@ali:shikpooshaan.ir	AOKSEIYZIB	Element X Android	1783587851943	5.121.245.67	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)	f
@root:shikpooshaan.ir	KJUSUOQBZF	\N	\N	\N	\N	f
@brian:shikpooshaan.ir	UDYMGJCKJI	\N	\N	\N	\N	f
@alextaylor:shikpooshaan.ir	HKTASTBOAS	chatapp.shikpooshaan.ir: Chrome on Windows	1783589781593	217.28.137.165	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36	f
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	Element Desktop: Windows	1783589782085	217.28.137.165	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Element/1.12.23 Chrome/148.0.7778.265 Electron/42.4.1 Safari/537.36	f
\.


--
-- Data for Name: e2e_cross_signing_keys; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.e2e_cross_signing_keys (user_id, keytype, keydata, stream_id, updatable_without_uia_before_ms, instance_name) FROM stdin;
@alextaylor:shikpooshaan.ir	master	{"keys":{"ed25519:nL5wwk5HfbsXyutol/z72QntD9yOvMf5lZUHGm9J4fc":"nL5wwk5HfbsXyutol/z72QntD9yOvMf5lZUHGm9J4fc"},"signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"CfTRjF5shAVK2HSpBWOyguuB75asOQdgS+hN2wch1vpQ1hMiZf7mc/8tdMzHbxe6nsCvCxzBgmYGdHbraYfhDw","ed25519:nL5wwk5HfbsXyutol/z72QntD9yOvMf5lZUHGm9J4fc":"Z7irZEADO6cvfRRzpCF9VZB+hGibd/e51czpDaR0o4uOSE3mCuFwHH6AUB0sJtu6fchaieA0/w39+oJKZ4SvCA"}},"usage":["master"],"user_id":"@alextaylor:shikpooshaan.ir"}	2	\N	master
@alextaylor:shikpooshaan.ir	self_signing	{"keys":{"ed25519:QEKDtp4sBqU318wcbel/r2C1PUgsOCTEdfkgxJE8Pfw":"QEKDtp4sBqU318wcbel/r2C1PUgsOCTEdfkgxJE8Pfw"},"signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:nL5wwk5HfbsXyutol/z72QntD9yOvMf5lZUHGm9J4fc":"+h+M/C5TQK1Zss9I63eQSAQkbpeV0Wnkkhf/WcRCFXMsHxh8kS5hikx/6mW8dhQfwX++7sz3d8nbAq6uE3S2DQ"}},"usage":["self_signing"],"user_id":"@alextaylor:shikpooshaan.ir"}	3	\N	master
@alextaylor:shikpooshaan.ir	user_signing	{"keys":{"ed25519:CfxK4aQke2AvtIR/+pW3ABSZZCjJOGAimv+4PHDnfA4":"CfxK4aQke2AvtIR/+pW3ABSZZCjJOGAimv+4PHDnfA4"},"signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:nL5wwk5HfbsXyutol/z72QntD9yOvMf5lZUHGm9J4fc":"kVuPjA6iR4f5AOAady6ck9Qii179HBRazr7P7QY2YE9vspSrhy89biuAPhdbsp6Al0GGh55M02aMu1WKYfuODw"}},"usage":["user_signing"],"user_id":"@alextaylor:shikpooshaan.ir"}	4	\N	master
@testuser:shikpooshaan.ir	master	{"user_id":"@testuser:shikpooshaan.ir","usage":["master"],"keys":{"ed25519:L2xVW6+Lw2tqrM6ltDKI8uv6qvF5U9j7kdRyXhmKV6c":"L2xVW6+Lw2tqrM6ltDKI8uv6qvF5U9j7kdRyXhmKV6c"},"signatures":{"@testuser:shikpooshaan.ir":{"ed25519:L2xVW6+Lw2tqrM6ltDKI8uv6qvF5U9j7kdRyXhmKV6c":"t5Yt8JqOJIXX5T2DMBsxUWe3FZ7si8eVKYIglQCvDsdap7LXgaNWAZ3SRDUxoP4CBrIApJ4GfHUKzladbfZICg","ed25519:LLRGRFFCEG":"j7v380Co8OcK3ep65M5jPRfVsz401rsrhQdo/8TzFjkKrTlZVN8L4OEYfXXp9GXCSbjvhMaweL8vhui22mtjCw"}}}	5	\N	master
@testuser:shikpooshaan.ir	self_signing	{"user_id":"@testuser:shikpooshaan.ir","usage":["self_signing"],"keys":{"ed25519:gHJS81vMOgwIZtAAnMvwIKyQMcl0Q/aiMEWL0m+JB8I":"gHJS81vMOgwIZtAAnMvwIKyQMcl0Q/aiMEWL0m+JB8I"},"signatures":{"@testuser:shikpooshaan.ir":{"ed25519:L2xVW6+Lw2tqrM6ltDKI8uv6qvF5U9j7kdRyXhmKV6c":"Glvz3meA2ScGyyx6KpgA0Vs7+aJGqOK4MQxQvR+0OWmSFaLQYHN4ZZVEnDj5kET9h1kJPID7AWIi5qSX/D0TDA"}}}	6	\N	master
@testuser:shikpooshaan.ir	user_signing	{"user_id":"@testuser:shikpooshaan.ir","usage":["user_signing"],"keys":{"ed25519:r4DNwSNf+A1felepD4odYpnEdIP4bUhOyO7S1rqP1ws":"r4DNwSNf+A1felepD4odYpnEdIP4bUhOyO7S1rqP1ws"},"signatures":{"@testuser:shikpooshaan.ir":{"ed25519:L2xVW6+Lw2tqrM6ltDKI8uv6qvF5U9j7kdRyXhmKV6c":"MmgPrIx5OKZPOZftHy0ZtpfmDJ8Rb3NJOliOdBBjeqb8q65niW90ZozVhZUUZDd5TFiGJKNyQqtlQMWLq6T5AA"}}}	7	\N	master
@ali:shikpooshaan.ir	master	{"user_id":"@ali:shikpooshaan.ir","usage":["master"],"keys":{"ed25519:kh8e9XwuXd/lSLjW2mcxNNvEFvx3ritwu9GaHDHiw54":"kh8e9XwuXd/lSLjW2mcxNNvEFvx3ritwu9GaHDHiw54"},"signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"9RgZyOjZ2L9yl6lA8e23SJU9gEBZqAHHnkID828xwrFGZ+40i1CmezsTVCNvBBEN2YTc+XxGu7FULHXlXaTZDw","ed25519:kh8e9XwuXd/lSLjW2mcxNNvEFvx3ritwu9GaHDHiw54":"4LG1TQTAp2mrTjrR5kIp0po8c1SIZqAb5i0fpT9UrvbZ0Auu1cr3s2Znzj/s7PijJT8fGrs9WpUpDjl2GBkkCw"}}}	8	\N	master
@ali:shikpooshaan.ir	self_signing	{"user_id":"@ali:shikpooshaan.ir","usage":["self_signing"],"keys":{"ed25519:9/b9uGVKUHxto5S9mgW3XwtGXJhohU7J1//3maDnp/4":"9/b9uGVKUHxto5S9mgW3XwtGXJhohU7J1//3maDnp/4"},"signatures":{"@ali:shikpooshaan.ir":{"ed25519:kh8e9XwuXd/lSLjW2mcxNNvEFvx3ritwu9GaHDHiw54":"uiRjax875+tRDEMVQtajCfba2uD6FbOaKaVUDaf/e7zUdTHHSSn9x5kwj3kh0k0quJlRdZOT4yYZcXsYtxtRBw"}}}	9	\N	master
@ali:shikpooshaan.ir	user_signing	{"user_id":"@ali:shikpooshaan.ir","usage":["user_signing"],"keys":{"ed25519:+UPnSBrOVQ3TCYX/rh7HgomZIeoypiAXmCH2kcCQ2LI":"+UPnSBrOVQ3TCYX/rh7HgomZIeoypiAXmCH2kcCQ2LI"},"signatures":{"@ali:shikpooshaan.ir":{"ed25519:kh8e9XwuXd/lSLjW2mcxNNvEFvx3ritwu9GaHDHiw54":"xPucsMmmjf1YQ3JU0AOBZUO8c54sBiIrPNNsRwgiU0aUNqk6N5AU5dgjzzvt0fepFSnbdJVEPZ24orhAuSlKCw"}}}	10	\N	master
\.


--
-- Data for Name: e2e_cross_signing_signatures; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.e2e_cross_signing_signatures (user_id, key_id, target_user_id, target_device_id, signature) FROM stdin;
@alextaylor:shikpooshaan.ir	ed25519:QEKDtp4sBqU318wcbel/r2C1PUgsOCTEdfkgxJE8Pfw	@alextaylor:shikpooshaan.ir	HKTASTBOAS	jtiZeLyKtIXl80HXsakMrEeeuZE7CWECklHp+HruUEltX/uPEVH+kRmB+JC9m8Nw8h51vkrdmH8j+ZhVoG0BBg
@alextaylor:shikpooshaan.ir	ed25519:QEKDtp4sBqU318wcbel/r2C1PUgsOCTEdfkgxJE8Pfw	@alextaylor:shikpooshaan.ir	INWEZSCLYH	smMa+P6fGkEoZJFxaUwWTGtuLDc1d02NdnzZ8Nc5yuEvFF5/8QSTUSPNXzGZihRvMb2E3NBULVfUGKiIUhHiDg
@alextaylor:shikpooshaan.ir	ed25519:QEKDtp4sBqU318wcbel/r2C1PUgsOCTEdfkgxJE8Pfw	@alextaylor:shikpooshaan.ir	UJHQSRLCJP	8zrSnxC2iPz5McTGl0OuFN0PaCRQBgaRx/s8AVFtqWzaQimM/tR3SOFjGWXwtYYZwTBZvnNBIijKrCxF9pX4AQ
@alextaylor:shikpooshaan.ir	ed25519:QEKDtp4sBqU318wcbel/r2C1PUgsOCTEdfkgxJE8Pfw	@alextaylor:shikpooshaan.ir	NBQWFWVCQE	+dnINczq3ZYcukvDJQX0hqSEjnsHauEell7f1P3DBemWq0F1i45FzVSa67zEomcf7Gqky22a6/ZWij5dzaArDw
\.


--
-- Data for Name: e2e_device_keys_json; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.e2e_device_keys_json (user_id, device_id, ts_added_ms, key_json) FROM stdin;
@alextaylor:shikpooshaan.ir	HKTASTBOAS	1783577575996	{"algorithms":["m.olm.v1.curve25519-aes-sha2","m.megolm.v1.aes-sha2"],"device_id":"HKTASTBOAS","keys":{"curve25519:HKTASTBOAS":"Uxo6uTPAU860PksP3asarZYgVw6fV7iEP7nhwRw4PSg","ed25519:HKTASTBOAS":"MfgX/3UkAQ6aP4Z1d/oqtIn/yzO3hFGtwVx3rCfwz8o"},"signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"CVt2G8zTiQyTcCpw6lJyrc/56UKul/Vb2RWCHMOof8uVwHowWv9hMWcCxAZkVtNSfrQRNs2ebEH9xpIyl8cKBw"}},"user_id":"@alextaylor:shikpooshaan.ir"}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	1783581939482	{"algorithms":["m.olm.v1.curve25519-aes-sha2","m.megolm.v1.aes-sha2"],"device_id":"UJHQSRLCJP","keys":{"curve25519:UJHQSRLCJP":"mYzAqV4lK8izq6OTGGmzHUfUFdKi0of0TM4A/zbTpXc","ed25519:UJHQSRLCJP":"yFvptaU4YhkazZwbGU6W3eFMSAWOVrQSzTAMGWGxzlc"},"signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"1hGuyNHdf95GSvNUCOueqBV0v3gP74A0zCRLd9k0fM2lm6S7+dCI0bguaaIQMKF11NHCoC1+kF9S8QpBVTVVDQ"}},"user_id":"@alextaylor:shikpooshaan.ir"}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	1783582639746	{"algorithms":["m.olm.v1.curve25519-aes-sha2","m.megolm.v1.aes-sha2"],"device_id":"NBQWFWVCQE","keys":{"curve25519:NBQWFWVCQE":"FqkUPuFBGiNuuQlQRp5UN0zXzxp3hhSXx56iLoCFjWI","ed25519:NBQWFWVCQE":"bVbos18owRAIByF3wbKt9VyxIp8K7vr86XU1jNsVho4"},"signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"kx6iSPGqDsubpp+JbRaxUtqo4vdMCaieNaezF3VaEyN96yaDquXRqaOGDVoytLRZfzyHR68e08/0+SvF6NDjAg"}},"user_id":"@alextaylor:shikpooshaan.ir"}
@ali:shikpooshaan.ir	AOKSEIYZIB	1783582882483	{"algorithms":["m.olm.v1.curve25519-aes-sha2","m.megolm.v1.aes-sha2"],"device_id":"AOKSEIYZIB","keys":{"curve25519:AOKSEIYZIB":"NmM23XC1ZN1NdS7/0ZURWKQxnm9t7xaKYzKUnQ17nlc","ed25519:AOKSEIYZIB":"mj8R2qaucMkplYjZztecnjBLvVKw1KuevsQyx5wG+zQ"},"signatures":{"@ali:shikpooshaan.ir":{"ed25519:9/b9uGVKUHxto5S9mgW3XwtGXJhohU7J1//3maDnp/4":"ucc+yjLOIo44cswJ6uZkE+ue1TQZ/6TqFP6DAAC7vau/NyPE2jcCxYPmsgJPBpO1rThdvWwYMGbTsCW5hUhjBQ","ed25519:AOKSEIYZIB":"PqBj1z/XeJB6OrUm7qOIYsuFmS5ZWYlvnrDtFY73A8eWRk6ZQC3tQhNRbXNMaClvoHIx+hg8K9/oukoKJEmVCw"}},"user_id":"@ali:shikpooshaan.ir"}
\.


--
-- Data for Name: e2e_fallback_keys_json; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.e2e_fallback_keys_json (user_id, device_id, algorithm, key_id, key_json, used) FROM stdin;
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAAA	{"fallback":true,"key":"iAgv6HLfU4rz5t9Z1NRASaH3d0Pgyy+lyQC20/VjpFw","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"wd9DUNK0HpwYRbAOn/5Q+RykZfmIpcdYEjN6H/EQKg9UHvJTZyqDiS+iQe10uUQYELlQXsltSL8Um07HeacVCg"}}}	f
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAAA	{"fallback":true,"key":"MrYAIXeZszFNBP75zVSfzM9NpF6L0KhGaGk5nygOwmE","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"FIAFZmYnvOlby2cB6HddNPzrFnQcZvEV6vCZ6hew79PHXUG+aSO4GExLgn7P2I/m8l26UNrCyWde1CEk/lS9Dg"}}}	f
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAAA	{"key":"ksxRtcHNShY1BEw/MvP0iiO+C75KFGq8wkCdg0kL/38","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"+o2+n4T0o1qs5NtclGAmzCh1oFJhV67Njrf5E2p20l3cQFgIeOOvpcXj6NRJlgIuOe0IBl+wHNq69lyoTcyRBQ"}},"fallback":true}	f
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAAA	{"key":"frjc2TDnR9uzXlq2AWCFlC0o1nT1roY2OH4Mlu9E52w","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"w7sHArKSbzbhdPEeWzakmfd8HbZG6FzJl9AFBtuyuwehfxhoBSpGItkKRtsk9ni4o2OXaNj5ZE6rga5g6rAYDg"}},"fallback":true}	f
\.


--
-- Data for Name: e2e_one_time_keys_json; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.e2e_one_time_keys_json (user_id, device_id, algorithm, key_id, ts_added_ms, key_json) FROM stdin;
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAA0	1783582882483	{"key":"RTNUSlVkCfmAupnaxahoJeAXwYXVeRCO+xZgG45Tly4","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"Ux/PxCynMyouepnW/yTg8ni+tjBAkWDJoHu4Z18DGZOG0JVx/OaPgJ1PRkyYVOGi7D8bV6f0duX97ZI4qpEHCw"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAA4	1783577575996	{"key":"5x4MKf2nglnhUG57JhMjeww3CGJuWHpFdlXwpDN6G2w","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"uVzGkdM7CB6kjpVVDFztmZX+qcbyJxCl8uvMYj4Ztj2nsZlbkamfqtAmCrEidVbOhWz9kucjZuU/eX+GfCAgDQ"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAA8	1783577575996	{"key":"I583OrvvAR8BWWovCYoIVeSX1lIkTGCN4GXWli9DEDc","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"MJS2P9eEReCcZjMqEhl5pc+RARDENC9ZNVCKfAzTC+KnyuHjvS4z/2uAP4ePzdilel/+SJjhS/fghr7YARk4AA"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAAA	1783577575996	{"key":"sMw8RZkCrWFHb54w2Y0Qe/SYrRxGif4tGTnHyG5b3Ck","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"E7GSWIMwncHliUiQuCBB8PvyHLYcuHHj8Dmx0a3GLEWsIq7v/LXsazdpXvFBDayb6O24esBqpZ+1yy34NH+cBw"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAAE	1783577575996	{"key":"LIEyrYjWE4exkuctf1J2tmkQUXrkwAmMk4kIgTD4uyI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"NI+cx1pASOOsFimefGXRNHGWrzm1pkRka1l0N5V+pXjMulog70SkawzYVSkRf/e+Cn6exNUtld0PqW+F0sYOAQ"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAAI	1783577575996	{"key":"4RfPlLdq7SF9si0Df9shVqwXnTTTEqbNPT1TIqNwphc","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"yhLdrnrZ4uPg4MnftXVDppdete5wDB1tZeUdj1nROSt6wHtHylQ4R7uxzBWVwqZ4GalpikUZYbJPP+gbHhlUCg"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAAM	1783577575996	{"key":"c54UDUPOyDc3vxD/FcK5LhZWV8Q31nrIdAliaUYwhQs","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"voH+6wwQgl5tFQ8Rqu9Y+KktMt+kAPMtoWoQSPjcEGkQy4Ilbuw3T1wVMuCrOMgUwlYE7bmnq1EFnFhh/wPjAQ"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAAQ	1783577575996	{"key":"xmJVb+tTMJCE2bHsyBZS5/Om4/ywCq+j5lNXrAaKH3A","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"qA3/0JGAtnq3mjDev6cNLvFv8y9UcooMJ8qndsSD1yopd9Kozk20YMVo81iG40Sl9HUqZIwjXMPeG3ChlMe7AQ"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAAU	1783577575996	{"key":"iWhXgwfEXIPJZgpAVoLg10XiT5iYUt7NdkZx+3IgVCA","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"U24Ln4YVavmCj7FknBhIMl8fA848wDohb/AiqTECGP5EOKiue5MkcLi887peLwkAZBna2C0rlWITVP7peKt8Dg"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAAY	1783577575996	{"key":"SEjSSxVrXT1d15i6AL/5OYu84HYR5XaSwAjjpItbSUo","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"oJOqvMHCTh7QGEGRdTvkJ7326JpI8H7qFO6uuA0tXbVvpDqF5NArvBgnIzY+RlibRqrXC/IUBp6P4Qbheg1eAA"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAAc	1783577575996	{"key":"JQh6kiHXdhuveAsYovmz+PPEGdQ5Mp00rfujKGWG4n8","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"WvJ8+osBZXxMzg2aztFEX3mkcjWhDTC+b6I5o2oF2uetzfg+BOMIneF3AKR50sBecwr2YGMEangRIT28plGcDw"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAAg	1783577575996	{"key":"ACa0qRtEwCE7N+xwpFczyxo2m61tDTNfQUvC/L1gFho","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"cJm4AjQ3UgczFcfpFbonKBeQNPUmDh6YJYCG+yt0N2J+vg7vA5+L1KCy2OBlaUM7ozzdD3GC2VBL1kIqBBpzBw"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAAk	1783577575996	{"key":"4iaAsGQYXBrifaxi8sdSY4amCrcMC4SFTlBMi107b2s","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"Mw6hdysjEXnBNXaQ66rbqkdFaE/S/ZRe0OE3Ea1dz+qqRVXXXTet4Vewq4n+Kc1ZcJOdw2iQaG7GSF0+2oj5Ag"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAAo	1783577575996	{"key":"EmlcmVMCwlYMjLlkySKallWeuBtQTSL2M3l3gGl5NVA","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"ac3KjICbNdbXDOD/mXZdDPmYV55e+RDOGpOaPTpWt7E5T3lzN9EkaNFuClk1CigBbzoXXqRDCiqKeYdHVfc5AA"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAAs	1783577575996	{"key":"E1BT+JPY4PYSJAvkvBgUDjPDfiMxoacPAs8xxPsa0WY","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"rGJbdl2w5Dw30WhKqHmbWiK00lgfGKaVExA9RW9ibSN+fCoNxhPh4Tp9Cv8wglH6CiyuAmSPXx68xqVuWHsqDw"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAAw	1783577575996	{"key":"OeF6lVMncS0lxKiFQF8+hOEYhg4gGrybSaBB5nQbsCI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"Ujd/ye0jbkf0H6GqWbHfFdnktg+pAd75PFEMAY0pBQf7rLYqVaTtq/pExubpSmkwc1kRkUoYfz50WDbPWEk9Ag"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAB0	1783577575996	{"key":"UgsyfKt38cKtOPOrJI1HRmmSP1gMGSF0RGN7kg16azg","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"k9Nzzf4/UdBFzUCAvw/GlXvxbGkQTdGXpPAuRklniNLFXgFTRGMA+g3wVIDN4mt5yJuCwJ+j2jGs5zKORmUnAg"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAB4	1783577575996	{"key":"V0UXknC5XGS4av8aqpEgcAW8Kam0b3Vgo6GUD9qjsz8","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"M5ryosNKDGEOMUWcPNswUuSY85poMQwO1UkIUBMeamSv0UN/Woe1B829dgltifjG9ad4wgVPiUSgRa8zRxukAg"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAB8	1783577575996	{"key":"BM3rNkpqBRADckD1bJA6r0vimvU6sIU7uVYXN3+xTCA","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"rVN8W/Gwq5Jp0Tf2SP34N70tkNa6gjkaQ+AsXLkzONJ6uyEM86DWt1t6m9O896EDCcGzrOobqxYrMCXxWxTHBw"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAABA	1783577575996	{"key":"680j7AG5ZULPpbPcqpeq8utF3w5LXSdYbDicD2VZmV4","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"aUU3l1f2ezZCatzFK/lJ5nsJGQItAWbuoPdW51czuGZE649jSw/PeEKSkUVkwaMUNGo1X3PhYak5FrLLnFN9Cw"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAABE	1783577575996	{"key":"/BBO6N7H0MDXtKWcRrx2g5f/Fo0ds+z7hysyk2J58xU","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"fD3jAoidDzNGVJorIVshl1ziCAVha20erbTlLe/E9zYYEpaoxhEJ5SJWr6Dbzfgxp067/PwCfUquK8NWX9iNAg"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAABI	1783577575996	{"key":"o7m46/ujSgPYYeUYp+jjeqQ7T4YNcdYxfKR0BaSIxQE","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"6jg9F2ReC/8sCgaUg+1SWslf4ADfI9DiWz2MB43KgD3enuB49tWKv0BppW6Wt+6GdDFyLmFZAKJ00XqS33ZBAw"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAABM	1783577575996	{"key":"U36/ME5VyQ5/dpq7THprHPpZDT8t9ijUQNRX2tqFngQ","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"NeQBTN+y36+lG7QuOXpo5RFqye62D7gCNvfDnFWJhUcKfDPbLR900wEP9FikK9O5bKPjBtABDh3IGfHaaYOLCg"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAABQ	1783577575996	{"key":"ipxzu/9Nwq3XPol8tXIZ52+CCyhHT2svWB0gDADjvnA","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"t3dfrz39jN2D1iIDM9+3Gu8O5pyVxtNrk37GxhiIul47TtDb15o+GU4lhgHfr1G6nZb83EEj8drhRoEV3xErDg"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAABU	1783577575996	{"key":"uckl7Jq8LEl7nr/BT8KJOax6nasIJiQnyF3i/MakNyY","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"Bn2+0VS0qywNlRUKH9Jw+imkf5aVDmXM7qoXF2Bnm9wCLnwVYdNMcVMjveBWNsbojTyOV4Yg2SchfMGdmcvfBQ"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAABc	1783577575996	{"key":"rrHcweLZOcNUGW5uh4mtKzoZaTqx9eIZ7FMvT4rLaUg","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"VshZSTVqrQSYiDtXe0lWn97TUntMh3g7YTgmAInFykUYGxcT3kzmiC2VM5dzTa2XEaGrX2Kc1rRYAe31gf18Ag"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAABg	1783577575996	{"key":"jffyeNmw6F+2HzH+UKDOhcYHbgFAI/cpX6ma0mg1qGQ","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"+5Vj8a6O5o5gWa1WlLrt/2ENzUYQzD4GUIzQ73pztirdrOXWGeMXTBEfnX2/pvRSBptHTLdJILyfBG5PtuO9Cg"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAABk	1783577575996	{"key":"/UdAj+1WE8VAnII4y4RMvyNGRdLwIX2VgPcLwdIhPCE","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"pXF2xz4XP+FnTFfbQQ0ln6iE91SLJX2XCGPYlsp5eu9XLm17vopZSKE7Umbqup43xeob1PwVVv+Phnop+ecVBw"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAABo	1783577575996	{"key":"zVu70NH38g3VJCr9M3qyG+B2y2buAz4eeeEtQRo/7E0","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"lbpQxsGFzMCvquuUZ18e7JS3FwianViaAY72Jf9sbw4IhJJX5q/ElQC3KNayTXJ9tYSSV+LQ0K7VBllK/ubkAQ"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAABs	1783577575996	{"key":"1m5V42CFbtEAikGEAoSCS7MoAMRf1UDjH26rkel3xhc","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"Q/vW87tS9IBlRGeldd6wctY7iUmEu/iMi+xROeolRIS+ZcPGCt2kpsnw7o93Mb5Ux4x5agZKCcI7wdkvs9d9CQ"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAABw	1783577575996	{"key":"r71eY1FHopiknEoBQAw3kN2FT5nijdlWjYsnPqaMoQ8","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"CPOgfdPzgcnfPhJ0KxV+hIpk7YsAA2sRp3rfAekGVlWpwZiY9JmHZxc3ikUmF6Nuden/HNV98sDtFJoKhor0Dw"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAC0	1783577575996	{"key":"D/w80ddpQbjIKGAhlUvhiKdpwUnbfpiTX2jfpxvvAws","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"rse0HilIxCa8GNFDGuocdywjlYC5wOEp3LmO2x/cOBHAICZD5yrfMJA5XzQCZywRSYN4PUiSHVtWUK5HlFE0Ag"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAC4	1783577575996	{"key":"Vy9sldL30jIr4LRiZte4D4qB2LGeLx+LBNxU6I3hEXw","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"ALvdnQkw7hKDNS1sxssjRYhehPX4xp58KEtYTZ9F7HkzwOXDwd7zfFYUblhaWcRpR0DOgeTQcKyG17iQo2oEAQ"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAAC8	1783577575996	{"key":"jsNQHZd0+H1bJitGQY3ZAwuyRK2/7ugTcH9k3aUG42w","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"2IfDucEyclxSs7YHHzY+W+gWuf9p54Rppcj21ja+G9xUnwfyF6nvNkDP4cn7JRaYOQGxS7qZ2qXUR03LxyIYAA"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAACA	1783577575996	{"key":"1KPe0MMDhbpY7T4G4kZ1VWKqlfAo5j6cHaIjNB3SQVI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"BcZzPDnGBtEWIUfdf30wDhC2y/FIapyO9aM8jga05OjiGXJfcgrBmSpoPFZRkGW09C+UoY4BXO5iL6kNPdC+CA"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAACE	1783577575996	{"key":"szjqWA2weZeZ/S2XTN6HhvslTF0AzFjg43GkwHoPnwI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"G3Wu21ieiM6daCk9GxSj/PFG4SYBaJ5Q+CSg/ZAxiZ4+i7yHm9JOOWosIeetAU4aZetDHX0kcZWSyr/Xb4AvDA"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAACI	1783577575996	{"key":"pKN2LK81HhSwmwAKzkLuh9Qh3ug/EYvcfevFDWNOPHU","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"jvmDKg74TKsVzvRrRe9y+UCFo7H2b/mrn9PIj8Ydi695Su9LnxcYDNTifrnFCILfXz94Orq31xSH7ZuP5I36Dg"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAACM	1783577575996	{"key":"UiJFFZySsdd3SNrub+SPKCQS/KSqvBwy850WP8BujUM","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"XKakyVttgreQtuWE03BbFQd8nTQm7AHwX1ciM2Q0IMbSySyWXtY4Gh1+OvVAklkDX56VoQNTZC/HT+6ojUFdDA"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAACU	1783577575996	{"key":"3t/hTiwZF/1ZdAP7kK0KBq+pXFTyD/5Vm/x1hcoNiHI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"37G/2Oq//k4C3f2TWwDNCysNPupLdTSDxCuhg5icknd4/QSD8r4wQ/PVHcjpRjr2i30eoM2mHLsEqQPvx4WhCA"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAACY	1783577575996	{"key":"5qh2oHcXfUECgmJ2htI2TqKCLfthWSz86r2WElMVtAY","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"tpeqhXob7UQTIBpgcwlErSfRsNf3PAICh06t6qMIbBdzmE1dJZtBHI6/uofXUJluGQLLt0A1yJ95Zci/n8dWDA"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAACc	1783577575996	{"key":"6Wbm4y00q85Juemyd0G2FPnbM5pDeY+RK8NLGw+W7wA","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"Otm/jz2w+5WseSyoIj6r4gYBrIQbzUUDEwYafY2AWhsChTjg/si4Vl9mSKYWGEs+6UBM/O5hzjSpv/8y89rRCA"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAACg	1783577575996	{"key":"Da7Q4iJrTtdUq0zId356bcHCWSBFNYbBKxV4GxNVoQI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"lBgRqnbEx8AlwF/rxaidA1e1f4kRjrgF/+UKlTcyou+tInQEjDyqRDB7Z227AqmBh2JziLkJJQPFW8ie8UebBA"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAACk	1783577575996	{"key":"HqMaR039b7EA2SimPkazM2hd5DbiphACXd+wIVsH/xQ","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"SaWFESmYVp46vhyyVgp0beo0tEP13MMsgsWGeEaBUnPPx1Dtzl0dvvEMgUpAJO1Pdpo1WXEbfcMjvTCK5P0CAg"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAACo	1783577575996	{"key":"6zRx8tZ4siS3dUgbBttZxeOohBT+YsoDAUiVasTr91w","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"Yi2Gb4N/j3Y+I5bPJ7mv7h2yO5wfhduRXFbjYXRxq3BZSRdouYYkbqwg0Z3pVAsSPZmjrVL9Lw9+PtndFI5tCw"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAACs	1783577575996	{"key":"J9VrpNGXEmW1mo4dJfLyDsTYC2MAjiBHJkmIT0HYK2A","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"0AdcLe4G+9vl7NdKiZhpie9t0Xq+vF05XWQ9Rxd0MibrFuz/j37UtBH/rUohcUBCxMerpgEUC6JzVOkvEmyhDw"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAACw	1783577575996	{"key":"1HQyGJvYphm2coZSFfVD+9lGMXGb05fdnPWdDSK7Rxw","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"7efrJjygkR4BEromNGjnkjV1/AaM9+4ifMkHzklU6iot/Tyza3nCXOFb+IkrdAqldcTr01aLjksa+SGvsPmOBw"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAADA	1783577575996	{"key":"4Vz49nVxfjSPoZFP/T0g+7lvhx+KcC9O+xxkUKYyK18","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"W9UuPqLqBD0++LnXsqCKDYaspT/0EjbvmPg5gDzDnzn6yFZC5OMRxssv1Ydrph6IQGQms0iwqj1g853yQXiOAw"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAADE	1783577575996	{"key":"a5YJhOESKsNwJhPouhW37ydeao9YlUF/51wR3GfoiBo","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"QmqhjYONZJbLIjyzRN2FCLYsFFF55GWzoiff2iEEhTOoiRTk0jCBINNDApg8JucyvmGVbLVICKITRaOMcC8UBA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAA4	1783582882483	{"key":"UjVXyRRNapIIWdlO9vx8g6NOikIMxdjsU/QxNEEoml8","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"3Qm0HkhfsYgmvGwGwfXvoQqPgisKQzTldEQG1s0z0DfeDUcmzJ/NPaXKC0DE/58rilyMBqeVcTzw7Hoa0WHyCA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAA8	1783582882483	{"key":"nyEHI9KjYiluefnV4nTJHeiYJocuNt8FgPlfmM2/ZUE","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"2s6hEDnoR+q25ArD7PeAdgs0uKd4vcx3oeyXi9a6tjQV24mWZLdJ84hIrZz16CXkUhPgp7EltKBRAbBVJgUvCg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAAA	1783582882483	{"key":"X8JkKyHBJ320NkKVmbyT80jivF4KPHjdah6Af5fKY08","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"jYrTQUaFp2zI/v8gkOERPp4sgRm0DD5mruOulP77nY2pRWJ5g/y2S94XeUGnAhe4rRGyMaFn7dLHFyCuooZeCQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAAE	1783582882483	{"key":"yQ006AKo3uRDjZsxfXCJOk0YX7tZt4wt8Gcn/NUn5lo","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"YO/N4nYNRqs/GSv/GkyUoz9IwSG8apgLOZ7etPIuoMz1SNYngZ32HW3SVIhxAbfLU/nYsevJcZQUke1hmmBEDw"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAAI	1783582882483	{"key":"ZxRAScL7bDe4jUpAF/5juzTjGNergs3XNIdv54fMKxg","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"R0wYTAF0r1KwZHwaAtNyOzgJKcZ7YvGyNUYx9UwaT6FXPwrz27TWGNgYJNgts1O6Fbm9LhL0Wk6AEdKVCjb+Bg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAAM	1783582882483	{"key":"UbccjWUyvuqY/qjdoeSv95tyozKEbAkHofmGTbEwrmU","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"9Csx9GwiUpYYg3qrLQsxzxJMEd1EfaR8vGg8qCAjilhGPNZd5ldNUeNE/Qc2ovOWr2jvG0fCp3yuDCHTFBsoAA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAAQ	1783582882483	{"key":"miVg9aUeQ3RKGE5UK2CFj1Fdyv+rwUyieG4TOv8BrTc","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"OcaWzR+xHUqO109RcDAz9Sk9b6XeSXLni6SI5TsbkTgdxWWII9nkWkkdJdEm3TbqDb+LlrCKAHIfH7RAvPXjDA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAAU	1783582882483	{"key":"LtQhsQCfiZ/sc/KJktbACZNbf8iI02O3V6H1qmFsul0","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"4whNwzYvzYhOb2PqF6nk942b7ylR5dqV2cm5znyOaS1jVxIsj9gMvtO3A/myMZjQr4dBSebMGOFpwdgrTElFDA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAAY	1783582882483	{"key":"Ti9mDSsLtbRrWrec+pFTCAGrxs2XLLBoVnlGxmbetgw","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"aWo5XJEGq4WQDoj3z+kX/ZVdKLbpddZFbd1GpHnPh5QoB76fl0HtO6jiKAWIpCD2eo1MG+ljKIW4c8Knhz8gDQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAAc	1783582882483	{"key":"HvMnHOEImJtNvBDICtpdeQcwu4Wb1qYFtqL+xIoPD2c","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"Zm6uBaeFw7JWS2jz818K8XhdFRHt2/p0e4sROkBfyXEXj4maiOImxagG6/qmRYZZKfaguYII0QCUlRUEu9+RBg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAAg	1783582882483	{"key":"IhcXp4NB07xzjM0NE/TSiWhfp4YqUEuF72kKgMYCOBs","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"mCUgarMeB4j/jXFHbsE+2BfQnWAsjHjhKijK7Rx6xb01IU95oOQWMxKa2RejZitUyQbiRZQESzj7W5xib2OABA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAAk	1783582882483	{"key":"I+US25GqsCPtyaLBlwNy67eLOmYG+CVF5IW/R4QLo24","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"dw2EA+NGupUOjb+IuSuSzejLyFt/ACUthgxCmVVwzmS+JDA/jXOxEMmKCHdjvJkftOxVa2HI6OuYrZhrsXSeBw"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAAo	1783582882483	{"key":"DGAfkMcqkDAR0Fz67MyV05gzIIBWDtVGV3IBxtqB10c","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"nmJKHWjvXXclFPbECA6tuWk3ttLGQ2FGkL6+RAFue22lBzAbukxsL906lN/XsAF32/7NfwtXJcGpE1SWFr1hBg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAAs	1783582882483	{"key":"eOjglq+BEPkqorhElN0UqWlbx1V0zZz06jZ76x/K3CI","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"VCaZ7xeFAC/K63MnPMXU3h6fRefrWU6aoVAZI/vZOFiEV5bVm92zH19wu2euio0C8PnHgS8UPNtp/W20EkqVAA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAAw	1783582882483	{"key":"Q8sESepYlu3g5YwMBYnXY+hw5syKO17MkcsTvGTaT3E","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"S0UxNfspSCfzSMtrT9AUf6yr1z1yjFf2ZrdH+TTxiqABzibd7TTpHHqRcNS9o6E9ecWR/YMWJInkWaDZHIHrBA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAB0	1783582882483	{"key":"fB37EImcD6tKXPa3dvbFs/jNVGjf7tGQ/TDRzI5JUkU","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"/gFe5J89K0bLaF+nPvN37KW7twYZwfDy+LmNa1f94+7+LSAlgMTe60uRF0TpxjECZB0K+4uzmwQtJxH0hcYJAg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAB4	1783582882483	{"key":"Qsfb6X+bGQkq5xbLejOMvglUQam5/F7Caw4CzTSmqWo","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"ThS4gZxRsU/ekPV7p97/wi8xOPNvE/W7lLyCi+0PH9T0yu2/Dq3h1Hrsx9ND3bhw/CjIE9vapaqnOgpKscxNBw"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAB8	1783582882483	{"key":"GP+gxHjd7ym6h11uppA61vIjrYAqzelLdg2Ib+JJ7QE","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"UfuJsoBIcRd8GZf9aJ/IyfmfTrVCdC1y/hV4gHu6+Ys4fSCXEM4ahE1W24glsWEb761J7n+9f4Jg3VTXavaRCg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAABA	1783582882483	{"key":"zRT2A1m4872bhy0azgvEmtD/lD0vNnSc6qC6P87HDHY","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"auP0G9fvVc51/HtfpTq2OWYXfi3u0Lq5mcsTHMRow+yqVIqnswAWqXvSD41AiNDNVF2YteBLMW28+hc7O1+UBw"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAABE	1783582882483	{"key":"FkmRlwpIVzpad5dJeDvkE4Wu1w6bxBp82q46wdGbcjw","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"p3nr72I31eiqc498c1z/uxVOKkTLFGGbTlew1acWHA3e9n5Glf2MWxiHrbxh3/LTBA4X0IQVOUv9z+QfZPrjBw"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAABI	1783582882483	{"key":"MM2vwVRVLOgK1/P6ZosmDZMP5WUQRXEIGjPnxCWYNkk","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"snjdurGlVJ8V1cAW17ZhuSBe5mvmZ+4HSWdHFR91+JSEaFTMUjSMD2KS9YEMYf2Y+yNEHNQgzCazdZIhmrPSCA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAABM	1783582882483	{"key":"xHOJfUz+WNv/b8mFaxWjam96CZLpn6o4BbN5pGtUz24","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"3gERpYklO/YgbTlG7iC9PwC39eMK9+6apL7srHppuoEMN/vEbUIM2DUhM/UPkYnuNOjLpq4VwPQy6psZOPmmDQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAABQ	1783582882483	{"key":"Otnl6ULvPFNXEZ6aFYtttVf+FQYiqQEE+XkZ5c/9HTc","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"gylyxL9PnGco3wn9MzlVXLERWrWAaycBJniZoQ4yFjeR2e9k+egiVLz7NqDySa7KC1mDi3QHZlZ6oR6j6NQcCw"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAABU	1783582882483	{"key":"QSCqiQWyVGNBw5Y1K034OvoHTvKW26YelK8MbeXj/SQ","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"XAYhaOfVTVKI/JX3pjHWcLx0yXRXGsZAYBDCPfL1HemxSiFBv3R4WI1MG31Sp40vlNwIlBTbBvMqlQD32U9RCg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAABY	1783582882483	{"key":"sWE1BgWjIIP11uvWQcWhoXYKInYkSQV07R6u2qtqw0g","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"uan1dyxzjtfubFkexPWM84Ni2PF6u7W6hPba8ne3RGYeeS+X8sP2LEjjgsHhxTGB8zbeQaZdVzy9Ud5QVt/gAg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAABc	1783582882483	{"key":"BgLfyCI2tUvOiT6UaUz8ZEUMOWSSAlPuu/7VFVliDnE","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"SC3wQCJfE7kQLB7roHcFxnOl6Vg6q/5wnw4Zy8wTHRy9y1kf5hUKq8zludakEe6Q0ztSCs5jLw/usS2Blb/gAw"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAABg	1783582882483	{"key":"LW5ofQLCZWxLEBuRTCQEAsLKojVd09EW2iVUzGg/pBE","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"077SHYFGUTfTm9Ck0OAY2J+aPVNQL7zR6hoSdBM2sxH2HnuHeCZV8icahCIue+V8y3B8B26fiSuEi7Z/B6bgAw"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAABk	1783582882483	{"key":"w6cCUPc9lO6TlfH4um/H8R1EM9Qn5yL7dSeJfe1RFk4","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"X5MoN3d1N3sNlJB/ehNDeHyLV7O2qzM7yyx8agCckrVfN7NAGH42RbujpK2dAvAyygIclpfHj6vcQp1p370VCA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAABo	1783582882483	{"key":"e7tat67LE+j6SCFY4uirz4egB5dFNMqpBTXW3/5Xilw","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"0LKj3xUSrgH+WxpWT5aqUwhMp9yH+jbfTRX8j1W7ZCi7WIxZD6eqOW7a+hjlq+iiZoKtub83uqE4nIvOw0twAQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAABs	1783582882483	{"key":"js7Uo3K/OCgo5/xuEmtqfRb6U49T2gyrlnYuUcpsW2I","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"x7APDW4/LGIHs8BcdspDxvWAlLanu84P7xCuuXownYoGZv/fju9ZYGxTrs0C8Pm0HxddW6TQpSC9aNYEirhIAg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAABw	1783582882483	{"key":"AixC21gFNTjYZbetWYV3ijzo9SyCMCrqaLZdd+WjN3E","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"lzL3VHzQuzBiYsUZno+2R8YNHgomCKU8Mqx9fTG9PEHCBEt4ebEH4c3LEeIS0hDR4Z8h6BsupXKdPc71LoXcCQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAC0	1783582882483	{"key":"R+kYjGklvs1nGWWycxe3CYJaC+nem7yzYXgrztpLnzI","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"5Ac3QY97xvDzwDsYcdok/5Gzk3mQThjzNQMlj5FcSADkEfQOje9q9XSAgKmgAafnsrCPeErtvIixf5OQP3BrCQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAC4	1783582882483	{"key":"22kPRKJnbMEoHEzPpjBSbUqA9BvMTsijr4E8loDaxn4","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"S8c68Ll840VbywyKqedGIsCt1wbqY9GTlLeRtO/UDV+KIIgFgOXcL2nWVoA6Wbdech0lGqEfMGV0XiDTn3qSAg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAC8	1783582882483	{"key":"/8Qz0Y3gPc3qjS3aJ3M4j4Ep+OhQ64qAWttxiT0hNUg","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"saGYSdTaLGlNwQxWYdkfdoHi250XVB11gHlCEWJMMUN6mw4ubT5Sl4i6Dm2/v9600E5SxmGR4XZhGI12fz+/Cg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAACA	1783582882483	{"key":"kThRNnNVeH1VHoJCYgvH8abPiVqnTrdMeXgkx6MhpgY","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"uQIGW6wRlW7xOkBbvvWz8q71brQvdBwkGu8TP/pOW5qg9dR6lIv1ecv9JgiySWe4Qub1VsWMy0denryw5tPxBQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAACE	1783582882483	{"key":"s9Ia4qT8RQ+LDWmsqbMsFqbtxk053FwEh6astSciUFg","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"V6BIFBUsMsz/Zi6vuM7pexTfYjtQQc9E/Yhuh7XeMXMmEMSs9BcWjFvs9dh/0WKlMe7KTE1LLHq3MDNNDqt4BA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAACI	1783582882483	{"key":"TVHt1DRzLSjuX+7Bghytd2PZCKyq1T59cYEWkVySjmw","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"mRCGHVbW6wYvcARNsF9W8jfX1CSbrT3qM764nPUmQp874x6JmZa2JrDu1+x4Eu42Nnzu5Tbx9D5eR/vQoq75Dg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAACM	1783582882483	{"key":"qDuzv65ZRpVeLAiSc6o3NqM79xpPV43RGoULBtg4sRg","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"GlOF5XSuZ2seSFLeAePU1Ih+kq+MGm3XSsJmYU9qNXvDl4nxsmjGuYNU/ftvTQpCR61joCV26gYy5KoxdD8ZCA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAACQ	1783582882483	{"key":"fimyjakMzRBfYiQiEZaZzAIHr2r5ybqk8JAlHx+gVAU","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"Uhi5RJcwNoWPLTrva39JXj15JaUYLIxDI/ZMKprV+kQ3dOOQSIdsRcqXe3g4L6WQPz8WXHoSPnuTK4fyvx+VAg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAACU	1783582882483	{"key":"1wmSXsPQkl8YG8ALfAHDeDDlIy54kmBYEfSJaJvs9wU","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"TKMJqcvySUSDz+TEnf5ew0FdRBY0BtYfKyB+vcNgcqKCEk89eOla2PGl/O01UYo9uMIysX2TttEjM3EloLGhAg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAACY	1783582882483	{"key":"ytALi/VXSW2Pwole+IF797prFVQEjpLB7lkHc8wrzG8","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"UCw3RVfAEyumybQvRe5EO6B0Scr8G/VYhr2geIms5k9UiFw8sm4LUfbTTdzeRnmLlUutP90btiNOzAVgFSHCCg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAACc	1783582882483	{"key":"hycnzjlLktccXUmh6w8dCSGJ1ZMR2YA4AVZqpxdyBQA","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"eECmPWd2+Bs6bP5QaoaskMVW9caW/5C8voAoVYp/15b4VTTWf59tjF90zOxXRrrCkjUD4CF99Nq6lLI2x+5tAQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAACg	1783582882483	{"key":"p0zc/RdDE7V9WuVz66lZRetflRRzIkn5xgooxOStDnQ","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"w9TIMWOh2euYrqCW0047p30dNRZ5b/8eX5HrdyRNxXiGW4qQqVG4jkAU1JxLR/FAzsIYV635WmMxZfG+n/fECQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAACk	1783582882483	{"key":"TkBnY03sx49TFfQCjW86I728fhJSfn1ls8vvqIhdwWs","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"UfPQqp+0f98h5yWPhxbvzFk5dJXkHI9325OBiDKxGngi6Ykn65hCofAWkTIH8VbsFgXg0cceFatloGCahbRdDw"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAACo	1783582882483	{"key":"8Ky7VezwmpLdebzPwWEQQguOiJemDZHouAPtD84OVBs","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"A2fDkujRslde0gC/TCaJcGSQylUZ/fwqK9U47yojZfoHg2RE4TmuliXB/C24j1IkJdNg0/aE3RCBXuNuzb6/Ag"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAACs	1783582882483	{"key":"5roLM/bv89mTdJ08ETkG9GqfUtqTmUGz1c0aWjXt0UU","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"L2gztHKv/0iL6x0U66mgdCnSPe1mvDstB61QQyEwKGqZa2DGz2ULAtqrz/j9MgIddP3RyRCp0xZxWx8vKj86Ag"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAACw	1783582882483	{"key":"ZgCf9HRz/O6S3aaOjQB6e+j/Tuk12bqDdScJSLsIdyk","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"k4AzRvtwEq4WG4+iz9NrKsLw6HNTeDOV2RXnaV3TDDDfQkBR/9YiDgAvEwJ1EIXyW+2cMIJPu0PCO+H7nxQQBA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAADA	1783582882483	{"key":"cZcTpe8luhwtuffgbBoyhqVPq7HOwrd0NXJAGVVOMGA","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"QJoaBZ1fcqXuNABWeneGZuFDQyP8WBv73vb6LXpHtByhOyM9enYTaAiq9PdQpG8KGBDUezHYyVvS1UCka/dgBQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAADE	1783582882483	{"key":"09tU2YVmBC4kjjW8UEqvlBKM0cwYH7ogad8diZg8XV4","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"kWmmIhwuZWBzTK6DQtej83b/XUBU1aW+aHT6P391LHzzMCyFwRqYsY6UTWZcAfoWzYD8QrWr6Ny7FdejLUIjDg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAD0	1783582882889	{"key":"0OmOlexhURSLR9/TdzLPQUf6c2IaMHya70C4kCQd/VA","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"XenZIPT3ovD142DvZiMXHGDEvhXDG6ns8Hks2zra6T2D8pllc6J29QxHmCRTQ620ORUvbDJ2VXnvKCNaiD5LDg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAD4	1783582882889	{"key":"+UfziKoMG+k8Ri9ft/l/HgCjCa599Ego45POMVBMLl0","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"EuVD3g1MkuRasg5SA884lUbKRvYBcSaH5ZgHSiuvgc4WKsPK85fcHG5vuQJC59yi3wKSVdeFj0d9ryBxw2ktCQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAD8	1783582882889	{"key":"uIg7SnDyOZVS8JwsIeuWiGMLC7rPsavpcNyo/VWEahs","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"BJy8ti8OzEYeIxesF1skP1G1anQ70rRsd+yagJGMGFo0s4iQWaw5ONHE3OitiO6YH5bCTDMlyNbq+dYN1lfFAw"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAADI	1783582882889	{"key":"/iDZ7G2yIOEXaEWY0hg0U+SIVGDiN+iPokKFvG1dhhA","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"mId5LCOT/7q86ELG9Sezkl9TB9MteqzpDNRjOgBj0a+rWOvM8NirRyrCmCrbsRFVRLiP/vgs2KKH35D6FiB2Bg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAADM	1783582882889	{"key":"b2svu05GIqh1eoNOGEXqFOq2Q7fCXZ8Im03qW91HASo","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"jcRYjzQqlIzsABCNhLifD5Qj9FkjwGnQFRv6bl/tJkKEhth9cjlu6znGaKqEUqBVxMxQ4lUcjljIeKSxGe4KCw"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAADQ	1783582882889	{"key":"Ilqm/W8yrQsGJzxZULswwOMlTXe3dqbG4dx7kNyXrUA","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"I+hfhkLpkhg0HRF0e4N9QR5J2hqsPvuGYBr1OIuWvz3a1bEk80g0aLDrDeRKzcHzI/Duv0U4oy1aqeuygEKzAg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAADU	1783582882889	{"key":"lcLuOUoDjhOCpXqIiCXaJGkGUtMBBunEGnXot1k3+k4","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"7Xr1jnaXWG2rw0R4sPrkbEE0ekoxGDX72GUFiD3ntwseu0MWysD6I0rg7URTwSFApk8mtwNvKHAM89CGOLrqDw"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAADY	1783582882889	{"key":"eAr7bERi5/WhoXdKUSIqvw6wdww3Shm4FNT96Vkikww","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"NIDNtsH2l+Yv9br5E7JzjLq621zzhJ9mv61vi2oHGmnleChJBC1TdjhRCH9IxGG9FiA2fd8IgZwlOyfrpfCQDA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAADc	1783582882889	{"key":"lSu8S87KLJnfAChsh66G4ZB5K+XlVSjsYwNmtOgZqjE","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"OUaBeLZVAxQc8nqRn3NVVwpUU+CvKTmaDpVi8yKA4ZI+hAjZle44XOr3kw6W7xNRsGK0e6ef6J91V7RouuLEDQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAADg	1783582882889	{"key":"C88UTkWKxessNl7aU6tZvSOUttDIcHpsGptbBV+o8io","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"7wfyH6KTlJlC0VDmO1m0k78nhJv4Jw2+QqUvL6duB5sXE6ARZ7pX6tIFc0wl5YLAt1+3k4+pr+1puKPeOxNXDQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAADk	1783582882889	{"key":"ecOyWoN82QWJD2zK+lQCOe82DNaxszqdexkJiZIcgyU","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"I7FoQaNlEK3hPtEwAoTjoIvH8ZUb3LvjeQVZtwb33tdFRDZVc4fM9yjdx5d2Id12nvHKkDfE6xyt2NNaxMWYAQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAADo	1783582882889	{"key":"w5+EtNU4n8UHNVSRxq8tgAN7z1ojr5/j4A2F+ddAJFo","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"uw9VXsLMDdg+1Wg/aY7aUb1ZZo2Huj00qk1JFo8/kAZslEwCwD7O4n1lc6vcPsw6VozVJW9jqrif/UTxK7nQCA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAADs	1783582882889	{"key":"KAD3BukpasGikDKaCqvtZiTLOU7BWncpmWpZevoLxVw","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"0k1MxsedITsjnPwgsV42znrrVsvmc9eZoDKHAm9taa4Gt3TYNw5a7vvszwIbwYov6iz+5haDJXRk2PorPzWCBw"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAADw	1783582882889	{"key":"M8JbaDM7yVGIwKiktRvbTBk3toT0jigbpvwCqhFysCI","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"FgJVNdlOTs4sBvh1EMSgZxvXdsa0Oy7zAWm1PZCyv59FRvUcf6gfmXg+q5ghYcrM30wbcIP3n3d0QMlx4Y5vDA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAE0	1783582882889	{"key":"upEymI0gM7qcigAoHdyL1naO2rWxv1bpiEpGGaynxAI","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"pfX8VrnqdhVCsubmArLsm55H/s7MHSfMQLb5OKZ3QE8K/Wxx4RMNN+r90BXgyzaTV5t5BSpA8jlbOtrAO3/vBg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAE4	1783582882889	{"key":"V9VIlJM5aVh4KGy6ynPpG5egDKlmFczTPsn3Dg2yoW4","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"VsSu1aOZ2l/6BwsfbPXEJ3ZyUpnYjj5x/ww08ux4v8otTwvnTw2OLaVrEHN1W0+etaU76Pcs4N17XIQg8KLqBQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAE8	1783582882889	{"key":"0CA2mDpa8OYM6OHG9UxFepVRja9oYUtBOuvFKr1eDzM","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"iILeESc1bknE+VgWeQ8u7qzwvepl15tVogvCZJaa3P1StLOuiEf4P+bSs4WXw3RlGSCEJpikeJrU81JKGySqAg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAEA	1783582882889	{"key":"racNgzSFpTmMzTuQ/4DXMK5KxEKftlZqUxjWvlgBoko","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"IZz8jWmcLj6Eq4iqK87kZvJVjZVOBxIORQG/Al2O6b9tTEA79htgEtiy0IvZXXdcX8C54kBRyY4GJlb3uWKaBA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAEE	1783582882889	{"key":"EiGrJwfolGt26MpnAv2RupiWxf6EdHiXbyeDjFPddlM","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"wDbxU6qP8P9qYTNqyWwqYm58toHYHT1lo974dQUSit4asP7rXh/nV2Iv5JuD0GQTRgmTR41f0IFkTQ1bh8ewBA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAEI	1783582882889	{"key":"g02ypRojaPakRDc+kZI4FV8Vg3YFPGkd/OK33LSygRs","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"ErzJRgQjtF5TMM6mC1Ge1YJtCoJgiV54r8u2gZoTp4u5W54eLfp+WaNnYpt9AfokHYt+iwwLlN9c7dWLDQctBg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAEM	1783582882889	{"key":"9hAVWLEQUj/ytxNu6IYs1bEke+IrhegdbBKplWnJNSQ","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"vEaDVQmbBlSO56uV6q4HVRGyF8ookuMOS+xenPIPNbDURF0K6kgvwVBARIriQl+cMJoPpQzk8FdAX5D+3VotDA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAEQ	1783582882889	{"key":"djrAalIiDCcIPjF+wou5kC+gSm2BZRv0wsa48c5A2Uo","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"w+UEdT2RF3g+m7yIzAhM/Zu+X9UfM+skGBlTzxukqsHvCFDrrMjL0Aww93qMFK/yZ1f0PBWPU64MBqvLAO41DA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAEU	1783582882889	{"key":"92yWwMycltTrCyFy5v7D5WtcPpa53ovWKhdLGOx2dBo","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"lkrsWtnkku+Q/aoZ5anwfMV1N1ZeJbuOQE1lW1zbqltAgDKc14Qfs17JzUxwHZ/zrBiqSpa6fBztg3OwygOHCA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAEY	1783582882889	{"key":"shf7KzXNTFmTFQqKX0iJi/+xVhypiGFKvzVvmySqzCo","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"knupTwb0RgwsVwLKcdBGMaIzTLgZlcEKEVc5r0KzhKP/yHzMHr5/b8QPQ8MTkLj1jbJQq2zFa85tbkbynJG9CQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAEc	1783582882889	{"key":"pmiTtjI7AgqQZZj6lU/hAbrczTCCnrEs2a+waFBeexo","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"wnAAztiWQXpSeNYmcUFuuLjKFyWabfMmgKF5cV1c8c0AoIYC8j+O1LxuHtT3kbNtTSlR+jhnEoQ7FpS5ugUNDg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAEg	1783582882889	{"key":"M7XCzobEDHVEWJWceBC4XihN25/yanGd+CWr41M5rlI","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"OoPVXH9hgDbg3Ox4kSY+z+etliEVVjfc7N0p39gggdVpmHIW9E1RHVSKqFKM5K+OYVKk8n6Mgw551f2pxolNBw"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAEk	1783582882889	{"key":"o83F+drCfq1d8nGrOlF3PQ+ZqvvVZma95DDeJ0WjiWc","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"UF5Wluak2LRM+fOMKsZ1uLx+Pgorup75alo9gXlLQowzQU1smwS9xoHtZzcQ1z9iKu0VEAy2NGFHJ2ud6MDqDg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAEo	1783582882889	{"key":"TksAQCFWX6BwpQsjrlQrCoVeh6iRT/jb7CxtRGR2GVs","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"hXN8QBZ9g5+ESylmpsMODO6wNR66uOkxNrbz8OUsMeNkQZpgIpMfGJ6MEcyKPfrInraEC+B+DBq62/T26Wr5BQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAEs	1783582882889	{"key":"lLmSDA330g4DCCl8L+a/R/mDe3OIPhE9rhIPcJ8bVAs","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"OcnNLCxXbA7CvkHcFl8jHS8MKtBqRI4XWUYwHn97991t0dmtX/SfTWl6CE0urKaGWR606EZHMhi8Znc+WxT0Cg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAEw	1783582882889	{"key":"7V9tTKRBSNH/6WpDsmE+ULa5+XtJU5b9R8velMvNOn8","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"+nkd6lq2HvK6h1x05eHR0jhTlsu0irtBarQrbP/bRvZp8T9Q6s3Bx6esrfFkob6hitXolu2SaGrT+onJADrCAg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAF0	1783582882889	{"key":"tkTQ0nI1xbmkA+kqAc/TaZRnErCxt57lJp8sVkEOn0Q","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"F0IhuH9gW8pPIrdIQXUEMaWf5ykL10L638IFjpEPgyq6syiYJGGJxLjPvvfBYCscE1BnBK35zM41YV+T16v/BQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAF4	1783582882889	{"key":"OkR3m9T8V3qInPlIL7cDUnvXLzXgrq74dBX5ciWg6GM","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"hGupFNOpGr0LYdgIg/dxkA12pZAjqyVEK0ialmJrcMKa9CIpPpqY3r5VwD6Qmh0aWpIS1tJ8Z9msBNt6gw82BA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAF8	1783582882889	{"key":"hGiyU4lsVjOhuzmPIDq2ACl6AyDJuFxlQa9ytwQlkko","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"QmL1bLsIJJUUbdnVHTVg7bN/N7EU5bf1Up8ynl9fMLlebdWmLT3dZMddIq2mxWhAJGQtfqug+N4vNcrewb7YAw"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAFA	1783582882889	{"key":"ySPLj4X7qcCC7C0Ci6cp/RwsdnB+WdJ1anjtk1bqzC8","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"NXBcEmUTWB0gPgpNtCkUQ9tSr80nLkPF9gZTz4m0VDDKzwChJcJKucvLlZKWXdq/2nW8QgJ9ytwOjH8CwPywCA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAFE	1783582882889	{"key":"ruyedmYqp8vNwom3YBPZdNV56FcJTM7pS00ZCREZog0","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"gLYWd5rHJfyGj9uhyJu0Y/cT0E0Kwo3nIHLl0ZVsXvJycJ+jQccK9WFgO1D6WDNOOzfCGalAxFJX2Sd84iYxAA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAFI	1783582882889	{"key":"5N1T5NuRvw7otdAk7S5zdV/neFICaCmDCjobIdqO3i0","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"NqlwW52PLk8I417ccpS9s2VXRDxK5hBpsG0IX4rAEeWNllv75tyj0833QC1eZKesASCJri+PEptawS53UUtKDw"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAFM	1783582882889	{"key":"kZKsFvyxO80zhDGlBoAH4bGkKb5C7LKZ4baYNcjaElE","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"jKe4jj4pHaiYCgH+6BzBeZSElnf2a89JZS4E20L7RkakLEcaFZWQrlzqfjp1v4yg/rZU31Yai8DeRbCGEjm3Bg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAFQ	1783582882889	{"key":"EjH6tWQfJP1Zbi7MnqPpxvjAx1SOAE+atZcaE3UePD0","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"YLQaFVnaoMDYnp2NC8vmutCk5/j5BFisR6wt2xQ2mtT367fbl5QQsuBzoqcjE+lpq7FiJ7Yn3LPuIsdaQiM+CA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAFU	1783582882889	{"key":"+JC5OS03sRxhZ8T0lM0MLJ4rma3yUfFF89dWgH8ybRM","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"/J94yzu32eLPRGbriNcQg249Fq3UJMsxrlpZjFg6ZL58xARndN2TR4dtDL5z29V43q9ef9AMUZudQpBqIOiVAw"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAFY	1783582882889	{"key":"GeRtCkFS9EDzMrlJo/k96Xz5r+/FnD20atxqQxAmrEc","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"oA6itarVu1dqdXaedGGlaL+fMPgV49Mjrc+c4kP93glqH0OHYe8pdA4/EOU1c1h64KJibrCXpTO0W7FIwpJXAQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAFc	1783582882889	{"key":"VFf2PO2ZLKiZ+4mkMauBAFSrG3WSkyxAR6mouYHUPDo","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"gTLaRNaovI2fisXkM2SxMb4f1M1ZheSgvJ+I93Q4DZaHP7FTHU6TddaE+3FPSSv4IE8AFZPoMdMG/d8w07TjBA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAFg	1783582882889	{"key":"1AWQfhotzA0t0jrRVrr/4e7cMz9U5/dWp5/YJWWk/BM","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"zE7Ll0is1fZZPKCQtM7mALIUBXspZC6QIUgC5TiO49OApU3lfESALDGRRlr+3beifwekKAXVxoqIclIteEHNCA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAFk	1783582882889	{"key":"9ZVPxHa2Ua5id1xGagO+hYSf4oM9ifL662dC3jhF7ho","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"8Bx3dhMiRNsg3rdYIvslo1En+7UmOZBcBMQL56f9o5FjIAtNvgAsjlZe8TNNBZc5dq3ZlZhUuVx+7SXeSKsZCA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAFo	1783582882889	{"key":"pXvbQ2qNzv+AGAb3xhvqJ8RwPTfJS7wKCXAsH91UFUg","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"8ZpYU0nGt3cCPVmwIN+yzIsDftOwyICO6LOkk42hjAixRGSSB6KH66i+qzGj0qQJeYfUQ1ssFxTIDzJZKb7JDA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAFs	1783582882889	{"key":"7sUSzT4EB4uqcw00/ox9WLZj8Y7yFneTot3lTWqVWQU","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"psu8tBqhRmdC6M2zV0Bed/ZUBmGOHp9YCkO9PLNuvFB1DQ8ja+zsU8LHOtNRYETUv6Y87CFjkDBFiwjrSwOaBA"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAFw	1783582882889	{"key":"n2Lz9ZMYl5SIq+y5NIAqE4vYwCMyK6jbIqGZ180LzTI","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"Q2+XSd4gmTdDXcgAtwkDV2D5jjq9gHdXsCnhgb2FHYA6ubIhcAC899AZ7oyIhp0FZ/H8IXV1bpbzu3ushVlAAg"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAGA	1783582882889	{"key":"bj2QwjLqADVr4zdcxXL3V6mzSkbGxmFZ0Ff0FHxXyi8","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"DxWnTefQQlnBb+yggYNup039nESZbonIZ4Lj4L6bzsQHLhTyf/cWGnRNyHRMOoPLyZ3Xiuga4+nH7Lp3qVAmDQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAGE	1783582882889	{"key":"4LP3VjbLyIb1HTP/C7wWNtaw9NOo3Tv/VOEnzvq1cjo","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"8ZXvra3BQXv7QIwAAdwo8F+xARpjAuM7L7rpKAWr9eBkseZ1iTqW8VWaTB6h1ehL+Lbj6YHvB8RLAw8PFo73Aw"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAGI	1783582882889	{"key":"wmYSSfefptAVfsU2XGuqmOdjtZ1iohikBcgpBIVOSFs","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"Lm5jZnl27iWz7CNhLwrfqZekivcQEKmwiGeWHC5fBE7gPpygd/4AYdZhnn/LDMLCiRjvvky0LRkKSxnvzgVCBQ"}}}
@ali:shikpooshaan.ir	AOKSEIYZIB	signed_curve25519	AAAAAAAAAGM	1783582882889	{"key":"44BOcvEN5vMAjgOfE6I6MKss1MLnB/zJIyfuzWbY614","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"9A3mVkPHSyKoJF8Rxq3IU0kQgHCXkaADPley729f3ykpBSHJkGaT1gK836Pu/VKK5GW8+IHTms4aYErhXbUQAw"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAADM	1783583521038	{"key":"lh0GelSCv7EDRlTycbc+t9k5O9A4cAFBK645QnCKay8","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"N19C1Ro3mkZPjJulOTqHkqWafJmxm2oXIAZC/jMkEOrH4FUNSIs82mRmpxrOO4RJWjQelipqTaEfMNOVi00UAw"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAADQ	1783583563448	{"key":"YV44k/wRvslcZGAVudQ/Lp1x6ZluFSGs5Gi5ElfD/Qs","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"MmWX6XiCQABIg0sF6KenqYCCf2EULIQ1aYm1ezPBQObdiX83yyVkeN6CHbJoiMFXc89nFccAc/MPmPw9E6x9DQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAAA	1783581939482	{"key":"cohu5S/XpkvTyaPJTyUIoTunJPw/3P60QLH32eVUqxE","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"sk8RNlDOqKgyrNkK9WJVHWEqE28hM2EXJMCjdA9M8sDWrBH8Ma6QB+bpgTewkVfIf6Ld3P4UqMgsiy546CyXBQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAAE	1783581939482	{"key":"a2aOONXjlORa4r7t4gRCTD4++0mUJC/dvgPssiGSCAU","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"joaNvbSztKz/BIw/o/EEDxIFIsBhryq/vXMiNWZY5rF6a5YElfcSQthT9ctnAxRyZKvwx8Y6HM/83VNDvG+KCg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAAI	1783581939482	{"key":"3vM7bNBDQRsWQlvGzwRj32OjAuAjli+dM7/jmFVg4QQ","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"w/JoOBqBMN7OXOdpotkVwW/vaqgorGLf0ZbgXWEjPF6/vtVf37eDKv6+lk7CgAhcJYhj5tvf6WTVXYEnkVbcAg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAAM	1783581939482	{"key":"A8W0yGs2+PfFCyMECnKSdJr7sfSIU4Ur7Q7/LwU5wRY","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"pACbs0p2tc7S4x0hWI3xNWywA88PFQor6dPy7fyEJEjWd2oH0MMUuOV3US8nj8JoatrinGNkh+5xK+46o9zlBw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAAQ	1783581939482	{"key":"iuoiXTg7pnlrAEio+qryM+7fTuktU4EqgYeG98+DIQk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"ZwtGfoWIeyWTFxJQPujNjdfA1CZVKi64c2P7J9DUzYmxn04cWdqQi+/Eg75T3rKA84KiCGiUGzdVGKeMP5VKAw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAAU	1783581939482	{"key":"FB/FzHUaLVmDxjgmbTYge7Y4ePvq5etjU89No1cOFnk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"nSJIg2h/Lm7V6yR7LA/t4JjzhVP3DjTIzfFmqi0XgqCtcD1+X1MAnxsUkiT1+PQzf0ZOdylKPGfucmoFxEM5AQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAAY	1783581939482	{"key":"ICWQJOoCkSNoHPZB8cSrWHZtjR1JuiMA2PxdbL7F824","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"yFCEj08sTL2Fl2ZHCFP5Wbs6iHw4pmn4rBkcS0PEAiZNSVWPGdV5ILlHjxCXTudSYOIdW+oVA6lCFS1CGIpbDg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAAc	1783581939482	{"key":"thRLZ2mxMSZo1IIf7/fv4ehRxSGyk2/+kN9PU2RtSUk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"/sbPJRmQvBd4xkgMLnD0QYgJ+4qPBD25GEc6tdM7zziBKV7e6WbGPrQ7XcqTgn9IqOoSifEuoDm4NcEjPpj1Cg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAAg	1783581939482	{"key":"IHN1bD+u1r+NGFOuz65cFv/hE/k1ntY+mOmndzSix0U","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"Jg0yjIsSBngNBUF0jySjhPH2f7N9Eezg7F5iQDIw8g/eFs+gRK+UM3s2AwrI/6qJ+0HTsROd9hl4ZXXkQSR5AQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAAk	1783581939482	{"key":"yAf8TqyEQLTy2Y1H7dOcir9tgIV/lYqKiD7NnU3V4g8","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"k49DrqIaeQ10YSHJrkm0YICmFL8u5GYbUdXvmnaV6lD17K/M9AuThhn8hWvoW2NGOOpQO4IJ2uMrcD3MWTKNCw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAAo	1783581939482	{"key":"3kbZFfFqyLTg04ADM1YQc2GeONM/LpABjI3GPjdysBw","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"amGQRWAEZz1sjvH0vPK1MMfIGuIGA5sLeaGxtzQC9ckd5lCPX45cdsI5O/1C8EB8aK/QHhhSn9F4pakM17StBQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAAs	1783581939482	{"key":"NkOz2fCmPsbrrRhRPegX2el+Cfm5jqGKk2ZyQHVP4xE","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"G2hp4mXQYOvsApIFX2uKxdWYNCcGCZHxVCNnUx8NSjyIQ5lp5Oo+7O0lqge1Jn1AFjBxpQysrZm6qtWJ+aTwDQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAAw	1783581939482	{"key":"tIo43jk7ZoH27K9s1pAmKCHF49LTt03+KzzhU/J9OXU","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"tyjMhqgftHaEcLuJ73/aKh27H3LypDBOd73Q5jvq9psgL/1JD7tq17gH7WaAS2u3mAW7CKB1P2fLPGMgpnHRCw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAB0	1783581939482	{"key":"6DapWV/acRNfbowtW27U33lLI+dYwQZoMk/mveD5Hy0","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"91PoE4MzUz6KWHENEmSvMTXZhY2j9s2Q1peRFncN9BSh1GvwnQNqKUTfwpb/nsDD7ZvHXMoZYVEeB5VC6C+iCQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAB4	1783581939482	{"key":"rSsQQRIVh6Hu+hOso2OAPLvxS0IY+scDQMhNbsV1tUs","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"YxCDjoe5Mikay+DGoD/XsdE42xdk8xuz7RgE4gcf/Ryk3Fp56BFJtkKO8E4RoQ2AAmcaBU52+TQkYESkVy4vBQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAB8	1783581939482	{"key":"VDuqrLkpTIZm3skocF9pQ1zZPsyRuYDYxSOcNplKVwM","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"xueS910sOiBY7o9yLQV2W5GA9pvWuViBm+zCD70lfeJzIx6JGrUp9UQTtnjsjbTtpmkyt5KRwPEJj8vUovwmCQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAABA	1783581939482	{"key":"bR3VnKF0pz54jB4tIdv1SLth5okArC99xQ52AvoujRQ","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"2Intw5sJZBV6v6G1EVkPA1fB+0op3XS7Zbg6bVZgbGgqZzahAeZql63jHWZZfvw9AfZNBqi1MO+QRhvdh+40DA"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAABE	1783581939482	{"key":"6hKo10lYEDkM6vHG0i+nLTF6TKvEAuhpgT2ncG+cqhs","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"b7BFEg3R+aXcBeQHdQ/JSOis4D0pdt7ynt5jZndmfTYmrSt7VPcSlGKqb3gn9vmS2R31izSoIFq0r2+4axppBw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAABI	1783581939482	{"key":"/tM3Aec6zsxoTJuTpPFU4+P10VX/BEhkI32hoh0+UDg","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"jvjA5yyLs1/aFkjY62BuOj/8yd9cg2pQYwtEwxlM/MnbYNBVwGNc0e6iLOWRcUk0oDiUMMiyeboqqZKN+HJkCw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAABM	1783581939482	{"key":"MjTT1NU1T24KXXgBfpLG/sd6ov5nPadBMbUgEglE9n0","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"RV7sJqpVDUVIXoiRXQ/fVX5VJUld4f9m1HJzvQs1HHb3AsO6S/0WcrAtTpeJAHdrJggyHZmwop9+PYG2hN3LDA"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAABQ	1783581939482	{"key":"xfwalLM2m7NjwvNYWU4dOsJ5uwhxYFhvlZDl+KCFoi4","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"hxAMOdFc2Q+RK9WwwCQtsjznjfQZtRs4iHWyDsQZS0baWEWjH0I7liyd8BM92DiFXk977qT1dgtC/FrWu1q+Ag"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAABU	1783581939482	{"key":"dRLTJe4rxcDoqJmYciOJ2hqXofNwt/ocyOnbExxpkVs","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"eQlRjbWvbPcEmNEN/4CCZo4KgMa4MZLLSqffXDVZtHNYaL4KkDN4XLoqfnDVQtsflkM0bDOAuN0/a3xtLmcPAg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAABY	1783581939482	{"key":"9WUXiRHYzAma90c6xwOWHY5PYTh2MxdWwDtWFsVjdUI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"VDGikN2ElGDfY7QRlTf5OBfbuWzVZ8EyGb4IqX2KZeHD5q2GP3jJcUzsMDyjtK2ta5fN/9o9wkcNyNEErbdgDw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAABc	1783581939482	{"key":"gGOgV3hI3ic4Cbc4IMAwRn8mNId9i4m0R0rCV8tYdCY","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"Pp356dJHVF79iRjyvW0QXWR2/RlLOaFe/2BE7kpoRJk2mXXedvJJJUSr9Eyvzrn4i/u+tLMy9OJh3SL30RgjBw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAABg	1783581939482	{"key":"wZVbB+l7bRva+7hSxhJRfOEQkaYqL+oa6c6w8mhfCio","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"upSHjQSRHFstEHJ2SpPRSXJrpeQK9Ur85LbuKtr9J31KZwsoRi5KAHYELLW+p0xSzIWi29HsWjMQBZF/oUhFDA"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAABk	1783581939482	{"key":"uQdY9RjuoMxWyafJwUwbyXdpYimHXKXp/1Nrz0aCgSo","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"x2VJbfxTspALHmDq3QCl6+fIO/COcRqPh0EQyMcC81OEnSf1bLos4PtpJE3oa02se2skax+eCfbeCmcbcOTvCQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAABo	1783581939482	{"key":"2OuL3E82bRFDn3elu2uTv7EXmGTkBaHWMg7kwlYo/Vk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"c5tB2KGavRbGQ3QZber+xaSngWKng0kiBoP84Wv6PMRCaiyXbEm17H9VrU0pSWjAeGlxteS+xnKq/sV8embNDA"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAABs	1783581939482	{"key":"jO/Sgoly78XAGoru3jTWSfS210ZoWt7nJmWU2m29qEc","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"+ns240Feq0wmNbNIn1cMyCwXWxCoH+bbFPE9wH+AwTe8IwV8Pwu85Fh6wQHeAoq/iPXVn6SHAn7reBqxdYZEBw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAABw	1783581939482	{"key":"0g5XkG4R6FjxsgZ2ikCk3rQzYL4WNF7IcmrV0ODclDM","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"SPp3yDBGxiIME4tNKZerNsgDaovugUAz8IWkbSAFuasV52Br5Aj00t8eNEReA6YrDzaiGof8/PZxem+u/Wd3AQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAC0	1783581939482	{"key":"+YoANhfmBBMn6R/Ow9WsbRKPhoIJy/YXKS5ZCIfH/m0","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"Gqsb95I5b475qYG8JpD1CeTmn6pYvAO1qye7JJ94I4GTyiLTQM0YBDIMWpr133o4etLFfFrzfqCOgKeiQ+huCw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAC4	1783581939482	{"key":"CzPO/XzClSaCKtGO6ptO1m2sMZ1csu/ENZDxMkSYjmQ","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"0jAHlQekk94d5aY/atnNIW8sHDHiq12DO9vPwo4Y44i6HlsneU9Rmv+Gx84io8I9GXW6YRixllAPt7/dUz9fAQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAC8	1783581939482	{"key":"qE9eCd5fg7Y2cCK0w2gthaM3YZG7khqEwdqpfUbGLko","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"P9fkAguq5WGCF9Q/hpsKgc70mrT0TRZfqTzhoXnmxtiXHkUlYJiaWMu64UbgZyqJKvO2iZFH3nqQlO2RCIggDA"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAACA	1783581939482	{"key":"CZRhtkakpCebt0OCd7HO2qsL2NdO4pe0EkfVZoB0aXM","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"9KPKg8SPYuuPqi3Z1rTguN2MyEr8hwymXdWWDszpimxPSagMrEFlSs+IFF3M4zIv0eUPzmFkLQkA3ouQSD3TDQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAACE	1783581939482	{"key":"35AY8dBnZXKyo1yGB8rH2hNeOUmCApROXyIBhgzzHB4","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"b0CRuHBwq4wDF5HG9qaxE547uElREC46/uxSGtoykmrXFVVVtJeiwghQt36947sGDxoHg/v0wPjH+eXD4srLAA"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAACI	1783581939482	{"key":"UGBKHUog6d+wZ3RL6Way3YVaMOZV1C9fnezXB0LANkA","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"nEUo1123b48TrJXS318qTdIkkxGnS9Hgee8115l/ZwcC7v03BtH26Qpui2JIXW43UUK3IWXpdmRX1WJjmNzYCw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAACM	1783581939482	{"key":"YxXJ/3B3Muh5kOXR3Qk9MEJG0p6iHXpku+t2iU0oGTA","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"+Kch+1V4UT0MCmPy1Ua6Qvud3K5peaY+jFt9IFjZ+gEsPZxCdbdedLOmRT4+Dmg/NGsuwBrxusJLMLYvnl9WBw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAACQ	1783581939482	{"key":"LGcXrJLlaB0ScBGFzibFiPbQinPM+AqSr5r9UtlrgBg","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"EGpIoGnbxYGCtAwPZh9l/TOLkv55Vz4o7L/Y9Ty/fXEucp11J8oJnRkJmUV5uNy02HYCJrVehfJSmuM/4BKWCQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAACU	1783581939482	{"key":"J3B2XwFcjo2HI0/dVYrtqT05h/YajsXaog4hxxcRMFI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"3fVKjrMh7nDJMX4eoANj8NqEqL9nSIUzDltQGFbtllrWWqwsRePDiA7FEL7vtAc6nSGnXyAAuBBCX8LwdSHbBg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAACY	1783581939482	{"key":"Q8xukTGlfSEPiMYhgdbVdK+1cLxYS9rE0po8s0GGSjM","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"e+wJ1P2rF1x8Lp/jHl3N21pEhyQ3bCrVpkg4n6Z8qx76ipMe0IA3HT2l1mswoV5sZPOOy4+6zJ3oqezhbKHvCQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAACc	1783581939482	{"key":"/C9ZvK+GhCC12GPBeGT/VkBR+mwMcXHNlIO799GB/UU","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"q05rtQpgAQfudrF+5D4GXnw3JyFBLWIpflSkHabQKt5TgF9feLHA302IpUMWMzsZ9CaQy1E4eWdu8Lc4rGXOAQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAACg	1783581939482	{"key":"RbFU6h19H/5dZzOmuc5yCWG0dHPSdNSdQ8q4jgjFBGI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"rrWReJv63/q1zex4HTS0by4avshXJMB3ukfl9Xgu7nomiDGtLnFheE+WlyHoCGULeqKWWjkIVB/1ktbVcal9Cw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAACk	1783581939482	{"key":"WrA2x26bzkXum1RmcZxhNa38mePLA45e5NsqVhz+lGY","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"WmQXpzaL3qALr0NEr7z2bRldvFFC31UdLuiYaCkPF59k0LyCPBXTXVEUUZujr91Py60lyY3GBZY56pvvBDiBCA"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAACo	1783581939482	{"key":"j4mSpRJZzYYMQSQi/3x44mhRkUyBH6XElTw8WmlIhxk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"q/p7Zgx3PFWTtwsUWg5IzNk8msi+G+lu0cCVPnGqfAWC9ekQIy4/W16jvQr86RyTo3Tk7Fu1wSQNNLtKh8kqDQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAACs	1783581939482	{"key":"+xPPHCQwzO70U361qJv3UFdCi+dwkJXrYj2n2DuXFG8","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"wfg7Y2uEN2KIEVLfblmjdTOu1CXgxBiG8alF5q2Bn7Pt5fuDz+FCk1P8KR9d5iCOKMcFPB4CUKyYExJWeKbxCQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAADA	1783581939482	{"key":"I4tUfa3HJE69MD4fMlT9Bt7X+JO/Ll1VnsNR8YLnsXU","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"+d/vGOJ1LjYfcgh88GZOY5cFV6veBOdmFuepMLUGaRRFDT2SkS2WKYkB0aa+O839KbqmiiG58ouivxensG2UAw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAADE	1783581939482	{"key":"jStYqb7EcwRc8b7pdbbJxklc/HT31cfV6bt+jtfRiCs","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"rWy6GQWS5Bumlu5iwa2LnaX3UOlA/wgAkN2c8se+yLuVRPaq1OTXNbTbHpu/YIdI9ytPf4tOG1+Ugg63DlRVAw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAD0	1783581942260	{"key":"e5Sih7Zcv9LVbXTKmjIs7yVhklRsPYaiBKvJdPQJIyY","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"lDk3uU1b0nh/coHSR/z8H+pokfOOHbiMeKzFgWMNb9+i9DSOP7TDbxaJzfJHClC2/D/W+GM69CTCioRT4bb8DQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAD4	1783581942260	{"key":"H1/gmCWm4RDVO4X3tYKyOR4Ei+hCgQS2qOt0i/rf7Ag","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"d3TqM0bvRIv3u3KwSXIyVi9GGXuBYQ/3aStdOsnVxJcjdmTNSbcO+dq9VYFbzfRNCbZkGdDR6KQQlxa95r9KCg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAD8	1783581942260	{"key":"8HKX9WuT97NpB63aszXSxRN7hfBY3nhl0UQvQiSaaik","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"d9BRIH1+FSHskeXnE6kpQIzdTIWhHxhX7cpezz2KShFdTET64eorX5Yoqw5wP+2V7YNJ08hpvuSvXrdvDKRWAQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAADI	1783581942260	{"key":"g0Rr6vVCTx/wp6+k+/4MlrvoTcEMMM1OMUIsv0V8Pxs","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"C22xhpWK+KSK5ukXa8KjWkQ2NA+PV2MSD+Qqfr01sp2Nt1ENVdfq6KcRQw3Ch9o71JKqz1zfgd3Hm+79rD9NBg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAADM	1783581942260	{"key":"qc6ZPlJj3LIxLsizJFwLjimtHmnOU7cvGEl4zyH9Ono","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"9yLPEio1jddszkMuzVyaWV8RjQMNhX6FzRI9mKB4RcAH2X6E/w/XJNB0+fkaEesDSvWd9lF5NxsIbQusuTB6DQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAADQ	1783581942260	{"key":"umF21oye2f8xVHGiklfsNrJJEiQQL0oaiv91lJfZzng","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"TY0G00VaesNFITHZKSVG8828VYU/jO6t8R27CHd5fvTaLk3Ptv8PzEQYUZf5YsjqmobjL4hGIKukDCv48mrdCg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAADU	1783581942260	{"key":"4nJaj4O9BajKKZkM3SpTTRemn+d/LfWHQkAoH6BrbHM","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"jmCFmEjvnfNWRhslmwH7lURhfVn/7rPe4p2Hs+23GXQvkZYW6AEqBtByuiHteVQI1gWH/FJN/L5jCibz2rKVAQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAADY	1783581942260	{"key":"63dWgex1zxrJTN5QPPrCNa4HX8t3X5x5fFxx3/+j0V4","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"NDPwg3E/2tVOJlNqut5n9g2B++MOGfg9Hs+g79iUiOdMKca+IXhtm2V/rLfNIzDkwJts9iCzTCfNhw1R2UDKDw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAADc	1783581942260	{"key":"jPXw/ZCrEkzHpbdWKDHeeZObAqhqUzLwDnKwJ+WUsw0","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"4cWYFk/N+kfEKZLA0YM6BE37oK15vQcsfiXKJd1t6/JmzGdPTHm3yFinGClkco41qVbjp15vOLxR4ab3XQzKDw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAADg	1783581942260	{"key":"qrwQiVxxPUU/H4ohO9vZm7HvymuaUH2odWVgjw2FtjM","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"3mB98p+/degIxxUrry/THbJ0e04fmf6NAS1/fZ7fBO31R+QEfa08+KBEkczhWYjusbgQMEuoofhv8U7r35IQCA"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAADk	1783581942260	{"key":"gV124YUOH5hvbzWFlRshAt7JkCbO4FAiamroYm5ihVA","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"+X9Ae9nNbaeGN4eat/8JcD2ARbhIgOePPyKWkaCqoPJhON0sLMAzeX6Q9b28JqGjzM9HeJTvI3irq8IW3lr2Ag"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAADo	1783581942260	{"key":"LrOuh+uEGLYE7BqtyIQ+7GVFSNDIJn0RIt9crxuKWjk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"guM3+9q29LOib5wLIjkOtSzu6kXm0HgmQyhfoUBBuw+EsN0/VQ4ShzdF0bQXyYu0GecdWqHmr3JJTWsja0nVDg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAADs	1783581942260	{"key":"6kw0KTGXKvJP0rpEvChEmKrdK1f+MEvopK2zuHsFlAU","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"pVTAE9xyuly3KUBWhG9Tjd9c6L40nO+rSPYRCPSNDhmKe9cYCmVvY79S0x+FbxhjLzQ7julru12fqmzTqrL1Bw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAADw	1783581942260	{"key":"oyfijMFGCa9/hkVVduyBYfazsH4DhYoWt2dFAgVdbWc","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"ZbySFss6RfVXHDSQakv1i8FVwIPu5ffAj5mQhnQMCHSXOFhHkv0oMaYcLhXLi3y0coblSszL5pXZfwWg1vbIDQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAE0	1783581942260	{"key":"HEBY8nHYiv8v0yaLXKGCowt8rGmpDQuOmRoXY9cglxk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"6T0fYw+K1eSOMBypK0T8GTq/uecDUVK/kii5Q5/mBJIHdZUBg8lyFedfFsoooFzKq2rTHrv+6ySOLc4NIeAPCg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAE4	1783581942260	{"key":"FdroiOsFE2MoPCYVtpZEt4V5aLtpUWgro/zrPDl6G2Q","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"cAiXGEQVewIQs232wH4TFxMOxjBXQX1Wd/OLMoYm+tfKvgonP9XRZsZ0b4iVR7mvbU7i4MsiwHCYFXwdNXmCCw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAE8	1783581942260	{"key":"Gyd1cSodSKJUuVcTynHeJ4dZb7U/Olbhh0f9ldSS2hM","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"zfVQpWxKf7CuCdzzNviWO1DIrVdqzJhEjK/KdX+WRoU3nNFA1/c/NBjmKcndBU1vSPcNfFDWPkZDUBlH3K3YDw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAEA	1783581942260	{"key":"HszunANPp7EqxVL9sQqMud/kYY+CMoY0vBCmtnFyAwo","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"RME8/1UeK8VJxcsxcNPK8OhttlyxoNab+DVbgECOn4LJ6aM7WaB2GKX9erQKRfT0LU6iD7wYfhV+17ox7LS6AQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAEE	1783581942260	{"key":"y9opmx3DQ6foWmUFuBvNql5hC9jo5vtV7sIOgi7DZVI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"Vj57U6WBBRTynCBOxyMTx9klDP0mzRzw9KOtWIBgnvegoOmS0Y3R1diHILTb1SJDWmlRTZyZTzEyUQ07gg0BDw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAEI	1783581942260	{"key":"fRtVMrP3MIBHe3lmSgm8amMKdH5/DcMkd5EMgOGYMgs","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"kpko/KagT98ytYFInGYJEiCx0UvTaNiJIbG1roBS6BHHRLJ4l2110ePkviLuIFQj52XokznfHvHOtHQJmh16Cg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAEM	1783581942260	{"key":"pd0FFaEg/pvuJIO5CklyvKhqvt6QF7MqILKf+WZP+hk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"+yXvTHq+mGzoZS+ImpF43ffnNq+izQPCrUeqRcHiLUtm3/V7jd17248IZt8ji2hM6nXy2e+R+rqCq1nH9L4tAQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAEQ	1783581942260	{"key":"zC1eM71oV+XEcFwm0qWB/+pLQJNqGui0F4R+yGZSOnk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"HqciniTi93s37+Sg4QmDnuYbJdM5vX5A/dpBAGX8gUscFVGspfcxEQehF/5iEXlD7fm44iv3VSqRXmp85ysgBA"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAEU	1783581942260	{"key":"T5eJZMdhTw89kTde+El53SwVmvr1+V2UY6naNCEzwDg","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"p6YSukulAjLMBFsT33a6dloEBMG5kQAefm3CG+KkuvX3GM7aYd1dun4l22OdifELNNj9Ut5BePvLaw8H8PvIBQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAEY	1783581942260	{"key":"NRCRlCYaGLDtpSRQtkN/LiBDo4ZspR0npS0YgTnsBgI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"DUd1tNIOi06RZyqFNYQDGbxEy1XXSRLzhuQmL8aFhTdOepGoGv5ism75uFTe/nUMVB4HuhajEAWVa1GAUY1aBw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAEc	1783581942260	{"key":"90I1nTlQnwFFpYbNzF/1I5J1XBOBKbERUUcZkSJ3mgA","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"bUfItFMI2yRNcdw0UHFnL5UJTxKJOntQiGlSWDlNY62bsOJrrMwaCcE0A6dOmO3Y1JH1YuIcggB7gXIBluM1CA"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAEg	1783581942260	{"key":"pQwmRROMz7JtFZJgQg85iqVsxTZHf7HuPWfsOvWxF1Y","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"vEcBo++AW2C8b+V9zkRrbnRdQf045KmM78v0aOsA58BskcWkb+XH/z7Wqmoi45s++RLmHKhegeDbSiQTrP4jBg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAEk	1783581942260	{"key":"9zeb6/838hkrKzqiYyRq8vo/QwytDr4PjW0m8frT4mk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"oNJKIen+8q7fFYgpEbIcBB3OjSRRyDJfZgZK8onyOe90oE1/c5fy2vdjsxy03kj8Y8agntUHmPjJ+4Yfc+2YBA"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAEo	1783581942260	{"key":"3uOLkpT4KOEeHSjkrnC4LWdyApTDP6n6M31xIM8nFV4","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"oWb++FL6xSKFRUN2B4s0+wV+0DgWGfiO8qxh1dXr26rI0/CQW0nPfsekv7LNwWFj/qtqRwBj9mLcBFHraf35CA"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAEs	1783581942260	{"key":"rQQgUo40ZLS7uzZKCTfpmdgjcNrwFEeXNGu3qGB/jiY","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"9LZOFHVPeAkK9+nGJrA76ET7lW0A4E21eQzgfq+yIeeQNSylyDkHMze5Xhb5U/nuNBDMa2k/MSfXDUAV40AbDw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAEw	1783581942260	{"key":"ui3UYE01vRsvV9iD2P43fzHAvpY4OCvFWFu48prmHAo","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"tSUc5YUFypZw0K6OhrerQYkOsgEO38lENETWso4jxycfxyt6V1rBstpq/F9/OpMXM/xeC8s+kgtwCbaOvj5dAQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAF0	1783581942260	{"key":"z5ttIu5wDE5hudew2ZNk4n0GNVghA23Y0gONxep5Q1Q","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"hB6oalTQuuIBWo2vUfcugCeqhe39KDGxoffd639RYER383+QroriUvS3PxXis9J2iq2KgtHmuGPZmCWIAGhtCw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAF4	1783581942260	{"key":"2iixPjg6VEq62xbwZ4xr0ys/udQuFbsWQG0pzkD3PB0","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"iRG7/REb2GuIeCD0PBTh2+ylgUiRynqbdpBstOWp0g/pwUTC0kBgKzTX5cbSQqB6KyZVVL0C+FlPGHtBxC/XCw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAF8	1783581942260	{"key":"453uMQAlhTm4Ppj0CJL6rlotnKhSgYA9D5KiCR5ZAWc","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"sEzMDTFflRNDDPZA69rwa/jk6RpbMCQfyzNAm3oMD6zBN9hhRXnahHptY6UnwUPb/vlQVORDGJ8BcIBp/UySCA"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAFA	1783581942260	{"key":"8z9ON3WfsiK99tfOznlW9A8Cv4tGLp0K3HDxHljSfkI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"7MAHrVDRk49x4yv2L5basQtxBSbBzYap+jgVREpYzaMC9NIOr8rcxtU05W3jX3N9BPG3bKOQgY5+zELVGu2yCw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAFE	1783581942260	{"key":"szxEQmw8EIRgYekMMz6kLhitUN4CRU/8KNK5/YxGOVw","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"bA6hgNMosXLbn5/ASdybepnbJg7ZwQpuocgkx9DgT4Mn0FE6E2972bAcPuwGacIZe56+dKBbfROqac1rKW/MBw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAFI	1783581942260	{"key":"26rRANCWApQolrNe5mQHvn41b1a1pFou2J6tIZbVowQ","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"Wey+0pldCOK2+z8/K9uLeR24ov3oZJEf58gtAq+z811s0dPqBTvIPxPDoPJdzrEaABp4DvtYnlx5u/EzjKrlCw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAFM	1783581942260	{"key":"KUDjpB5YEG9XGRsk5zGgbsG1boSEY/dOMytQMFto4SQ","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"drwq0KMh7t37FD6a7xCH1PuRFQK4FKCHYfDNYw4NC0GizOLWa6Z3t+mfB/ITWjf1eIigCkAB85TJ952BsvLtCg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAFQ	1783581942260	{"key":"MBzj4GLK2WYHrYK6JpC3GczzXbNIBVg4A9cwYsWZbW8","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"vuWt0PGzR1xZ43kBqsYnhrGP2eIgKEjesCXzOvlX9eouvblgGHdVhptH1XwT+j/Mm78tXLVIqhEkXu4jzKXDDw"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAFU	1783581942260	{"key":"0zZCT157iV0mnYzWDvMeUu4eR+38YifUxjVeD2QXkBA","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"F9DRxbe1CP/l/sVclhHE9wD4l3JxUkeoGBccuhB+1xDnAaYiwEckmb9fzgFy2LkuqHMfEhbeh08FjKTBHAlYDg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAFY	1783581942260	{"key":"fmYwRfj9QF6FewQD/GAMJOBUUgT144kBeR/B4ECDjy0","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"bWp/q4RLbBzIt2fyWLIOtO3irNVA1KYaHAt0w2rHPwSbAuLXlxnUdW2g1Fl72P+tGu7VAIIIk68o2DiZaM+KCQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAFc	1783581942260	{"key":"D8VrC1lKlx09JY8lIgWofm3pdd/GO3O0iZ47AkLT6Fo","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"gT+ICR4zuPKGf5CZfdrZxZl/dB7lHtfYF4dpBcMKOl9xdM5LslwNYgyhHEy2aIOvRWKQsb3BiE0t49czi9UiAQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAFg	1783581942260	{"key":"lDhLV+A3xbhAscLPBPiYToBAXme6Oxv5l8xgbUWeb1s","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"zDXKBjx9gBfFOBU1mjjdIU77iMc4yPg82Z5+aMIDs4uZXWv2ltEYLbPO1WlgI3L9vs/6wupjf6CrRFIiXLvhBQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAFk	1783581942260	{"key":"z1XAeNmxK7U/fUHYAUC1jLhcBb8pUE7sQeiUeH5t8kk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"uT7ALl+70C9JyhTLTCKUe+Lj92iSrlrkw8f1v19bZc2KiH7Mm9eetbtFQFi49wAT/GgDt+wfrrlzUYn/wm7wCg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAFo	1783581942260	{"key":"MufF6IjaTXr3cej9X4y7K7HQf21efAF8MNJQQXMBx0A","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"42BR3DFUSoZj1r2i+YVuUWHzIPXJjvfi6dniMMTKst3Y5MUlg0bAPUXke2dAwEdvR5gpVbPBTXw0uqkrx7SLCQ"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAFs	1783581942260	{"key":"avb02AwBep1y+A9BWkfUKY4gcjpmdBLCWrI7Qd51oUo","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"67O6sg7lTW/LLyKOGv3PA0na55WJ0DfxvR3K584fPljDVeUezXQ0ux2jgDGhhIbi1ppK7ywAL2LXEvQlWWoABg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAFw	1783581942260	{"key":"fyFxtEbclAfAXyX4Cp7tnIKLRMH5Rjki76mYnCSN4yc","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"Ai6yb2w6iDNQjR9HCZ+cHF1hqZsW8mIzFsL13Pk2E2q3VKZDLwoVPrwISxylDv2zTfK53sqWTZGVFPy2ihlNBg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAGA	1783581942260	{"key":"GU0MZxtQ4EUjnBK9q4gIqwtJ+Ew8Aig+0x8SMeEqUhg","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"7nhQ6w9r8xFLE61TaP9OgrDJHp/uMkI2udAIzesEZ5DoAMLSXSNvqOt2NX2PI9qRwuWfhJxtL+UkYpxzWC7JCA"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAGE	1783581942260	{"key":"kD1TAzLZo1gQC9tdvW83YZvbMrxw33ZRmAFmlTMbeAg","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"yBKjGjl65WfOVoatENsAQB+BeviPtTt6lvPn8nSN3n8rp5Dd2sPXZXAWee6KjxAabBhEUBMfKHOu3ck+LnjlAg"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAGI	1783581942260	{"key":"e7STu30cfUqCDz3S5iUydWC4NisLM/ZaGkzGxuFg2UM","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"EAmexp3esY8bJP0CpCo7lYeVmFQweHN7jPZnTJa0UTrsUNuiqpAtculFjQfQLqJkF9h4A4pijU+4C0nraPKfCA"}}}
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	signed_curve25519	AAAAAAAAAGM	1783581942260	{"key":"x6JmzvY0092SV0n8u9h7ZhYkRbNNMN+D67AqogBZMEY","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:UJHQSRLCJP":"fwWJNLW3eVVrwGfDl5ztf44k1bWDrUzHLGg7ZoaQPnyzdu/qFqKwynmxhVsvV5tzJV8NuiiiE8y6ldLhGT8oAA"}}}
@alextaylor:shikpooshaan.ir	HKTASTBOAS	signed_curve25519	AAAAAAAAADI	1783582227468	{"key":"qfJzvf3u8t0EtTBZAupG2ZzTWToVU01TSvAJarwn634","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"TkL4xG1q/mg1AzamkQt0iSsBYuYWtqW/ssR6C2CtVdpt+V2tyWDN5WWErOWu4k7vY6FgB1/hhlX89bVWwUfsCg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAA4	1783582639746	{"key":"C1GV5uQ46sTlFumqysn8x64vm9544qsRak/bF085Uhs","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"ofIqgBxLRiysuH/e+wdLZKVok2FWbcqDa9AI7pw4fhXJwTgBTxPqR0gC3vj+oAEP+djU8UW9MMlv21YUtQJxAw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAA8	1783582639746	{"key":"T8Wo+wh3bYomvZSmWE1/DaOkhs74bt3whhsM+Zt4lVo","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"lMlDIOTbprtYJcDSgtyiktj58jkd+R3Y4ovztp9WsxUOHN1zUsSeVGwgnzIcT6GZ+g9996iB40fm4qsmCuxnDA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAAA	1783582639746	{"key":"ZqMdX03vQxb/934rK0e5HDfst77r7I18USaZwCW+aS4","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"TI1m4Ke95jK5fCKctxwz21jXaX4m9Wrk4uT4WcnMSRWD4y5KlEBSPbK5t5YkT/iqi/YUW+3wiHl0vdT+j2KABQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAAE	1783582639746	{"key":"6e6DkmU1yR5odYSD2K4xKZwioMIDC5k6xcGtPMTms2U","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"E1UbSK2iRI0vU7XON5w/930LFNOySe2Qe084pIJZ1Dk9opXP1wf749Lpy4kHIhpPmuAAwutB23FVcptYGapdAQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAAI	1783582639746	{"key":"FRZYm8xL00vHnDJ/dbOv6ujDOfxLmnb+bp1dluFffHQ","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"NphhiSqfV93BwdDt8NF7TkGUVmXTVtbSCWJ+tPjR0B9fIe30vWiWR+Kpv1HmMuFueI6+Jn69UuRjIuXp0WrhAA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAAM	1783582639746	{"key":"7pYG+nZ2bDZAmCUphebMgf68wBuceNYp+FTxLWgTvQg","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"zR7URTIeucwtmoxRcRePrfc17GqPmpbqf1eHF4iyrBbawS5ySMKPd7u4+gnMUwWKoU+EKIAocS9doZ6T+aYKCg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAAQ	1783582639746	{"key":"Y6F3PN33DIGdZfQBfS5SHsVx12L++8yIPUXS2KW3EEE","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"ykE2Fn8fEuXAR93nHi+lcY2N9t7obB5GSwAqgFjjLWb/ZW+/KOH0MI1CP7l7fHXADlNngStjFMCqibhb1CRtAg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAAU	1783582639746	{"key":"vvel1jg4UA3kjHyO0JeQmdBqNBVvOzt5b2ntvEjsEEQ","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"cuPT/89dSh0OTN61lm8GuHzS2/ysEL68urmok0u4HclG1eMgQz+gUmkmG3K20ruE82greVt5sZ0QdEH8u8j7DQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAAY	1783582639746	{"key":"6KVWJRE1C9SVx7b5EwOYMO/vlQxLXNDFEbvBOyi/chk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"ukG80RE3qtYx+RQsiL7Hp9liKlGJGA4lXytbSkJ3wafsEKd6WsB2WsPeRoWC0kCcCTiPsyhksctDH6sYdOVaBg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAAc	1783582639746	{"key":"qx/gmEThpP+K4CkD8iTdjNs7rtdqoPW22zl1N54BOA0","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"ZkKz68jFNKFjhKypYEa5hzevxVvtu8xXumvmAm1aT8mCQKAiqzZEfA6JRg/zlA1EYvmnoRVP0RUwyZsB9VB3DA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAAg	1783582639746	{"key":"sXChIGFukOtQiT8CPh5UnpGY9qlDGNRj3X6NoJwkUGk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"TPa6xP250V3znwpRmA9viiStULIJTIW+Ty5J+98JED24DqkL1iOGh5F6IFku5Xd28Lu6q5XY14Qf+Ohx7BNlBw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAAk	1783582639746	{"key":"laGKcRr2bX395SoH95GJ7QT/4MSk0jT6nl6XFwD6uDc","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"WzRoEheAi81FN3ZtHAga77FbdRyntXxYSofOzsStEoygximFUDaXwWnAs4AVy/GOlagc68lYTakkTGbzssxFCA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAAo	1783582639746	{"key":"xaFI72Warw9G19JOQ5abnVdVVLFbSxO5j89vl83bFRI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"+BQbO0L/FnBWuf+1CFU7P+gy5X2cl/CA0FqIcUPARnVY08qTfF/gSQVxjwwnk1Gp3Aq6KOQlwVMtnQtLLO6BAg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAAs	1783582639746	{"key":"wXvvEbOBhz0GZwT0oXa+0EP0g2gIKN6YtkpWPg/rvEg","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"TpsBI4LnhQqlCKQQEan9tc7hNSheGn6Xtzo+n/M58c86f527n3YvgPb665DL0bPXsU/zwHZUPiW4+IyybotUBg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAAw	1783582639746	{"key":"kNUMtmPz9sJUdaLetZWvv1iekgSzh/RwufNg3yteiSs","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"i873Tv6BA2SMxN/KwWMF+PxDNbUsMQ9pjFCuCqA2qQyK8JkAgXve+SbUCSH8Gmtru16Aq4uqNjzROHT05iirAA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAB0	1783582639746	{"key":"tjgByYf7iwoN/OSrKa9KQXb7sB2MjjCZNtfH7dXtlig","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"S3+A1W/V1As61O3jLq8fpMERVI5ei+YZ9pDUcacNAS+s9QiyZiAXJ3WdXKfLshHUSC9jULyJENnU9jxM4qljBQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAB4	1783582639746	{"key":"EQSZxBnoJXxOM53tj5knw8coCaWYCHHs3U4TETbsZUg","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"eXQbOI8TEctxR0MUqxYlg6diY+ikz3Fo6S9f55xDGzEjJrjMlF55qV+7gsnLYYaOI10DzR0dpKQtK5N+68BUAg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAB8	1783582639746	{"key":"92GjFDc21zeNFGOH7jgdUnH0CwZ5CP0/2PgT+o/if3c","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"ff69QzOKEZkCSk+IJbGabBpppP97Lf48XbIfoO3FfGpUysG3oQnOhJqEuJUP+VxOp+aqoRuE6r4pZmamGfjZDg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAABA	1783582639746	{"key":"rEZ+gubU26y2FiO98oAU3lo1kHw85HlRK8N8uxFNmhA","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"0bKdzqBa0EFEmh4l5pKQSCQTZUxKZPoikxCaof62OGm4+fu6u6OIYdIZZSotSjSKvX5vLwuI+SX1qRPQhjbeBw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAABE	1783582639746	{"key":"8z3j/wPCB/IWT+T+wsi0WJvEdQgg4T3MgOYX4e2zA0s","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"6vKv8bv1xNb9vLLsizfpymbM32pUpXOWAzdYWQNxsJbgbskbX+eIaBzrRPj3ffBjIOMZ6ljCtyXv2GZoHhiSCA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAABI	1783582639746	{"key":"QoyipKGbcJnqO3poojAQ4A2YIAsOR19KFgOWr1tpYmc","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"0Br0muJ0uvkLcj6pCCCSDRoLR6GuD1ekxpskZ0URjsXZ/xabGwiu5mkBzIf4raR9uV3sUikHBt8Cj3qwb1WqAA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAABM	1783582639746	{"key":"05gwW2Q1Yzd2eeHrwzHryNerCKJ5gcS7hPy8Yh+npUs","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"G1I0yjshFApyyoQNx/aiqyny3pfy3acQrGbYYO/111A43GBNYJhmug8gmWNgCJac6Jl8OQhoEPaiaNppNr9BBQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAABQ	1783582639746	{"key":"i7xKBExjbHaAEPuR9NiYB2h5hBol9QG9wAf9F15xfE4","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"qKgBSwViTfSgi9webwvSw3+C48Wj3VrMt4xZKvDiT3EUTKXLN2PM4d/YjsCZTUQ/9IF/hH6cqYqp+FZdmZbrDQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAABU	1783582639746	{"key":"nxRoi3UGMnAyEYi7UeG343GSN2uFQ5XrQ6f+wcK8qBs","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"PsSXaMMb4oKay8XZSG5mlSFfpDvZjwSeen34WXW73u2Y+URB8VHh2KdvtwCNf0zgqgISoGSjCgBVmKDZW/RqDA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAABY	1783582639746	{"key":"CMNPUPuaQH3LVnb/AMx8C/NDww7xCufyvGxJy8BENkY","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"la4OAUPyv77OWXPSywe32MSf+//Ve0PaYmccFUW61JStVFsu2ZaomYWNuvI2UZqNWo2uff+3fUOJPrMv079vAw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAABc	1783582639746	{"key":"dKbbQKiduPgbmi1M/Ha4TqwSClWHPgIb71Kd0n/XvjI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"6olsU+YDyt46XX7//Emt17h7trMTDipEislKVkVST1XOhZkczTFFFvrFZV2Jp8n6Ks7lElT4lfu37f3ysUKMDA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAABg	1783582639746	{"key":"/PPY5i8v/Z7FO/e44YMhenklWigM+HauI4ZXBNDBtEo","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"rkkvMPj/7Ni3tzL8UqG7Q8320G3V0c88fR63J6a5w3QHwardN4SpYii9+ICZEHT6FWwTf/fm/6dt7ZfTYGn3Ag"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAABk	1783582639746	{"key":"3k0w0wGtAz8GXsHOnPTedbDU+fPPvRPio7CZ5v1vanc","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"IA38iKT+fcgQ7nK4u1ATkAxNmupTkSpnt9N0jZbL9MG86Xxsp3hfhawoo34SWvly/swiitGg5UObDuqFKnnsBg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAABo	1783582639746	{"key":"W/Iyr4Eh9oh3GPkQtMq6Oq2rAUUxo82xUDfpxW1SEm0","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"UUYBKpZd3O3hpMQ9RAkZIFc2ynnPqDhUF1ftmB7TwVWWE4Hk9iiTgMwp3hABIbQazMtCL4lVhCm0yWeIK+TCBg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAABs	1783582639746	{"key":"6eNkYxnfHzAjWxw0Bo28FVNmlxFTr7riGPEt0dxdogo","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"XZc0EKV2BrOm/TjuihE7hJOHocqCoW6TPaxrHOgFf956/cYAGs2VBckju2B80VSzVBOTCfWi0zr2EES7DKhUBw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAABw	1783582639746	{"key":"zhJZNMZcLnOIkFjGDXsEIk1aNyAYEgGMcEOJqUdN7yo","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"294gDecRZd05WDJFb4MCnR+OpcwcQLB76PHHAb0ZSwYX563Kk+xZ/086jjwUA80h+to60soQgM38eqjyyjzjCA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAC0	1783582639746	{"key":"v96HKTjZ1HbWM611MnsEQyNSgSX/whP/gQJLYuj6ZDc","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"tBog7SrR27FJhAOktGuesTT+pYM3yo7feV3yRXA69rj2AxM9fY0XySldWXs39T9/S/ljH2mdpvapTlY2BkekAg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAC4	1783582639746	{"key":"vrV8L85++8OwCz+Gf1uuNC5cbf42pNMA4BhuMzLRTh4","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"cym5jgiee2Q8hasi0O7Lp/6MueGhs3fMbaz/HBdPOIZ905b0EPEOHmguiCi6bePuN2OLLcuAorrxzHXmIV6WAA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAC8	1783582639746	{"key":"/K5NSzheSsLf3cElgQ5Bw1ODAluahgQWg13zjs8O1yA","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"CX0MTzCLaSWd51saT2YKBy5yTf/WXVDrH963y0AXdnU4Zf4xPbxxVF9Qg0vy0r7cxERwBgfAlzKY6HXq+AZPAw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAACA	1783582639746	{"key":"HFyd18QUGTCpOc0g1mWwPYYEWVzaGv6kznTtrKnbdmM","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"P8MwLfkt0NywR9tGFlSQzwlLfDdQONDa1bh7YnDYU5E1hCrB+pIStNEyEuu9DElt31C7udkGEidiu2RGw5j4DQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAACE	1783582639746	{"key":"4cW1S1Ptwqto5oR+RWJN4blwyu9nJt4gg2TcUTKMzWk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"9a8aRZEZOlwna3RW5ljAkjgpVfAmIRf0IsFUv27+okl5O2PuMR1hTPaZ02NcSR6ywfCdZz3UD3b+mp4HgcUFBQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAACI	1783582639746	{"key":"z4nEPNOrur0wsrivcxTFUJ4KUblCK/7EowTcJ3M85w8","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"h3InTG+07fdoKZi6qiFP1kNxfDVKyBi6gWi1S1T1YLYL0d/PUcOLGiXyBGezMhBSKjup38GBuGTEGOTU2q5ADA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAACM	1783582639746	{"key":"ewUhlP22hjIGuKPGnC+oxaTpCpf3EyhSvW9SG9TCk04","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"XhAyddaF0JozKJUo2epeSN5Y8YrdF/0rI3DvZCCoZbU542PulND1xD5oq6Zxqgu3rDJ07cLWZ37Hc9/JKHhBBg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAACQ	1783582639746	{"key":"2H2XM+56HejcqAQnXGi++q2PFxYzGL9+Kx6wWX/Vq2k","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"cmDKGBP5OwOkPvY1zWa7a26G3HMzHGIRftqmthucPCctn3ijSe25WBB/Zv6ngI/cpHgeH1dqRjKPo+VHxsbLCQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAACU	1783582639746	{"key":"tnNaYzpw0Pll5sVAnGPg5gPUAlgxM3ySaPSz8+mbGh4","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"E0ESdYm9VOg00yv3B/tb673RANGkt+OwGIomYuj+h7hijLAZTgJORCwwuVDDv2A4iODfWbgIRqZkHtHQD5bGCw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAACY	1783582639746	{"key":"eDfVMIDLr2WdmR/YIWttiKEIqzk0R0KgrXv9459Vl3c","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"Tn/ErktRIUJszbreIISjP7Whup8NwpRZlY9R/08U2MvyaOLwLAHyvujxwru6u3UeBxGjN9KErJH9tJeSUs8PDw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAACc	1783582639746	{"key":"qNSY8oJ2QVi+oMEGUoPF0m67l9o3EcenlDmzIp/+Z2c","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"wrGYjR0gAVuvpmlwNkkfnXTktpQDzLOXHuCl9pOUlVmO8+R/NCsYEFB+mMx+NGX94WtFEkTeVy6VYbFdwqpBCw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAACg	1783582639746	{"key":"Hxf7KM0on6w3dX7yKhxx+4aoLc9sJS26zQKUfRhJFhk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"hgg/+VrkE6MMnzvt6CQ5zZ+0HH1o43cV4TH3AsmR3rEBF9/Ttt7nI0JNpX1N7kEf0ZAT4+8oN/OSfaUhhHwOAg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAACk	1783582639746	{"key":"q1+wNqvPtWPyMhk/m64zbn4uLxkglXoeUXaNPYSdPgE","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"+ZOs5ZNJXNLijxQpCpD9Hv7JZRZ8Bc+5TUTunL4eEB0KwIUrLfTKYiJuGBcj/mWTAIwcHy4h3JWIH18YFtReBQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAACo	1783582639746	{"key":"fU0L1EO7FVaYZHCc0pntSqBZZwIqa3EHkHzD/4aovH0","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"s8w6+Bd5QaJKqUh8QfHpMhGwRN4YRTLas/n8ZJeQqkUExhvc3zPAJvdkKRh9MzWpoF/1uAwh4yW8N702axRFAQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAACs	1783582639746	{"key":"aWTSx/dX5g6HDVvKWdzyX9V0O2ZumF8j2c5HwGuOKHQ","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"K8k3wM6vJ7kcTuL4vt8EzYVW7S6MfG2qRi5Jtl3E8AIA1ASWlNo4cIDlj3lSDzJD6v22V5WMtb+4C1W9PGNCBg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAACw	1783582639746	{"key":"BXDAU3KMLNv+u8h5dlSd2rvcEfppXVTN03U0vMtDmWg","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"/2+9s/SmoO+7KMBqUdTa/D93Bx+USgG0kimnseKM0AVBHbvfWp7nvpHbKIVHjszIap9slQ0jObwVp9OndTtxBg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAADA	1783582639746	{"key":"qOIh4PPQG/c2bY7zkNo0aGgQm1ZBV975VHyEiBzc4S4","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"hvbdQpR5xFiFYJ+Ppi67tHjiIh+dUiMwGRsbj2BU/1lVm1JYxCxQrmWx6uV+1yb4CUmu20HhfAjNUkY70inPCg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAD0	1783582640111	{"key":"vFTeUAKuBG/E3TrPJ8RmB5PA2Yk/ET+0Y+9Qa2A3XS4","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"+BG4b8Fh43JgVGuLD/vDNqYOr1ilt1MtMe+TS6rE4Ej31wEDSOcWzTqyXieugB1O3A1W1PqRAG2mWxYQZz6SDg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAD4	1783582640111	{"key":"+eh+dUJgWvs79ZqgkAWCrrSt5kMTFfZmGKjnEDtZdjU","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"lJqffi3uThfyt3W8pPHbuUyXuLewFMLC9wd+5CReFGoPmyYXCR7vDCQvY5u/Lv6siRsHWeAGYQq9bMhDBAU+BA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAD8	1783582640111	{"key":"KrTHqHdg5xZc3yBA5i3Hy4klade6GUwlugva0PJ8/T4","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"Vo7IEQt4C9vk6PHJw1uHMTYu8B2ZNdl7vdvdp94ZV+ofg3hGv/1tbvP2r0lg9G8r7TKdXCpNca7iKeb1nVbiAw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAADI	1783582640111	{"key":"iSTISYzdPZ4lbHn/eFOBphlyoS51k4jlhan6HIXg7yU","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"7i/d4H8mdkSuQXvoHsldz1HmDNFbGlIJL6yS4RB6WE+2vtrRiMU7WsLTgs4uMfQ03eOxeOh0/QdojhM0+doqBQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAADM	1783582640111	{"key":"Qtkf31U+jIdpdMMDHmqlwl6wq5bUkeq8AeV6inmD3Qk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"IFdcUe8YxmQ2IZ8n+bp48FV4seZYnMHJ0chJIHTtQZhORAJP1EHoOzA7wYluts6izHpyvGXcxuECZc2MxBLjDA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAADQ	1783582640111	{"key":"oI7lPdkO7j/n7CE1wm6lSqE5yWZtISzep8FzkXtfpls","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"GtG2AsZyHcXeWXMCT0QWI4KVO3t1fmFDi2cBnrxeCxn7WMThXVhYGlV5FcyVFwdBDNmZjdtl9JPaADewXDv8Dw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAADU	1783582640111	{"key":"p2UK5r+DREBVufxvIrB8AGZ8pnDl6Ahuqlz25bM3Mxo","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"H16KBQuODOkyKo0E0/xC5fQSdRE24kBtMw0vjVGv/5lvtG95lZpwPkYOWmWXH43NMo/OrzrelrfcyBufjNGyCA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAADY	1783582640111	{"key":"vt8uSNoSv28+k1PoiDzuZ01DUtMHHIkbqI/ReXDBgh4","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"rrbph9nAoARefQ5VD7xqFPyijuQP+u41XEmpwiPEph3sd5hhIBdTColzRiZ08UeWNQSupBX4ghBLbaUERPVaCA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAADc	1783582640111	{"key":"CtJKRUDjRy73UwzmlupQuNOr7WlKF4ZfaVNo9NQQjXI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"LPeXkVYxQDLHAtRUWS/hYyM1Lft4zFf9ha7GC6wRvSDatcMa5KQD6rSssiWw/KNof05kHo5+bHhgS8fvA9Q+AA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAADg	1783582640111	{"key":"0tlXWn5v2bK5XmLMQ73EbPHAQWCDfKuSGzVMIrQs2h0","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"wWvXHTW9iajOnfHivbSkvV6gmYN5L2bD6kMXoke36mDHODmHu3O/Rj+XmDRxrTnAe+bHDW6KOJVgWsD2m8FlBg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAADk	1783582640111	{"key":"Nxqa2frWsbzKMbW5bZQfj9bzZFYXUqLFgby+jasun0c","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"eumfFU5D+9PrXMHQGndf+YQabDJM7C7K4NDAF36XNMW4gv2D84E81QXqKqVeZEktW5XSGPCUAmYcy7/3w9DWAA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAADo	1783582640111	{"key":"s+TTzYevYc9DWvRgWcfVLRXosY3ePEQ7TfClDzGnBwA","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"IOpy6lTSp0W4tvW5F9n5ZqEjUIWflCdhFeM9kD8ex+TMZsiwXbhDkfI0t0a2ooDnCLqCPeBpNcEtbleSqq9JAQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAADs	1783582640111	{"key":"OyrTkx9wTWQwg2eBm/KUn7BfSB8Z9/44ygTNWEXqBm0","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"hXsgtLmAizn0elh5ICRrUX4/NecpVacRnl48cTAob5SIxZy6F0Nwe6+HddPTRpCnPJ4mBW/WOAPjm6MCY8SyDg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAADw	1783582640111	{"key":"pz1RSUQXu2qnB/YyYztASR9Nzjr2/pGRdxvPr8jwIxY","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"NdCNuBUr/zXufH6UgGC9Pype/r3GVk16auLsAHjDN9TDFeyWe6Sh3ZfCXfAcMg3WVio5JhxZzJu/zLPtgOfjCw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAE0	1783582640111	{"key":"E5jHdWQqDHD6yYeSnO4GAukxoSe8VpGhQOQ6l7PRTWw","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"nq7Kc7qmmDE3y+2P+g+f+drQuTTqUtf+ycaQoc777/tEB/NaxUPH+MyiW1mhO+6fYtTJiKn8p7koLa6WfgYkAQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAE4	1783582640111	{"key":"Wi98UZfX7dEQvEqc20bwflz513LX0dcMy4EABhXXYmM","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"9UVgnN+712PK/9wjEwz5QHPuXPOaA2o02aH/Plmv0BXovoCMa9NmTJ/0QzkxLhX5zM6UnXRSP1fZStgS0RoUBg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAE8	1783582640111	{"key":"LRQH4RK5dc8es3h6bw1dYjA3nuHvC+QhBYkvqeHmGwI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"LxH5omdNu5lO78P93OP+4CiG6bkK1NfZ+8jUv+WFYqBMXK+5i7k7GRyd1dYpw4Nl1/A1yFcEw90RYdGV68iMDQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAEA	1783582640111	{"key":"Diqk44tFYsXqn1MeEjFnj3af7a6AH/gM7PAQf8VyKng","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"JNu0+kGZRl77f2ZaEE3F3RgMpYKe4tbgfJGSW21EeGTHi0rdwSJm8R+2X83a8Y7LNFwfDaBPTISSCBb2u8ZkAg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAEE	1783582640111	{"key":"rJ14DoXVhGi/faViR2KjAHKDQ5azGlyy8Vhlv32+XH4","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"tZiG9j4MalRgt4onUGVX94Js2H5cc3SaaxWlP7vv6hryw4boeIpNPM/bimsN9cemWWG4re3E06giWiLijiueCg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAEI	1783582640111	{"key":"gotw3Tk0HuCpW7O+r4ZhE/3KTnRDmjfX5e/vUo0eIjg","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"lozkfIhIK4L1Sc8TOOfjhFyKBxviMo8i7HYaHaNEPa5ZYvWZQm3iNoypE8JO4gA5SYNHVrkgGwKl2j05hdCuAw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAEM	1783582640111	{"key":"7iOTBPfgepcW9sfsFvlO9wzysMUHeNAttUNr3gg6YEk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"TrIEZXaxXCBd9SXzoqeMBSvdT72pI0vbYNkwwA68sIwr+tRrEDXXQWuv0xlDexHZRbOwimMbWXq9W7o1AmtlCQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAEQ	1783582640111	{"key":"kCRrPpKDy81bxi4bsNVQQQ3JsGdGAIiF4PslMpq3LhI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"xjITfcJwOWHG6Mg881Q8GlKMVi9QjLGzadi9a+gTv+vjnlzpZIMsUQ8/QW+AxtWwKRdrr8vSi0t43yzkh/lnAw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAEU	1783582640111	{"key":"mDHaRLfSIAqfjsMAtC4upSLKxadKhWWbu4WzMv0jSiI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"O8UJGoHvIXikyUzRZSaZTDEkuSk8uOoWJLi5VHvYmblHvblduDGAxYD+TeT4qRzITh+7LB4X45VJRBxUUUjTDw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAEY	1783582640111	{"key":"xunjZFDo/4aMwuEnoHEdthl5O3ZWr5Z1TXcp6dvvZgU","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"PGuRaVxliUJ3OLrNJ8kzdJXCP8D+EGpGygLAW91uwHUuoK6xKKi0Ss9OyxjH3CPn27mrPko3Zk4j/M/pdn2oCA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAEc	1783582640111	{"key":"H+Uu1zU/JiDfSxygvPcFHKiHdcNbetqfndHDUXozjUU","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"zFzl1YFaaJLAemGI+wXnSmJCsY0sPhm157hZMQIWEnpsGbYVk8r083/lXRQg00PKzTAeq2va38IvGiszRlvEDA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAEg	1783582640111	{"key":"9KmlC/Ah3XoBZlbNCfwtPqe6lTKVLJeJPvaEwtmXNj8","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"8e3KSTJMe3IFjJiIRSlaUo8nOP7jS5xdq+/DrdbnGO3nI6vXVImlIyMHFF03TKJr8zK1+ilebzWMkwsxH7O3Bw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAEk	1783582640111	{"key":"cDqIVPsoYEFKe4HaRliPBQ/6f0nrNVX7JlRHzU1WW1E","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"M74QNRaAhYeEPb2WQaqD7sIToNJIMUJqED2W+qVWm/Ms2mtmlktxyE1Wf0A52LMBfQHEXFPQZRvF+5fku+VCAQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAEo	1783582640111	{"key":"F9n6IniC7Fs6WBQNRixuzICrAMhYACcmeESjShSw3Rk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"doy2NY24aqYCNWxkSeIpQyQNoB2Fq4b4LV+aE7YKLY3CyBDu8fl0OWC9aSqa7WYQczFByPsK7LhifZOQwfcvAw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAEs	1783582640111	{"key":"crX1h3NYPTCPxg10tPbxx43TPQHm5xXx5r+ObfYBFQ4","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"OzF1SBKdxADQ83bmYSTI6As8lWiHTz+e3T7tJQSK3dWbzW7XN+ZT8a6UPTK5HU2cswMu/jE+D2D/txfVt1c9Bw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAEw	1783582640111	{"key":"r5/fMt006rG6eWn3BPtDGHnKzrNn/lJzF8LiVwt3pSw","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"2SZOypLSSfShDHacRxsvqzpxTX2p/iqKVYv0JRJSnfFSrMxxFQoA8Zn2s5QX46cY9L2UOtEmqyoLyriGntJmDQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAF0	1783582640111	{"key":"eVnsGA5dDjcDQO90y0H5+2upzXwgxe9TyvMqbJn5YTI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"S28Tp9yfmBZ6PZ/W05MRzY0Tm/LVJG/nXKoMWxHzUKEoiK7KpOKoRnorfLT1Rd4jegHMDhcirb9f67Dw5fjrBQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAF4	1783582640111	{"key":"o84jauJaknqqf2dnMDaUo3xAQMqR/7LlFmdXCNMjLkE","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"IPu7PmnFY0dt5+/Ntq9cbjTBCNA0NKtrmcv+oXBE3Wz/FgBeB+2IgTg4ierZLNgl8TcZHJWQM8yNeo/mEGsTAg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAF8	1783582640111	{"key":"oBxJ3b8wClPfRSMRMH3qytoOFf6+lftD4XXrRC7IYjI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"KCRLC5tA4n1n7oTt5lJYF9x/txdChFH7aPZbU4owX+52htqJCsNB1Qiw9mLljGhtSWzXWLyhK29FvHed5xoWAg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAFA	1783582640111	{"key":"TltpJAzwwaSD4VhvjOjuZ0p1YPplS48XnaPCmfFCADU","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"WQjwwHK2FB4tPrNg/CEJNZeRlzN9PZEPmtVnTqdob7Hb/F61nrr6zx3CZ1QIn4ss04gvvZrsruhkgkzpsK8tBg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAFE	1783582640111	{"key":"1sKK6mbS3IwalFOaT7pWv1PThjXn1bm3S41KnsCtfSU","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"NXIP8GFeR6qKzJzseisC3F+T4gCwkGi1NnKJ6xEt1E+IJwbmnqa6/sxR0fTk95R04Ya6oMdKS/Uoc6fNCCeuDA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAFI	1783582640111	{"key":"jSgdkf03+M27Kp2CYUXbKNBD6oZE+4umb/mFeelpYSI","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"d2aV830+gdlOigPBkwch9qyEpO/QfVklEXxa7E6XUpoviBzu8qEkHc5NspOWo4X44juQ4y6ePOv2X79z/uD3Ag"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAFM	1783582640111	{"key":"+Bo4/ZuNCsmNkDrXnOwnNfROnNyCKEGGweCVHUdtMjk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"hSaxga+XS/IIK+lYSn3sTWMUsS2Qbmivjj9BY+9ePFdRCaeajtZE9sZFC8Qoa/ZM36oFLk+zd/yP1y94QBoWAw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAFQ	1783582640111	{"key":"xgaWwUtIl//0jnkeo8wH8XTzX7qrNUCUtpeFVLmG2Sk","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"x62XhzFy9R6vcuu9NN6hO8DdMduLyAwNaAdsE0+7KDWRXrkBri8vmPUR6NrbRk5haJ3nHBX4H2BpE1jwEz8HBQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAFU	1783582640111	{"key":"Qlqu5Q/IYR3xhCDSURlBx11H9YqOeESJgsovvOlNPm4","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"Sj/jYUvoONHeOK74FfseUGr+OOOX71ealCJzXm0sV+Ywum1vJk4vE/J2PXNhNmXiOO1EmaE6PX0m0ELRKe9dDA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAFY	1783582640111	{"key":"DfWbmrEQDqX5zZ4QVKkEyzm/uOMsPxFiHK7dkINhG2k","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"Ic2NuDjGIRng8wexLVUB7J3jjBaYEpMe/6GJdMyKYkiVhOnELhEiOAt3tjxD2QagaaFvZQhZak8WDboS33s0Ag"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAFc	1783582640111	{"key":"eGEWgtpviS20KIhbZZKnTGRIJpiupPq1aj0YXniXrBM","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"bCisay4SDe9te16ACsWoguxHJKxyNEsTA9NfC2x3ZNeEui9l9DPdZK0wKSKG7kPLvLl9KZeJ7wX1FHwuLBybCg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAFg	1783582640111	{"key":"tl4Y8ZotiBVZO24SWdOLZzl2q5aolMfvzBMsc1S2Kl0","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"qAfe+NYy4VyKCtaTUrp0p7O6DrgB9+XKUNA8lJAlahYxYroXhX1FT/kILUKBMXWRopfnourybBffVTWCdve9CQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAFk	1783582640111	{"key":"One7Gm7ZRYboIDGMWfFhWnm+bxcsVEk/DIe0h4A9aic","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"eERS2oiw1LQH5APvDLSrMqJxfU+XWStYZS0CJNjdZXSBwekyRnkG1I/i66X8rUwkuAcjUiV4Vkj5GEticsTGBA"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAFo	1783582640111	{"key":"00f5PF9TQ21Tekt4ZOu7fhGsTan+A4r2x0bRnsAMwyc","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"nqkmKcZjUt7FttQlBjvrmfg7A6igSL3uXDJXbf1aypBC+jM53aJYMDo6qLYOQwuUwtXVI0fM1y/ojmb+m3fOAQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAFs	1783582640111	{"key":"w+55JPsqd8svErdoKohbfLkVbTT6gNRnWRjaWvIDcmU","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"e1HS3K3k1oJGfe7x2x/sbx3PWY+KfC0XPREcoX8Jz6lsiWhXWbG0ErFOCc5lC4OvtxejTwVsVDA/N5dXbN1xDw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAFw	1783582640111	{"key":"+g8t107Pchi3S1zf1T8YYzwPp1k36p+i95KNAVrOBTc","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"ZEpm27syfJGmH3Nnhj6h/ngJPm/prlolyMMLn5VeaIgmyCVVp/BC02ozBkrbrV/XvSIapjttjm+O7M95RwTqAQ"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAGA	1783582640111	{"key":"HG0uz63LcBVGQnj5EZfgX9bibN8Q9PbDVpzmYSHH/h4","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"7BJJMEEl3PQ1dWibc8/QawEFniZjzmIkr1Y1NXsAXudedRn+M0q0Wi4nCdFU2K7rTLcHgqLEk7irlvQLauMRBw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAGE	1783582640111	{"key":"I30XpOpd+GThJj6njU42y4eVl37qpAYhGyLZOFGIOBY","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"BYfSiYefGlvSrFZxEBUvfc9/GkXk81UchHR4Cif5x9LLF79UIiGCy9SZdx9hrF2UgEJc2IeRnLWd/AZKYC4wBg"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAGI	1783582640111	{"key":"+Rhswe07HqdodF8Z8Hycd4X5HaLj2Abmv+IGEMPuNS0","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"w/ABcxf/ZBY9a9Sk9rlx5EKq2wrAMRRXdD4GnVxXCrecA/Oq/fZV8FQgMxmGi822GT1wXXgaFbU4CpEb4ou5Aw"}}}
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	signed_curve25519	AAAAAAAAAGM	1783582640111	{"key":"UAMUx0BAXYh8R9FeUXfM7MzUQp6DDnSiIIIsTUl7fHU","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:NBQWFWVCQE":"ACIGJ9FbnA4gwrdQe+SmGPw99MRknNvl3Hy5V+OXl2IyQ8UlQEzQM2Cln7q6fz7GUKu9ZaqWH9Ms5Qkg5xOPCg"}}}
\.


--
-- Data for Name: e2e_room_keys; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.e2e_room_keys (user_id, room_id, session_id, version, first_message_index, forwarded_count, is_verified, session_data) FROM stdin;
@alextaylor:shikpooshaan.ir	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	WnM1NCwmnV0tP+kTI0iQseIxaBRagTRRj/SwS+I6Sb8	1	0	0	f	{"ephemeral":"QJkrxWjtKQHrN8cNjzxXkE0UhssiwRUrSWYzh7txn3M","ciphertext":"JHHaYiVqC8Vfr04erdGXl1PNqgahZ6V01L0JAlPsHCJID5HssdUsg8LGy2zGKOZI+KoN+P13R12Fkt1/LsMqKt1pLUYJlWfjth/F+IM2kx0Yn0JmM1ZWUgtnSTe3TYxNrJkMsGXTo5VgishokqTkHcusqPX6N8bOYFzh2/RSkcP1IeDRmcJIzrScpJcVbgd6yP+f/7QRcv4SFiIIM26XJeAP450jCTbFZokU3waDyr86zSTpgGi0wgO74+H6HzhOElNDoX3HeVogrHe4V68dzKVPzKVsrjQmi4U1XkzCwyFBMrvyh1vDH3NvQxZppUvtfoUU/lUNgPvq9/+hZjtEiqfYsLJTgKfLOHbBts5bURPOtO/Z93PUJjmFjzIuNmMFiqgh/BL4KGrR9LGQYKk2EsfdFr7lIoazgnWH5qj0GVQthBAAnTblDhsitmfRmPVgcbIPxR1S8+PCZXBlcQKH4ibToraIO9n0Gn6FVu5RrdhhPSIRylETLGCJkn8rvl5h5hYjwdGK/3xfJp8YYGmNBXMdFYzsCaZND3PqIBBgw7JhKegy3gNp1rNSgDIjaCK9UME2+fOCnXMMEuck+uQ7XLg8/CPpl5rnqNjg5rtdQI8FIyWN81faE0PLIKQWBm8U","mac":"2ZG/uE9Exmg"}
@alextaylor:shikpooshaan.ir	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	3JHMg+JwZIyJd9w/iSODrj6aqUBINZHFt4B07w5rtbY	1	0	0	f	{"ciphertext":"Hx2f04bCuJxmRcRpvtF4oHjpZdxLVK8qf1hCZFALnF1npEYJvvMvm8+UDDJNLXkMU041gvkF5WGucJgRCR7dNmJXj5slTq/jUr4WQtIjpLzPVf9aJX/gtPfEQDftHvQi7A9T9LSQwFbDxeVp0xMB82yvBN8XUIKvO+kUtbs4i4jZp4HAO+4jsIyQVYVYCKMjRxj9Ql/ZOZSjOCfGRUKBOe5L0e+EJ21daF/hIxRDx/7k3DsWSuBTUIYTG0nLOdXd7rF9lvJ4kPJxyNb07xCIChs0zCjgM5poUetstMDagJLU3VNXN0spyboeF/fWGOR6KdrhoSoPoKqbGmPrDdcWStF0sSBN/AQgGUCExcc84r7ezJF1bwZY2od2WiO4OvrKZ8Wza+dnmvft/ufPyF1X1e92LIqlio4TAcuMMT29iIU0p64wLfZGnnBWHJTdhNbBH/4YE6Om1n0EEhQ66PhYxZIXCee39VermjKGGwcfkvKW8P8HaUoSNNLCZpEmS8hRvXUwSyJrhz2PNnLin6b+5U0fbaDd8aggJ0ZEpw1lM49dJS64CqVJNfdvmJwqXjEreeRFNvmERdkqBjebOWjcmjgda9wkd/FLNuJyknPC0FjKs2xO+D3HeyLjrAct4jRW","ephemeral":"rlxqanJLh+iwRATUY6qHloVKC53NTaqrJ6mqW/EVEjA","mac":"Gs7AWGA6VDE"}
@alextaylor:shikpooshaan.ir	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	AR5wwfQ0rLe1NKsbpMVDKvXaxPbo5AWHMkFGoyhkQoM	1	0	0	f	{"ciphertext":"wDPHv9HqurK3i50LgPH40aTugdtFQ/iJH8Yv815EatvIT61nSMZtrN//majem3JCw0Tdo9Y4DgmEI/r+0GKbFLs0mW0heBnVFpyd6zYb3S2SPFMYEN0XXPfnSdcboXs7dHz8W7NTPCozKCZdDpsOksnQQLgt7ojDZkzyudrdCGZWkx9ZZXbf1P+lp9ucmi8RpqBjH5yKFuFdQHX6t5kFcAdyEJ1aH1P6PzQ8P9her4rBT7R0nQ8QAeUP9EOJ3YF7K9JbOY/JCYQsdY27afVmN/ixFTFoo1/uuuxaIY/tYuLDNjFn0SZBORZ9SLjeilS50OaLE9bI0JZvUB2Q7ptdv5AEfnkIeVaGV+QXViJBL+owm8G7Z5hwXN1rrSEWPNsgL1k1wXGavPZV09j7aebGZ3gUtJuq2ER+nEgUlSSLhNbpWpL/xhQ7RaGe+ud11OmemSMvIu2zG4qCupy4jiQaelDwNdtDUQ0pCISzCAZL0V7y2My23I1rRTm/jZUT6/GyMj50p2IGuPWbJKrokwWFnZPT+n1zA217BVrYD1EJCeL69e/KYMGj2Xu9TCMx7wQ3Bnpv0XgJ2P7WMGjv/DeNv5SUysNyhPEyt7zTj3BrKvdZZRUbLGrwggKtZh58DAAp","ephemeral":"E5DmD+AXy3Ba/Q15oQqqHmq2uBeG1rWwnkgA6ijkuXE","mac":"4SlnhluGADw"}
@ali:shikpooshaan.ir	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	AR5wwfQ0rLe1NKsbpMVDKvXaxPbo5AWHMkFGoyhkQoM	1	0	0	f	{"ephemeral":"79oP3R4GAYHskd/U9IgraLsoNwTNNm97e6lw3gqcaDc","ciphertext":"WYAJKtwGY2lFi8IeerYO/KOsHPa6FxvUdHuYCg4AjPtLCgVFTZdMbmyCAR4GJZX5JTJzFPyXqKJiROY9cqB+u5Eh4dd1MOlnSqQOYcFAqGRTYPt5knZxKVNPiN0QoK0ZuJZg4uyDsCWMt3rBybmHIn3Q9raaoeT54Bn3nBAekKsNqzxghtzX/EudPX9ItfeP1J+k/so8ZocI3r7XY/gr9dxqcMmAXQuspBI4usXq8SzY91uKWFnkjFGFWwbcX1+3ZgCQpx5NYi8jiowVpbRcGjUn0HFX0lNMs+lqAS5GbwzEWXIXNKVXZvR9/S0Nw8pChyrHZhvzN0XFHUD8/ik6Xy/ykvPArQd64gkIOSyyDWYsASE869RzJhDgWAB5zWRIv0ttFZ472/929QitA+RAjAt62JYulQaxUfFJMf74gqPurJcLEVNSZetYWW2Y9L1V/L2Ex8rOiVAWufL4CQJeb1hvH5Ow5wL7aRF0AW0APSZ6gA3cepAsBvGyhHq+XXVJ9rw+ZCE6s318PWGlkIrvD2wP1qCv2yhg8LIFk6yPm1u3B4swkONxbxUKYDivdrIvpXSp/MJeKqZzz7WyxXzVseFicjRKQOuBPelAiKUjvSMlwSH+2Pq6JbYAudoGmewn","mac":"F7lP+BT6vSM"}
@ali:shikpooshaan.ir	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	OVcnfa2LhQPYIa2Hww1gJ/GX40gN5A2EX82jbcjALa0	1	0	0	f	{"ephemeral":"X73jWR7yNR4HfQt19DNNVQUv/vJPUEpnHGHu4f7/2Hg","ciphertext":"GHWrZNz0R84cfVJVcKTcbF9OxiLNllHkmKZJwtp24nxvl/6eA2A7I5WjbWeA4gvL5CmgSWdGYZ8gMZSbcoGj06gjYztHAWmnV74JZZSoYPjprSBCvgsGSE6qMDztlGjOBKxSuxpwZF0OtmvoRDjgpFA9O/74Xr+roe/9Boa8R9UErurNjD3ZmL62N/otuGd0oay1LZ1oWf3rqVae1jwH0YEPakQPmAMOgIi8ax8w+te8NuxQVefxdVzwcCXPbLWicQ+4MvqxXxX98KGkbt7kqELlxYZQndyPIDsJ54nz45h+pYQ940OtPZOu8N7iY1dDY3XxZtgttdKpd3Iw0XsNPeK7FhsNdquTexmso6HFem/512+thCflc5SAj0uEPvRzI7NSicgd7CVqoXJjYwQ9sXjLKhJBY5WOqMb1eCm1jUfDX9edlq3C5wYL2IZ6Ib9AuxTtyodSrcbT8etEu+pIL/0fuysWtElUEpMB3Q4H7HdUaGTKlOxu8uacEUWL9qPAh+/+jL7iyLuCls3VYqu6/E5BDtRwGcHGIzRXlWHKFV59n60pIrzCH8zUQC5sxXGAVZTDur99S6RcLBWjb8pZT7HD32PyPzEhlyiniM8SQtC3NcmeyxmUEBtzNPuR6vlV","mac":"Mam7dQG4mj8"}
@alextaylor:shikpooshaan.ir	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	OVcnfa2LhQPYIa2Hww1gJ/GX40gN5A2EX82jbcjALa0	1	0	0	f	{"ciphertext":"ikGHDvH6+Z1s8z4PIWgLPsmvbQWGK1EMuxlegbeayWD+6Nsj+zEOD4gitLemB0o4hDvc/F3z24+BliquKlBhHR+D8FKb1xWjyd6EW7AUOiaoB9Z/VA4/3tdUqhqzZwuj8rwm5iSncNv086L2Uso+NoCHhFOixCcKh+YkNzEaLVQkTyIuXQCU5mBDz4jMLrspQbd9edIKOWCqPy9e12TmZqTeeqG5G0RQXL7LuH4HyLunCAcT8mUGPbUAVME/VUNmmqoYuNqbRQAUt3vzvoBqCkWe55XiBNDkPcwzGpp+83bKU4JfLfuyw78LzG6bq5e35yUtT5tQHoxJ77hs0wd4Q1BNzeg8e0+vDN1y5uXK+XJ4OPbWFhSMrls+86kiSpxM8CqJTYSV/PPZxEmCQLjauQC55TBX/zcZ0wFD9gKgUMQtz6G7Y4AhDYBEkLoVrfRSBqH9s9RCR/rr+UvByUsp3A/MvBuAIGnObuFExYwUh+tXNy1FhGf6qdePTP9FOdq9zCblY1jWm8WW+He6MhkXawADGtc5HMOdVd6m1p9LaTsQMZQO84Kosbll/XoxQXP5Wno7gCpZtbMmOUvJwUIZxc7USfFIGNPubjEXRFlM+AQXyesb8eMA2VGvxFcdePRQ","ephemeral":"CZ1fR4Oiob8hTB83eymXmc4q8ml/Cg7bqspODI+m5GQ","mac":"RTjKsohXkAg"}
@alextaylor:shikpooshaan.ir	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	pUV3Ial9uQxjZZB2MW7oTIz8ANH6a9pc5+MBQLGlT+k	1	0	0	f	{"ephemeral":"T50TBAG7wFFKW9jxgBLca4n3cO5WP0Z/K2U21SRrWQk","ciphertext":"/m/1+wdRlLYanYx+/zdy3lzUJNcsT7lL2gtDZIMq4Ozsr0zNnKgDkPbGIfivYVuyNJUKFTIpZH2KDHK2fZ602+WKlzs87yStcJoDF+DSQ7aIjV13NzT3LVdJ4+GStT62L1aZ0EC1pOKNhnvuiNwfbqQ+ZwSRYMvZ/g3Kc7daf5j0/tB7PWG1SvLjQq/ACovaY5lQFEa+KMzVkHwBOH4/19QQsYsF/vQM7pn2o+XTmQwqcEkls24ScyYlRC2GGQJgLsXrdoWtVqXegiIzweTKbjUpoCgiZH09o+Zy7hB1kWNmC8bfYyGPo164uv8TC53Fl7p9QvJWS5YkFHxqWO38rMDwy6xFUdv0j/vCN9DrYis4OtzUJNF5nnHK6IYAzV8Be996SRAIsoc0o+v4Iq+DZqHzOREGCNPSUXN5sixJ0mD+/7kMVAH08fUbRjNhVwSrNEWme+opuI2CcCMYKpoMbZhHB0tTtjfbK92IXcCfo4OzEIQQ8vBMxxuKOL/l25YQpvzCcSgA8T8Q4XwpfEtocD/KaGmjn0iqEAgsaiANA5byUTgEbdxChWry9UIrVh6neQOQfxdde98otPky7jdBdm5fAkfs9CGNfcAJFgfsnMCxMHAz6iOhfR9r9eLcfmSt","mac":"wnMEXCSGJtQ"}
@ali:shikpooshaan.ir	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	pUV3Ial9uQxjZZB2MW7oTIz8ANH6a9pc5+MBQLGlT+k	1	0	0	f	{"ephemeral":"cpDTUX8+6DcBUD4l6BIEXdUZDyQcV3S5oOPC+z9KyQw","ciphertext":"urSLzr6f3ShDBKiYvEXrF9RSKthE8Xdc6pQKx+AT0b5o54IFoFrAJlHctpqgNJyHWwUdgETNmsNRaUWAH6NTDYIBFjcUalEABHdvTWhoRAdxDW/o26hey8JKPlCQN1MCTxWUGaThg9ksody7Of4VYn9XEvMb8HowSiPCSaiXgVDgDnCiKZigntDxatSxnVaYgLGbdUqH8WtL9ORl3UzhxSNjLKTOEvJsj7OHn6alTQ1Yc56/Bc+/ZioBQn/o5VE3BoN35sExDtCCi5AYSN9d7C3f5CQr6W8jgz8w+otxenYG2KMxCFIsYO2fBQYRCp7mqyj8/eRNZVHNZR8vwO8Oz6Cci8uPB0GLWKux8xa55gwN5g0absnid2vCxWHQqqg5WqROrR/NTJFOICkf/nBIqDHUbqIXGs8vlofTpmfb/J3z1SeHWuegvNAzhucu4VcuWl98i/oDTloa1SZv95ITp3tAbgVM5wI03EndwxxAefYxB5fdS2PIJ7+o4do+RXUw5/h9kneHwrXCa0Tv/v6MStBTWND6C2SJb/4e8gtU9F8GHwLVyq8EdCcr1GN0AqbCPHbWEOnjCRydhAIgkgpuY2NDMfIU001Z3VQT1scytdBW7Kc265iXlEbKZ1sH6J0k","mac":"4GSAnGKwMNY"}
@alextaylor:shikpooshaan.ir	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	YqZXWKUPQsFGfn7cohF69Ga2xup8NCxx5P7BbAccocw	1	0	0	f	{"ephemeral":"AXcNNmtNujvv6qtIKaP1pf4dbV6Zu88pJvq7O+OldCA","ciphertext":"knL9ZdB247KldUd60xSgta+5rLcQ1d8qIQvBQkoD5aNUB+JHSK6hgrQMuuKdJEW4lg9sRTyBueZbsuLuayjc+eN9edOfgZ3JTg3wTBbMaS++noWZF8B1NtUi2ZeQN32bsUMGeTzIxRWYs4C+zkoQ5u/17GTO0+iFEfkHICzSHYttTr+k4OIM73ZDRBLm0GoQnHxIlt/75ZEGH3hLiCzUFani8ox6dWV/gqP0AuHrhv/GnaWdTHIyf5f8fusk9sQeqNM/N/QN1+14xK94L7SlkIwJIPC+PMEVr0+j6JzKTWVrRh3JFMRJTSd0Vb9WYQbpg0wiNO1Gi5Gn1CPGA4cYKTDloXfhbS21e9rMyOTaSUkVXfXyD3JQfOpNHGXEMZSlm0cHfxYfL6/2r3gagStkKtmpti6J6RhdJIDdJ/1V0+X+1KoKKaeUdFr3zMRcxIsf8566SddL++wioEcdKbcYnJPs4MEXLUB6qdCv+9zk/r/SoxzlKlnaqYNICNPxOBV1/I9skRRnfu+YKrsw7nBIaeTBQwwz1SCV5W9UENvoOrkGG/+9pz70SVrmHf4eDH8xt+kKt/ZyxJqq7ORW1Q2hYgrV4jP5cBHGifnEtREYHxoJB5HxL1gLoegtW8DP6FW2","mac":"V8HXsEXnb4k"}
@ali:shikpooshaan.ir	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	YqZXWKUPQsFGfn7cohF69Ga2xup8NCxx5P7BbAccocw	1	0	0	f	{"ephemeral":"7BCHy4FZPcmzbgGolKLOlTKdAa9QhwoGrhP7MgT7Q20","ciphertext":"rDCU9Yte2OAD6/+/n9figdZeWYHm2NAO25Js4BVUSuK4sMlQrRIan2VPIn5sEoxrHk5GdGjgx6Do77HoyDwnLUU1KEcmnbgbvhzQadiGUTycP5FDv3ylf8R4HokbbVmKKnRnUbBTToGsZYhNMTxzxnCa4eirSxm3voyiXRrjGDqwkTSyZ8IONPMeXK8GPFLMqshGZ1EDlM5AZN4WQImivzS8j+EhepNzEAI6haRA+/LbrJzfGn1pKkGBjokU6JgreG8LEO2PqRFFXgftPDIySqV5LauULfJpeO16LHj3y7B0rBIyikaiuhjCY5qnu0EK0lpmDUd+oXje+7Mq4rMWcfdHaLN17pt0W6tIVFdmJF/m5KsB98KTkMmmT/NJzOApy+C3cZaOOUUt4YXmd06SRitMdMY+PaeDqdpVBk08fzSNV3xWcU1nKLkwwFLFLVYS4wIPs7H1fcN+K84rbGyh6mF/+XOl4jWy/Ggrvm/SSESGLXfQtKOpfD8WTR4iiy9MVdxPl+C/lmZv6QN2bTxOQqT47IIeYY+163872c/xZQcFVlhQK8CnKnFNUxd6G4BT2LlfrasgVTjCL9V+6JE1sZPe5oAVYvxdahhGUwWmHqXqiwUcxXYPHgVI1rh/rSmm","mac":"XtPcc8PekQs"}
\.


--
-- Data for Name: e2e_room_keys_versions; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.e2e_room_keys_versions (user_id, version, algorithm, auth_data, deleted, etag) FROM stdin;
@alextaylor:shikpooshaan.ir	1	m.megolm_backup.v1.curve25519-aes-sha2	{"public_key":"dhoPoLW5tqOcoUjYg9DI5ovYAte0cEydNUbydB+lXgc","signatures":{"@alextaylor:shikpooshaan.ir":{"ed25519:HKTASTBOAS":"QdcJzfJ3A+JsqLVZebBkaIe1X4PTUIjl0i+FBotAV4Su+e4qtEoPYpf2G28ACtc6EyrNDLMdd77WPcd+/W5aDA","ed25519:nL5wwk5HfbsXyutol/z72QntD9yOvMf5lZUHGm9J4fc":"G6bOooZhzZyFtse7Sq9Ds8JDzXxd+8bhsMEwxVYomo9LH/E96O2q22mi3FGwdxKvmoWgyoM7/YZzMa1Ty95fCw"}}}	0	6
@ali:shikpooshaan.ir	1	m.megolm_backup.v1.curve25519-aes-sha2	{"public_key":"pYizVXgbYV7VC+6SthaCaTOcgUnahb+6Tebv+WanKik","signatures":{"@ali:shikpooshaan.ir":{"ed25519:AOKSEIYZIB":"I4TQktVLlbW1/uJwciRq37uDOHksmiTBTtlEImfDhvgDr4IN/Mggj9YDLkO27KTsDR6xiOTZVhwW4dklv47uAg","ed25519:kh8e9XwuXd/lSLjW2mcxNNvEFvx3ritwu9GaHDHiw54":"9M+ScCpnwQ6J+doP2yO08WFFDq58l0lqlYp1wZw7shyt3Q8mpXjSfNEMvIuSZdKs9ZXl61TkUzUZxuHPflNqAQ"}}}	0	4
\.


--
-- Data for Name: erased_users; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.erased_users (user_id) FROM stdin;
@testuser:shikpooshaan.ir
\.


--
-- Data for Name: event_auth; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_auth (event_id, auth_id, room_id) FROM stdin;
$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs	$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$ovWXMhcqZ51rR0-mmT_ebzrZ3c9XWpr256lElWATA5g	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$ovWXMhcqZ51rR0-mmT_ebzrZ3c9XWpr256lElWATA5g	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$ovWXMhcqZ51rR0-mmT_ebzrZ3c9XWpr256lElWATA5g	$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$aGYMEi1KO534ezshtH0n3_XRs3OZXgi_DY26XrWFLTE	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$aGYMEi1KO534ezshtH0n3_XRs3OZXgi_DY26XrWFLTE	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$aGYMEi1KO534ezshtH0n3_XRs3OZXgi_DY26XrWFLTE	$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$4WW-qYRENg7ChGX-khhMVKLO2asWf8I7EKJWgnuEnMI	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$4WW-qYRENg7ChGX-khhMVKLO2asWf8I7EKJWgnuEnMI	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$4WW-qYRENg7ChGX-khhMVKLO2asWf8I7EKJWgnuEnMI	$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$E97pMjZjzmrDM-hFyRwC6aqENPN3ixJigBn50-VhHEQ	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$E97pMjZjzmrDM-hFyRwC6aqENPN3ixJigBn50-VhHEQ	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$E97pMjZjzmrDM-hFyRwC6aqENPN3ixJigBn50-VhHEQ	$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$owPa_25ew4CsxHc1lZakZoynscO0PsDgfqWSWzt7GA0	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$owPa_25ew4CsxHc1lZakZoynscO0PsDgfqWSWzt7GA0	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$owPa_25ew4CsxHc1lZakZoynscO0PsDgfqWSWzt7GA0	$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8	$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8	$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM	$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM	$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM	$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4	$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4	$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g	$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$KSmWWmQkmzexNXwiaQhMG6Ec2JDmy7jmZgmlGyXySL8	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$KSmWWmQkmzexNXwiaQhMG6Ec2JDmy7jmZgmlGyXySL8	$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$KSmWWmQkmzexNXwiaQhMG6Ec2JDmy7jmZgmlGyXySL8	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$B-bfbB05RV8t1MKB6YKPsn7xa-KawJRYs-lLGP2CEDI	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$B-bfbB05RV8t1MKB6YKPsn7xa-KawJRYs-lLGP2CEDI	$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$B-bfbB05RV8t1MKB6YKPsn7xa-KawJRYs-lLGP2CEDI	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY	$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY	$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs	$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs	$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs	$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$9bQLGiDMN6cfZTQFKMEwuFSUDUIkIAELgVXodLQCCgg	$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$9bQLGiDMN6cfZTQFKMEwuFSUDUIkIAELgVXodLQCCgg	$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$9bQLGiDMN6cfZTQFKMEwuFSUDUIkIAELgVXodLQCCgg	$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$AM_7A_tNjjaTM9klUn_6ZPT43TZaWkerNTyPWRr1wWA	$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$AM_7A_tNjjaTM9klUn_6ZPT43TZaWkerNTyPWRr1wWA	$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$AM_7A_tNjjaTM9klUn_6ZPT43TZaWkerNTyPWRr1wWA	$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$q11DmpDEFKgMjbP76SMow-33zfL47mOYIebpAXwj7Yo	$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$q11DmpDEFKgMjbP76SMow-33zfL47mOYIebpAXwj7Yo	$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$q11DmpDEFKgMjbP76SMow-33zfL47mOYIebpAXwj7Yo	$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk	$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk	$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk	$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk	$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE	$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE	$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE	$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE	$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
\.


--
-- Data for Name: event_auth_chain_links; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_auth_chain_links (origin_chain_id, origin_sequence_number, target_chain_id, target_sequence_number) FROM stdin;
2	1	1	1
5	1	2	1
4	1	5	1
3	1	5	1
8	1	5	1
6	1	5	1
7	1	5	1
9	1	5	1
10	1	8	1
11	1	5	2
12	1	5	2
14	1	13	1
19	1	14	1
16	1	19	1
15	1	19	1
18	1	19	1
17	1	19	1
20	1	18	1
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
$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	1	1
$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	2	1
$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	5	1
$4WW-qYRENg7ChGX-khhMVKLO2asWf8I7EKJWgnuEnMI	4	1
$E97pMjZjzmrDM-hFyRwC6aqENPN3ixJigBn50-VhHEQ	3	1
$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs	8	1
$aGYMEi1KO534ezshtH0n3_XRs3OZXgi_DY26XrWFLTE	6	1
$ovWXMhcqZ51rR0-mmT_ebzrZ3c9XWpr256lElWATA5g	7	1
$owPa_25ew4CsxHc1lZakZoynscO0PsDgfqWSWzt7GA0	9	1
$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8	10	1
$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM	10	2
$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4	10	3
$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g	5	2
$KSmWWmQkmzexNXwiaQhMG6Ec2JDmy7jmZgmlGyXySL8	11	1
$B-bfbB05RV8t1MKB6YKPsn7xa-KawJRYs-lLGP2CEDI	12	1
$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ	13	1
$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	14	1
$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY	19	1
$9bQLGiDMN6cfZTQFKMEwuFSUDUIkIAELgVXodLQCCgg	16	1
$AM_7A_tNjjaTM9klUn_6ZPT43TZaWkerNTyPWRr1wWA	15	1
$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs	18	1
$q11DmpDEFKgMjbP76SMow-33zfL47mOYIebpAXwj7Yo	17	1
$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk	20	1
$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE	20	2
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
$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	\N	f
$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	\N	f
$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs	$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	\N	f
$ovWXMhcqZ51rR0-mmT_ebzrZ3c9XWpr256lElWATA5g	$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs	\N	f
$aGYMEi1KO534ezshtH0n3_XRs3OZXgi_DY26XrWFLTE	$ovWXMhcqZ51rR0-mmT_ebzrZ3c9XWpr256lElWATA5g	\N	f
$4WW-qYRENg7ChGX-khhMVKLO2asWf8I7EKJWgnuEnMI	$aGYMEi1KO534ezshtH0n3_XRs3OZXgi_DY26XrWFLTE	\N	f
$E97pMjZjzmrDM-hFyRwC6aqENPN3ixJigBn50-VhHEQ	$4WW-qYRENg7ChGX-khhMVKLO2asWf8I7EKJWgnuEnMI	\N	f
$owPa_25ew4CsxHc1lZakZoynscO0PsDgfqWSWzt7GA0	$E97pMjZjzmrDM-hFyRwC6aqENPN3ixJigBn50-VhHEQ	\N	f
$pmZLd5201Kj0dO2jHeo7HR2HX3MoKEMeDXfHQpHmClc	$owPa_25ew4CsxHc1lZakZoynscO0PsDgfqWSWzt7GA0	\N	f
$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8	$pmZLd5201Kj0dO2jHeo7HR2HX3MoKEMeDXfHQpHmClc	\N	f
$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM	$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8	\N	f
$hJAqFBOtlfAGIpo0e2iPYUmyHUIpeGzHdhy2DOGL5M0	$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM	\N	f
$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4	$hJAqFBOtlfAGIpo0e2iPYUmyHUIpeGzHdhy2DOGL5M0	\N	f
$Iy8smKso2nyVLpvpWF929j9Og8e4g79f6knC-jFSylY	$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4	\N	f
$WFNOeNnqQFC6pvybcuiouNFeVdoahcKJBga0cY6VdXY	$Iy8smKso2nyVLpvpWF929j9Og8e4g79f6knC-jFSylY	\N	f
$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g	$WFNOeNnqQFC6pvybcuiouNFeVdoahcKJBga0cY6VdXY	\N	f
$KSmWWmQkmzexNXwiaQhMG6Ec2JDmy7jmZgmlGyXySL8	$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g	\N	f
$B-bfbB05RV8t1MKB6YKPsn7xa-KawJRYs-lLGP2CEDI	$KSmWWmQkmzexNXwiaQhMG6Ec2JDmy7jmZgmlGyXySL8	\N	f
$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ	\N	f
$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY	$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	\N	f
$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs	$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY	\N	f
$9bQLGiDMN6cfZTQFKMEwuFSUDUIkIAELgVXodLQCCgg	$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs	\N	f
$AM_7A_tNjjaTM9klUn_6ZPT43TZaWkerNTyPWRr1wWA	$9bQLGiDMN6cfZTQFKMEwuFSUDUIkIAELgVXodLQCCgg	\N	f
$q11DmpDEFKgMjbP76SMow-33zfL47mOYIebpAXwj7Yo	$AM_7A_tNjjaTM9klUn_6ZPT43TZaWkerNTyPWRr1wWA	\N	f
$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk	$q11DmpDEFKgMjbP76SMow-33zfL47mOYIebpAXwj7Yo	\N	f
$tkhCzNBPYwhauxcDGd86lTAQzSTBjk9UCfQDl-Dcb94	$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk	\N	f
$YVY2sBhRnasnpoMwSSbU88Fc-B7KTrQ3G-MMG_vAfEE	$tkhCzNBPYwhauxcDGd86lTAQzSTBjk9UCfQDl-Dcb94	\N	f
$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE	$YVY2sBhRnasnpoMwSSbU88Fc-B7KTrQ3G-MMG_vAfEE	\N	f
$xS0cI6IRN-1AwThg1PXRczu-Ll67HXrijUmZ7dZapzM	$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE	\N	f
$3Od6EvbJ4mccQ6S_C8DJjvNwFn7ihmJ4QE7N0Ug6w1I	$xS0cI6IRN-1AwThg1PXRczu-Ll67HXrijUmZ7dZapzM	\N	f
$gYc_OPh-U8vTKbHPI-j-vjtTnnvaf8JHMKyZFvLCadk	$3Od6EvbJ4mccQ6S_C8DJjvNwFn7ihmJ4QE7N0Ug6w1I	\N	f
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
$B-bfbB05RV8t1MKB6YKPsn7xa-KawJRYs-lLGP2CEDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir
$gYc_OPh-U8vTKbHPI-j-vjtTnnvaf8JHMKyZFvLCadk	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
\.


--
-- Data for Name: event_json; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_json (event_id, room_id, internal_metadata, json, format_version) FROM stdin;
$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{"device_id":"HKTASTBOAS"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"mv6XP5iM3wE853YjJELOxkSct4xK0IXay/I3Ff/oa08iouU8dWIeEovvGt/zRJutgU1g8wc2K1HsNN5BuMEzCw"}},"unsigned":{"age_ts":1783579928230},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":[],"prev_events":[],"content":{"creator":"@alextaylor:shikpooshaan.ir","room_version":"10"},"depth":1,"hashes":{"sha256":"H5kDtj/21we1lwnN6odY22gXV2qoW/cEvWHecVLm38w"},"origin_server_ts":1783579928230,"sender":"@alextaylor:shikpooshaan.ir","state_key":"","type":"m.room.create"}	3
$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{"device_id":"HKTASTBOAS"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"2+1toZ7LFxW2A4/Odz/tA/MZGXylQ259etII9ROgiPP7bdYAi5Z9/psTSHixiaq2AjfB+Jzfwcl9GJ2T40A0DQ"}},"unsigned":{"age_ts":1783579928513},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":["$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI"],"prev_events":["$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI"],"content":{"avatar_url":"mxc://shikpooshaan.ir/glIjKxJGeoRTJIFKjVpPMkEz","displayname":"alextaylor","membership":"join"},"depth":2,"hashes":{"sha256":"2Wz97wtiq+MDHvPegsfyu6AkCkg9KOt4EhC6Ig1Aofg"},"origin_server_ts":1783579928513,"sender":"@alextaylor:shikpooshaan.ir","state_key":"@alextaylor:shikpooshaan.ir","type":"m.room.member"}	3
$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{"device_id":"HKTASTBOAS"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"Z1QHwO+d14fxk4gSfLmIcIHWOhmYaUPeZeqMDzHNvYIhblUjHEJcsTnXHlO1jzoAi14AKevglvPUBIix8aJ4AQ"}},"unsigned":{"age_ts":1783579928732},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":["$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ","$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI"],"prev_events":["$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ"],"content":{"ban":50,"events":{"m.room.avatar":50,"m.room.canonical_alias":50,"m.room.encryption":100,"m.room.history_visibility":100,"m.room.name":50,"m.room.power_levels":100,"m.room.server_acl":100,"m.room.tombstone":100},"events_default":0,"historical":100,"invite":0,"kick":50,"redact":50,"state_default":50,"users":{"@alextaylor:shikpooshaan.ir":100},"users_default":0},"depth":3,"hashes":{"sha256":"e+x8X3ApcfVkJy2qcaIFHPxa/3Jb26juHqB50tiLMWY"},"origin_server_ts":1783579928732,"sender":"@alextaylor:shikpooshaan.ir","state_key":"","type":"m.room.power_levels"}	3
$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{"device_id":"HKTASTBOAS"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"jtlfOn8aVqXjFbiQbozoHOQfxgDo05DRLTY8avsJ1WIi8xBvV8JYlDxjwsx70K6yfIZg0GTgBfdZIibN+W5mCg"}},"unsigned":{"age_ts":1783579928782},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":["$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ","$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI","$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI"],"prev_events":["$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI"],"content":{"join_rule":"invite"},"depth":4,"hashes":{"sha256":"MMFya270doKf4Vr29alQI+oKuIawTUTj2Y5FTU1JWg0"},"origin_server_ts":1783579928782,"sender":"@alextaylor:shikpooshaan.ir","state_key":"","type":"m.room.join_rules"}	3
$ovWXMhcqZ51rR0-mmT_ebzrZ3c9XWpr256lElWATA5g	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{"device_id":"HKTASTBOAS"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"lKvfkAuQbc2JfxykwvPwpfhOFBIJJARZZpee3PpWawL5U7ivirj1I+r05xV0pkQ+jgktoQUaBEuEr9sp9w+rCw"}},"unsigned":{"age_ts":1783579928784},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":["$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ","$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI","$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI"],"prev_events":["$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs"],"content":{"guest_access":"can_join"},"depth":5,"hashes":{"sha256":"Z9Q/G7DMFyIa7svdg9GXbY0S/qJR7qEIUq9PZcn1wF0"},"origin_server_ts":1783579928784,"sender":"@alextaylor:shikpooshaan.ir","state_key":"","type":"m.room.guest_access"}	3
$aGYMEi1KO534ezshtH0n3_XRs3OZXgi_DY26XrWFLTE	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{"device_id":"HKTASTBOAS"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"dN1NKSp3XXhTUUEFzwYBSICPQfu15wi3oEI8WrbCjvjj0/phvNPOwMbna6NYxMfOQ38n5XupwZNd6HLwARZEBw"}},"unsigned":{"age_ts":1783579928786},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":["$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ","$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI","$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI"],"prev_events":["$ovWXMhcqZ51rR0-mmT_ebzrZ3c9XWpr256lElWATA5g"],"content":{"algorithm":"m.megolm.v1.aes-sha2"},"depth":6,"hashes":{"sha256":"5VylX5ZDoQ6FGhaagphjcU+8dWSWU2cl870bloJFtc0"},"origin_server_ts":1783579928786,"sender":"@alextaylor:shikpooshaan.ir","state_key":"","type":"m.room.encryption"}	3
$4WW-qYRENg7ChGX-khhMVKLO2asWf8I7EKJWgnuEnMI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{"device_id":"HKTASTBOAS"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"+dFpS2fX9HLDnFmAdVv8ce4ioefOaeRd78CMnauPQJLacJDjJNxcjINOPBuOMMnVV6P7PfUqs9Sz5UzRih24Cw"}},"unsigned":{"age_ts":1783579928788},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":["$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ","$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI","$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI"],"prev_events":["$aGYMEi1KO534ezshtH0n3_XRs3OZXgi_DY26XrWFLTE"],"content":{"history_visibility":"invited"},"depth":7,"hashes":{"sha256":"bcj9KgeFqCbaC7fFlcU7HCoscO0capaOpNO4SJUnqzU"},"origin_server_ts":1783579928788,"sender":"@alextaylor:shikpooshaan.ir","state_key":"","type":"m.room.history_visibility"}	3
$E97pMjZjzmrDM-hFyRwC6aqENPN3ixJigBn50-VhHEQ	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{"device_id":"HKTASTBOAS"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"L2LZxcUJvA5HV8hqcb6QXP7y3A3Bw8r5Ha1nqqkC4r6deyUe510jN0av4hzKEVeOBY2Q84zsnxVTW5nCL400DQ"}},"unsigned":{"age_ts":1783579928790},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":["$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ","$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI","$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI"],"prev_events":["$4WW-qYRENg7ChGX-khhMVKLO2asWf8I7EKJWgnuEnMI"],"content":{"name":"alex"},"depth":8,"hashes":{"sha256":"LYPcY6s9wlLT5XUSjSmKi85b0QcbTQCUhxX/yDT/Vg4"},"origin_server_ts":1783579928790,"sender":"@alextaylor:shikpooshaan.ir","state_key":"","type":"m.room.name"}	3
$owPa_25ew4CsxHc1lZakZoynscO0PsDgfqWSWzt7GA0	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{"device_id":"HKTASTBOAS"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"QEzljSI3XR8MK5xhC2JdUF5Jmm6GoYn3QrYqPB+9+ELw5+PwgCRmW07E21YdR7RoeQRm9u5n//Em+oVAB2nWBA"}},"unsigned":{"age_ts":1783580573162},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":["$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ","$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI","$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI"],"prev_events":["$E97pMjZjzmrDM-hFyRwC6aqENPN3ixJigBn50-VhHEQ"],"content":{"url":"mxc://shikpooshaan.ir/LKhfOyhTLlAgUTeqMdnYBjKW"},"depth":9,"hashes":{"sha256":"CujRbjZOzZSpyob50WeeOZoo9HM0hdsw1kVlzwvOJXg"},"origin_server_ts":1783580573162,"sender":"@alextaylor:shikpooshaan.ir","state_key":"","type":"m.room.avatar"}	3
$pmZLd5201Kj0dO2jHeo7HR2HX3MoKEMeDXfHQpHmClc	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{"device_id":"INWEZSCLYH","txn_id":"492ad1cbcbf64d54b8836be1f77db411"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"dNITaisYQroZraGXnDhENk5jUWqr69GIyLmh/4ZoVGLHJLUg3PEmS8LoUiPqwGW2Rd9NxotlmxB45oI3l1HJBQ"}},"unsigned":{"age_ts":1783580804417},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":["$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ","$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI","$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI"],"prev_events":["$owPa_25ew4CsxHc1lZakZoynscO0PsDgfqWSWzt7GA0"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgAEvAH4oXSbjiXWD3y4OkTggqIokxpqt4fF4F2Ex0m/xWPskp9yp7JRXL8zHVXzjHumtZyFX/zybDe1+cechTSKYwYg2foGdezML2zR4krbmhCEOXqB28K1Fm0SV1Iond8Jy5Kak+RIJoV1jFgm8yl1asdVYVY8nZ2tYSbkq9LN6zkBdSILOBVSbM+1anEMmRTZMXIaaHPw1VZqif2G02O0uqsbs5lUfd/UiE1+Vbhkq1hEPhECKG9kRc0P+4XdJDWTCQsCVNU8iekTajIULgZqHzjkCN62wN0meHmHWvNOjwSW2KXEbwT0oDwLBTsAN1m0MjAoiljaCxk/a8nlzghvdQs2oLQNxv2wTUd6lfgK2P+DaBsgZSKEBB5cJ2xIwF8PSYCUZi1nJBkeIRZvwHhTrxufVgX3ObW+Wck4Y3UNO/CYDt1bwOYu4P9kBxxGR6SBZ3FkY2a1ASxg56s5/i8+uvrvcBxYe8oyt7Ef4mZ6MQxjWnJowM5FSOaiGA0X0kZdvl5ujpd3jsrcKbQMdiLg/WfuEn3uoXgAD/O9QSFaV4c3mRqcrYgt1IIYUFKNwNKG7kmL+T8EA2pOXymzOzwPCivMMZZTlIQqIcpwxKosVbGUsDQSNMqHFuIKG30ziiNkwm+zVqx+nim4ImZOsT0tFcYgfGbV6KiP5MEol2hxgT/8dwEyI6WZBrPT6ffiQa/tv1HbDQBDri4Pk3sqJRhF2S/oyYnVBG3cZr6Xf36ENpuYuh30xIsJc1DC1YZNLFj8qGJob5VWdTIb0c1plXuHhgstDxuNa1xd+zdkd6OCwVGlSgaE5gAwGi20xkqi4rUppFtaGMiI3aKx0pwcS9gJyi1UOdodcUwspZ/VjZcmGIoYAE3rNJH2DXR3exvUJNUVRAMsZcCZWJKEKWBgj6lz5B66Ii124+mBkPKoJPaKHDs4i3u2S4KN1lAzDtEg1cx+VzdiZX1QUUn+jE0iE513NWClHeu1ctxiJ65/x7FTCHMgGc4lXsqLrTsW+iAY7qGC4MtNCo27F9Jczabv69c1xooM/uaGdGWH5RUwmRDhPp5ch9c0e0uyHOWNT6bXCRU6Z6jibMgyM14xg/EL0v7NRJWVv1M/7KEzPex+aHXJgbcZNQ6e1yz/Iv4IidPsUBdJji3pYERmghrQYDDNOEe/ZMFD4z+mj1NOU1h72fu4Lfr04W7jW6HnMfgUOf8rlXZyDJYrNtz1qXFYX7SiI5H8KesCsbHmIg43RO7HXeakJk2oucC5r+X6VzmVoN+yZg0ltXQ0fKJN7MkLIiCetMHIXJNLIAllCXXgru+ujGSnyrGhcGfuPiPuCm8F6p+5ddnNwPCbdVDVp0ERhyqSNKmhZ0z9Fc2+GNhewIbSdZNIYEfm9yyS9tF9TlHmG5L+iMvig+agyW2lgNR5W51hackwgUKlqHV/oDfBY8D","device_id":"INWEZSCLYH","sender_key":"DXt9vFDfAJsantWyZKXxKDN+0MPlQBo/gvM0Y80mpm4","session_id":"WnM1NCwmnV0tP+kTI0iQseIxaBRagTRRj/SwS+I6Sb8"},"depth":10,"hashes":{"sha256":"H1cU16lhw40O1V2iT/kCBOd5c6tk7mH4xwfGlX64SKE"},"origin_server_ts":1783580804417,"sender":"@alextaylor:shikpooshaan.ir","type":"m.room.encrypted"}	3
$hJAqFBOtlfAGIpo0e2iPYUmyHUIpeGzHdhy2DOGL5M0	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{"device_id":"LLRGRFFCEG","txn_id":"d07ef5bcf94247bb82091171dece4b47"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"RrA5iDUC2TEpmRUesDz8BssI6kErak7ngzUl/Bd+EMjwtGp622VDtv5jbc3doiSS2fwpP+tfAVP6n4bnz/STDA"}},"unsigned":{"age_ts":1783582226427},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":["$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI","$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI","$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM"],"prev_events":["$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgAEpABN3VJfDiv2yDzMZPLtwXV867q/6xiw9cnSL7aCebMx3uX6Kxq2hItu/2SRXBa4GsbeSuby5Unox3Y9INyiNDe1BKC/gRfMThPm4KpQAErIFXhS12BZ7mHe/wTEYjLZfKcxBJ8/4YdnO4CrSuQ9Qa5qZ9tbVv3w1OdAvQjJ3u0kiqnB/WfufHi9j4ft41gCvPA1r5FZBxX0oq+QTSfptN7hmMKbbpbnU4NcXqVIDkjRhomRBnc5Rvk8h4C1/XbCm/1PYjl/UhRfYSHlXBW5PPZBizFNA7Fa14N","device_id":"LLRGRFFCEG","sender_key":"KOrKKo8Shfg4ZuaIbkSAWiWm6EfUoNiQocUefx0YtV4","session_id":"3JHMg+JwZIyJd9w/iSODrj6aqUBINZHFt4B07w5rtbY"},"depth":13,"hashes":{"sha256":"r+Dm65J6uOMKVq1gvD5QUMjNYst4ulSWtFNqkeWe9Wg"},"origin_server_ts":1783582226427,"sender":"@testuser:shikpooshaan.ir","type":"m.room.encrypted"}	3
$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{"device_id":"LLRGRFFCEG"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"rSoG0hFfbFHX4BAvGI2qTLpqXJGvHDOfdt8ZFv/rLedQrvIqiBHRN+1MYO36HzlENMnv2SyP9H/CCAK9zVocDg"}},"unsigned":{"age_ts":1783582218822,"replaces_state":"$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8"},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":["$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI","$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs","$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI","$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8"],"prev_events":["$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8"],"content":{"membership":"join"},"depth":12,"hashes":{"sha256":"x3mGYZ5grH7jNyAZimmcpkcojON6ADzijaQYQA1A35k"},"origin_server_ts":1783582218822,"sender":"@testuser:shikpooshaan.ir","state_key":"@testuser:shikpooshaan.ir","type":"m.room.member"}	3
$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{"device_id":"UJHQSRLCJP"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"g5O2dtnihNA7xykcAd3IJht4eYdlTCbMBIKpvVlEYGhPd9qLU1LK5IDYJIeyUrcJU7kKRFsUTWkzuBT/VyR9Cg"}},"unsigned":{"age_ts":1783582211822},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":["$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs","$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI","$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI","$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ"],"prev_events":["$pmZLd5201Kj0dO2jHeo7HR2HX3MoKEMeDXfHQpHmClc"],"content":{"membership":"invite"},"depth":11,"hashes":{"sha256":"HuJV3mke/yyC2owOuOrz4nWO7/cFvYeIncHqMAZZ/vs"},"origin_server_ts":1783582211822,"sender":"@alextaylor:shikpooshaan.ir","state_key":"@testuser:shikpooshaan.ir","type":"m.room.member"}	3
$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"JH3xJE7NxU1/RHjxX3SYGSSQlIaU6f7CdFx+W+e5l5lRy2gdMAkf7ONuonVX1gUpRJKNj5PdXDdrzAvCs8mODg"}},"unsigned":{"age_ts":1783582590751,"replaces_state":"$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM"},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":["$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI","$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI","$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM"],"prev_events":["$hJAqFBOtlfAGIpo0e2iPYUmyHUIpeGzHdhy2DOGL5M0"],"content":{"membership":"leave"},"depth":14,"hashes":{"sha256":"P23zzvc4/2CJXAbbavFTPFj3XX85ELPLSZP+7jUPuNw"},"origin_server_ts":1783582590751,"sender":"@testuser:shikpooshaan.ir","state_key":"@testuser:shikpooshaan.ir","type":"m.room.member"}	3
$Iy8smKso2nyVLpvpWF929j9Og8e4g79f6knC-jFSylY	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{"device_id":"NBQWFWVCQE","txn_id":"888939ccf987401687c826248a5b9b6e"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"ywg/gCXblbapQ3hJSmQ8KOJ7yjQo6iXwuU7kGwJ3esAhqS0DDQ8fUfTK/Z+Bx0D+q4L8Qzmk236bzWgzw03mBA"}},"unsigned":{"age_ts":1783582699832},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":["$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI","$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI","$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ"],"prev_events":["$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4"],"content":{},"depth":15,"hashes":{"sha256":"EXwy1gb5lrx0POXgT0EF4tntByTaj1B9nutg+iwt/zk"},"origin_server_ts":1783582699832,"sender":"@alextaylor:shikpooshaan.ir","type":"m.room.redaction","redacts":"$hJAqFBOtlfAGIpo0e2iPYUmyHUIpeGzHdhy2DOGL5M0"}	3
$WFNOeNnqQFC6pvybcuiouNFeVdoahcKJBga0cY6VdXY	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{"device_id":"NBQWFWVCQE","txn_id":"cf1a8b81bf0e438c8a442d52cf540c94"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"xurHS9jvguBCRSLM4xRgdx/mQ9DpfPQy8sqrV8iORuVfVZUR9T8Bq+JR4iOYb1MmNcAvWQKN3jguugNCp/8mBw"}},"unsigned":{"age_ts":1783582703545},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":["$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI","$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI","$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ"],"prev_events":["$Iy8smKso2nyVLpvpWF929j9Og8e4g79f6knC-jFSylY"],"content":{},"depth":16,"hashes":{"sha256":"q2G5KLWsZQNnQvftracT3eG/3hMu5peslO02cfvb808"},"origin_server_ts":1783582703545,"sender":"@alextaylor:shikpooshaan.ir","type":"m.room.redaction","redacts":"$pmZLd5201Kj0dO2jHeo7HR2HX3MoKEMeDXfHQpHmClc"}	3
$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{"device_id":"UJHQSRLCJP"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"ovKXbkv/GAjG8HAs1POTpJAhsTS4q8ApeYsBtfjpUOD5O927bcblV/kc5DJhOOun8meI9j6flb5/dwhFu34uDw"}},"unsigned":{"age_ts":1783582978384,"replaces_state":"$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI"},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":["$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI","$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI","$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ"],"prev_events":["$WFNOeNnqQFC6pvybcuiouNFeVdoahcKJBga0cY6VdXY"],"content":{"ban":50,"events":{"m.room.avatar":50,"m.room.canonical_alias":50,"m.room.encryption":100,"m.room.history_visibility":100,"m.room.name":50,"m.room.power_levels":100,"m.room.server_acl":100,"m.room.tombstone":100,"org.matrix.msc3401.call":0,"org.matrix.msc3401.call.member":0},"events_default":0,"historical":100,"invite":0,"kick":50,"redact":50,"state_default":50,"users":{"@alextaylor:shikpooshaan.ir":100},"users_default":0},"depth":17,"hashes":{"sha256":"rZlu12mPALL+byZdwQLXna1AboSxMzkqXcdxUqf/biM"},"origin_server_ts":1783582978384,"sender":"@alextaylor:shikpooshaan.ir","state_key":"","type":"m.room.power_levels"}	3
$KSmWWmQkmzexNXwiaQhMG6Ec2JDmy7jmZgmlGyXySL8	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{"device_id":"UJHQSRLCJP"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"uVVSTJmaeaGGECMyp/2N0Kfg8HZfkMjVMGie3QY0K1WIJ+XMGQcnPgGhCoMasTfkWLJ1ErifMVP9naukYO7IAg"}},"unsigned":{"age_ts":1783583005051,"replaces_state":"$4WW-qYRENg7ChGX-khhMVKLO2asWf8I7EKJWgnuEnMI"},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":["$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI","$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g","$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ"],"prev_events":["$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g"],"content":{"history_visibility":"shared"},"depth":18,"hashes":{"sha256":"J+shIIEgIrMLfq2LAvmHGMocY5mS5ippPzwXmrNxuv8"},"origin_server_ts":1783583005051,"sender":"@alextaylor:shikpooshaan.ir","state_key":"","type":"m.room.history_visibility"}	3
$B-bfbB05RV8t1MKB6YKPsn7xa-KawJRYs-lLGP2CEDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	{"device_id":"UJHQSRLCJP"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"ZCsixdCNsquY+U2fjD+JykA4LxAopa8p29ojKSMygE9I1npdqQ8rnGz1m7C5p2RekfKeU8b2RylFknV/TAyAAw"}},"unsigned":{"age_ts":1783583169621},"room_id":"!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir","auth_events":["$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI","$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g","$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ"],"prev_events":["$KSmWWmQkmzexNXwiaQhMG6Ec2JDmy7jmZgmlGyXySL8"],"content":{"alias":"#my-room:shikpooshaan.ir","alt_aliases":[]},"depth":19,"hashes":{"sha256":"Vs9Dj1sW1JDP8Ga0d/kSgDuwWaRLQoaudNC99zkr/fg"},"origin_server_ts":1783583169621,"sender":"@alextaylor:shikpooshaan.ir","state_key":"","type":"m.room.canonical_alias"}	3
$YVY2sBhRnasnpoMwSSbU88Fc-B7KTrQ3G-MMG_vAfEE	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	{"device_id":"AOKSEIYZIB","txn_id":"6ef927cfccc04ea9aa78d5e18d57fb40"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"LFCKKj9Rjt8ftuAb5ELxev3jOy/eFu7kkiVJSNJQR7R19vaEdODcSUqf+Vz24DQDO9nEyQPWLPUxFYh+OJxnDA"}},"unsigned":{"age_ts":1783583526724},"room_id":"!DDSQZabMGckQpzuTFl:shikpooshaan.ir","auth_events":["$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ","$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY","$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ"],"prev_events":["$tkhCzNBPYwhauxcDGd86lTAQzSTBjk9UCfQDl-Dcb94"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgBEqAHCvoA6xEwWdwHI7Ir0CMo2PbFDus3vw9n4Ov8uJmIENQYnyMu1mIOWDBXBzQPyglTanH1COJqKndS5lioCDPrv3hRECwvwz4CeGv0mqvk79RXq0Qk4uAuFUerNka3Rjjrw3AVvTu04/du+Kw2d04naaczxslChX2Wh/ngoTzDZLEcExAteKg0qfLLFn0FN6oMDdpCY/+6D3r3yrfz0KifOXx/cKxkZH7Ah3J6E50gaxjeiqCGbAMEFpXaQfsDIdlmvE9qjwkAk9uZjh/8U7hpipsk9ALRFU7Owvm5nEfH80sEG36gUYiu6BAXbe5dBH7m15JwJejCuPW+sQO1T4T7PgmtlaCpl8p6H/LgVMQDwBIaZxj9/M4JvjtwEmKp+ziqQTdKngX+ywaKo6ArvdAs/LISHB+iSyRrDnntXk8wW2TeQzQ1WeqOEsHgnsD7zw/JIvCMkxCrglVk7a3VKGv9jo0VRw744wyYwL1EllTMMg8+DDzbxs4kux36nRPcK5wDSaDZ8n9S2nj+vPizWgaijubbrPspmqitm/f+JLOrk9Kabey8NbY79kemC6pvwzdJH9vvmYW6qTzVOnTG3I27pKLVaPUPSkF4msozuHCFauqnVLxdy7l8p+SbWrUroMpWeSpMZ33PjBLdlECF80aswG7s89DWDBgspcku1uoLZMKsqmfZmabPCP8079q7AEa4UeM1eKBDHFMVqlCOTAR55jnHlQprX/Niw+7h36m64gVbBQd3HopIw969p3Es+W28MDab9zTelv2izCBdW79l7TCle/wg1cMsaWfWZsCmb5M4Pd82jcMnxa9L6qazELvpQFAx0RQGMhQdGDTFEmT0l81Ix5wK86VP3b5veL7053mQ6VJTIrFYyIH9UBScsCy0i95jDd3QmQGRHuOiKEWCbMLADRlu8X37y8hYNFYKJ91FzglqLV9fBC2LO4HAy5VFQFeS01Aaj2p1F3wT4fXHwqVTaiAogFxIZuBbD7FmJeFmcAnXnQZHbwzk0mn6Osta5SVSLkIlnr7di7TzPDmtWZJSuwjj0FdS7oihF6m2fBT2Fc2cYJDZQvLYJOmFHFHTYuldG1bCsEfwdBJeDQX4LW+qtUQaU7NZbq4Tc+9CD0juxmcZioxJqUiQUVSlWfiHNL/qGLe3X6o2j8SjLYP6OpEWDkjBfybxj6SY+oERXGNSU5I4eSO4W+G0wTui7mvoibih4DqGQe9f7myWfvP6SZthU6NjgXfa6nkLgbw50vOKBt1kv26s8tWn8bxHJVc0pWK+pNEPHWnkYUGqeTXeUXPR8oohlB9/dAjljyUKxIufYfhjUJDZCg","device_id":"AOKSEIYZIB","sender_key":"NmM23XC1ZN1NdS7/0ZURWKQxnm9t7xaKYzKUnQ17nlc","session_id":"AR5wwfQ0rLe1NKsbpMVDKvXaxPbo5AWHMkFGoyhkQoM"},"depth":10,"hashes":{"sha256":"S0P5sSb+3t49QY5wc6JbtYKmW16YhFsX468VIBVPw+g"},"origin_server_ts":1783583526724,"sender":"@ali:shikpooshaan.ir","type":"m.room.encrypted"}	3
$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	{"device_id":"AOKSEIYZIB"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"TG9Do9fMgQqVKPKMgN8j6TbBCtpgAllCCEMPsces8buKamohkKnsjjV2rx23zMns2bJCAGnaLdNFb6f8BTJiDQ"}},"unsigned":{"age_ts":1783583512302},"room_id":"!DDSQZabMGckQpzuTFl:shikpooshaan.ir","auth_events":[],"prev_events":[],"content":{"creator":"@ali:shikpooshaan.ir","room_version":"10"},"depth":1,"hashes":{"sha256":"vnt9EkELtOZJKfPSwRO5beg46i+aloN2Yi1an1ILzR0"},"origin_server_ts":1783583512302,"sender":"@ali:shikpooshaan.ir","state_key":"","type":"m.room.create"}	3
$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	{"device_id":"AOKSEIYZIB"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"HgJ7jr3WZ9fdTUIM7de9DZ7PA/tL07MdEcMxhBi8zMBmodq7/0WRqvAyURnbt/3m60QOISUUv4ZbFFddf/ORBA"}},"unsigned":{"age_ts":1783583512517},"room_id":"!DDSQZabMGckQpzuTFl:shikpooshaan.ir","auth_events":["$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ"],"prev_events":["$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ"],"content":{"avatar_url":"mxc://shikpooshaan.ir/nfwAoKkXAOYczxtRVqrApNgi","displayname":"ali","membership":"join"},"depth":2,"hashes":{"sha256":"H5K2ihUOgwzJJ/Ai3FyPcw1r2RNGFqbR/SHtNZt/lj0"},"origin_server_ts":1783583512517,"sender":"@ali:shikpooshaan.ir","state_key":"@ali:shikpooshaan.ir","type":"m.room.member"}	3
$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	{"device_id":"AOKSEIYZIB"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"Emx2k/5mz7UCc5GdOaWZlG8D1//qL5EiwWSeoZnf/LnRUi3Sztk2N2llnzzfFQu6qLg3Wk70H58LKKiG2yAyAg"}},"unsigned":{"age_ts":1783583512720},"room_id":"!DDSQZabMGckQpzuTFl:shikpooshaan.ir","auth_events":["$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ","$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ"],"prev_events":["$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ"],"content":{"ban":50,"events":{"org.matrix.msc3401.call.member":0},"events_default":0,"historical":100,"invite":50,"kick":50,"redact":50,"state_default":50,"users":{"@alextaylor:shikpooshaan.ir":100,"@ali:shikpooshaan.ir":100},"users_default":0},"depth":3,"hashes":{"sha256":"rfxAlN/ju5bUmm3zCaH7YAJ8mQhwMNfAZRp2vbNw6xs"},"origin_server_ts":1783583512720,"sender":"@ali:shikpooshaan.ir","state_key":"","type":"m.room.power_levels"}	3
$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	{"device_id":"AOKSEIYZIB"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"Q6dbdD9E3dFAOfLVW6PSz+qaIRnG2wtQEBSKs94xXn0sDwlvYtKSPFDpmLEj7pGq1LD22vxLU3F/3bI3ykwsBg"}},"unsigned":{"age_ts":1783583512786},"room_id":"!DDSQZabMGckQpzuTFl:shikpooshaan.ir","auth_events":["$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ","$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY","$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ"],"prev_events":["$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY"],"content":{"join_rule":"invite"},"depth":4,"hashes":{"sha256":"ZMch0Wd8IiZjO59ozwFej2IjQoRg3TsEihe82FqCPdo"},"origin_server_ts":1783583512786,"sender":"@ali:shikpooshaan.ir","state_key":"","type":"m.room.join_rules"}	3
$9bQLGiDMN6cfZTQFKMEwuFSUDUIkIAELgVXodLQCCgg	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	{"device_id":"AOKSEIYZIB"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"UKpqB2oMZX+en0HXOTxCCdKuMF8bYdn/iQJip+ifu28je1NidyuixkrOGU26B2asQB2w5N/wrdmiQ+XygvPhDw"}},"unsigned":{"age_ts":1783583512788},"room_id":"!DDSQZabMGckQpzuTFl:shikpooshaan.ir","auth_events":["$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ","$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY","$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ"],"prev_events":["$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs"],"content":{"guest_access":"can_join"},"depth":5,"hashes":{"sha256":"i/n0WtZ/kA6/rAG4armHiz1bTRO1lNimpA7xYRHgz30"},"origin_server_ts":1783583512788,"sender":"@ali:shikpooshaan.ir","state_key":"","type":"m.room.guest_access"}	3
$AM_7A_tNjjaTM9klUn_6ZPT43TZaWkerNTyPWRr1wWA	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	{"device_id":"AOKSEIYZIB"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"xhn2a9Ne97ZF4Sb50lLBu43X/b+nwVjGca8bWW0oHQB9NeKDfAEuKa155pcfgq1crACjqeN7YHrluTMj/l0cDQ"}},"unsigned":{"age_ts":1783583512790},"room_id":"!DDSQZabMGckQpzuTFl:shikpooshaan.ir","auth_events":["$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ","$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY","$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ"],"prev_events":["$9bQLGiDMN6cfZTQFKMEwuFSUDUIkIAELgVXodLQCCgg"],"content":{"algorithm":"m.megolm.v1.aes-sha2"},"depth":6,"hashes":{"sha256":"RYeG6ihRpJ3oVn17DURh6fUi4WdJoXEY6TXwOstn2uY"},"origin_server_ts":1783583512790,"sender":"@ali:shikpooshaan.ir","state_key":"","type":"m.room.encryption"}	3
$q11DmpDEFKgMjbP76SMow-33zfL47mOYIebpAXwj7Yo	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	{"device_id":"AOKSEIYZIB"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"S/qm6qhKJ5YKJ0IKTMMoyCC6NEDOEn1WnytqyUozzvuCE4Vlrssaf0TmyMquv0Pn/2g1p7jvILYQirUmykXrAw"}},"unsigned":{"age_ts":1783583512792},"room_id":"!DDSQZabMGckQpzuTFl:shikpooshaan.ir","auth_events":["$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ","$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY","$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ"],"prev_events":["$AM_7A_tNjjaTM9klUn_6ZPT43TZaWkerNTyPWRr1wWA"],"content":{"history_visibility":"invited"},"depth":7,"hashes":{"sha256":"0eqZm6gnJDvSWrYhO2W41jMbvAA07lrfPx5ttqOvw3Y"},"origin_server_ts":1783583512792,"sender":"@ali:shikpooshaan.ir","state_key":"","type":"m.room.history_visibility"}	3
$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	{"device_id":"AOKSEIYZIB"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"FKPbj/sbudI/+TUS27s2I819rR5V0DTdL2okW/bwKYGtRBOSGGb8EfDIcMNjFv3/HiVxEblo8sePo0wyFKfVAw"}},"unsigned":{"age_ts":1783583513158,"invite_room_state":[{"content":{"creator":"@ali:shikpooshaan.ir","room_version":"10"},"sender":"@ali:shikpooshaan.ir","state_key":"","type":"m.room.create"},{"content":{"join_rule":"invite"},"sender":"@ali:shikpooshaan.ir","state_key":"","type":"m.room.join_rules"},{"content":{"algorithm":"m.megolm.v1.aes-sha2"},"sender":"@ali:shikpooshaan.ir","state_key":"","type":"m.room.encryption"},{"content":{"avatar_url":"mxc://shikpooshaan.ir/nfwAoKkXAOYczxtRVqrApNgi","displayname":"ali","membership":"join"},"sender":"@ali:shikpooshaan.ir","state_key":"@ali:shikpooshaan.ir","type":"m.room.member"}]},"room_id":"!DDSQZabMGckQpzuTFl:shikpooshaan.ir","auth_events":["$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs","$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ","$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY","$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ"],"prev_events":["$q11DmpDEFKgMjbP76SMow-33zfL47mOYIebpAXwj7Yo"],"content":{"avatar_url":"mxc://shikpooshaan.ir/glIjKxJGeoRTJIFKjVpPMkEz","displayname":"alextaylor","is_direct":true,"membership":"invite"},"depth":8,"hashes":{"sha256":"ocvfjxMwAwYnkkyknBbYYVsVYmq9oTfB2++ELyJPdjQ"},"origin_server_ts":1783583513158,"sender":"@ali:shikpooshaan.ir","state_key":"@alextaylor:shikpooshaan.ir","type":"m.room.member"}	3
$tkhCzNBPYwhauxcDGd86lTAQzSTBjk9UCfQDl-Dcb94	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	{"device_id":"AOKSEIYZIB","txn_id":"a180d17f2a374f18af0068bc202bb384"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"maqXloPHOvH1pEIdojtzpfFLUsaOWbswKdO2pWAt5m9nvhFDQYy14MTOODk14d5ZZgk1QjKb481vGZPrF1jcCA"}},"unsigned":{"age_ts":1783583520133},"room_id":"!DDSQZabMGckQpzuTFl:shikpooshaan.ir","auth_events":["$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ","$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY","$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ"],"prev_events":["$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgAEpABumg2Nk5FyrfVZVmLEsIeDRx4MRprNKuox6cdaDw/WnnfdxhkWuZ1jB4Agj/fJLDuYaGPO4Vu7LLhGTjSS/iZcTRsiX3DzJG3j32BOkSOYwFe4iTO98rPh7adJwXKV5XmF57tTEaq6M55zopWTfWPhNNJUk3ywAm0N2F60PnAzjUv9BwVPQR6QMaAZkxBUm5n4zWdrm34ktrwat+6jDDtGoOc21xWSy3NB3mThRD+ykx9znjev8tthP9KYhapqMdTIrLJMD8g/ZHFkm0f7IhhmpHq85OVTr8J","device_id":"AOKSEIYZIB","sender_key":"NmM23XC1ZN1NdS7/0ZURWKQxnm9t7xaKYzKUnQ17nlc","session_id":"AR5wwfQ0rLe1NKsbpMVDKvXaxPbo5AWHMkFGoyhkQoM"},"depth":9,"hashes":{"sha256":"7pNcD5zkGRG1/iuOfm0lLKc673PR8R+DQvY+H6t5PfM"},"origin_server_ts":1783583520133,"sender":"@ali:shikpooshaan.ir","type":"m.room.encrypted"}	3
$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	{"device_id":"NBQWFWVCQE"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"lPLnebHTXm11/nrYWfD7LOgzmZaBjnrqoO5hVT1eSVkWoqAHLamDL0iCoDZhQ+wkNvA2/N+SZOIIDl3xfUKFAQ"}},"unsigned":{"age_ts":1783583542175,"replaces_state":"$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk"},"room_id":"!DDSQZabMGckQpzuTFl:shikpooshaan.ir","auth_events":["$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ","$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs","$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY","$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk"],"prev_events":["$YVY2sBhRnasnpoMwSSbU88Fc-B7KTrQ3G-MMG_vAfEE"],"content":{"avatar_url":"mxc://shikpooshaan.ir/glIjKxJGeoRTJIFKjVpPMkEz","displayname":"alextaylor","membership":"join"},"depth":11,"hashes":{"sha256":"CuQyR0/MK+GsBNgoWu1ra6v+TmBDGRJSxAvMDt/mOJI"},"origin_server_ts":1783583542175,"sender":"@alextaylor:shikpooshaan.ir","state_key":"@alextaylor:shikpooshaan.ir","type":"m.room.member"}	3
$xS0cI6IRN-1AwThg1PXRczu-Ll67HXrijUmZ7dZapzM	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	{"device_id":"NBQWFWVCQE","txn_id":"8eeeb2be092c4a95a0a44726ea09a681"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"Eyu+naXw2tDhjDZNsBLmDp+v1GWGCq/MzOxmZHV+oEmzutLXHD9QGeh0oqxtC8gDcEHk8MntTPWrh9cq4wvyDQ"}},"unsigned":{"age_ts":1783583561464},"room_id":"!DDSQZabMGckQpzuTFl:shikpooshaan.ir","auth_events":["$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ","$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY","$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE"],"prev_events":["$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgAEpABEZZGle9m0sZiJtH6Ts5Vjt+VPDWlL01WavirxP8HnYKAYL0ujuTJ9b9di1PqcGWOwhaifJtdLg4rtW30Dc7W6q3Nl6kFBEuO1UxMfsa7zdKOkKA0rhzbuKRTs+aT/lmhCI1y9tTeWolahKAuIb9+1E3oZVF0j+66l8DKeJ3DIN6YMwZjp2ii8mJFIjJ4l/Wu/si9qI2lGCH/WP73FAYQ1pbryKs2FKbkrdSZ5dgp/c25Nq5PV/pE+n4zW5BMcz8uT9i8ETuk97tp9Fl2Z7cVti27o6ahK6QC","device_id":"NBQWFWVCQE","sender_key":"FqkUPuFBGiNuuQlQRp5UN0zXzxp3hhSXx56iLoCFjWI","session_id":"OVcnfa2LhQPYIa2Hww1gJ/GX40gN5A2EX82jbcjALa0"},"depth":12,"hashes":{"sha256":"xs4Wff2822UyI2ZFpyPjfi3zMydJVGKS4GUstqMrJEU"},"origin_server_ts":1783583561464,"sender":"@alextaylor:shikpooshaan.ir","type":"m.room.encrypted"}	3
$3Od6EvbJ4mccQ6S_C8DJjvNwFn7ihmJ4QE7N0Ug6w1I	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	{"device_id":"AOKSEIYZIB","txn_id":"8010a7606b7c4c7d8269b2e58e763ca9"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"9j3JRxo08UP4/mGVFfJ5QTNLQ4joSFRGZ0dVP+YBhCdCYlh+RVrPwqtJuNctAU5t0Ny/sExHFIbrcsteVG5FBg"}},"unsigned":{"age_ts":1783584950260},"room_id":"!DDSQZabMGckQpzuTFl:shikpooshaan.ir","auth_events":["$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ","$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY","$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ"],"prev_events":["$xS0cI6IRN-1AwThg1PXRczu-Ll67HXrijUmZ7dZapzM"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgAEpABUoFaMX1RaNdvt2fnuEcIHiaHRmivwFfpTAB1PvRS3E77LodS7B0anbXkBAlf0isKtn+Cpy5Si98L3SsPoO8SGmnigtfPISn68lJ6OQZ4ADXOtI49RlWr2pZR6t1TVAdz2w9gBFK7bC4keBW3C9yHZ9CBqVxMMX+Cbd3z3byHSVuD4J9k2+dz9zq85WLvf0Svn/RtZMiYheY+OQyhbjVZ12jA60NL8Zbn5+6dCgyZb30r7e+2zOiC9XFt7ip4rjmV5Rd84OAwxhZRpg7L89Iv+ayGVVkdgOMG","device_id":"AOKSEIYZIB","sender_key":"NmM23XC1ZN1NdS7/0ZURWKQxnm9t7xaKYzKUnQ17nlc","session_id":"pUV3Ial9uQxjZZB2MW7oTIz8ANH6a9pc5+MBQLGlT+k"},"depth":13,"hashes":{"sha256":"+Aii0rm2kce5sSFEJz8vbQ4UWtmklEnLWCE0Kiwh054"},"origin_server_ts":1783584950260,"sender":"@ali:shikpooshaan.ir","type":"m.room.encrypted"}	3
$gYc_OPh-U8vTKbHPI-j-vjtTnnvaf8JHMKyZFvLCadk	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	{"device_id":"AOKSEIYZIB","txn_id":"a1e6e550ae3747fda5315e9971f8a1d3"}	{"signatures":{"shikpooshaan.ir":{"ed25519:a_nwch":"021lJriCY4Jqe2kq/qCQP9Aox12GaFnq1uTIRm6zlcAL4B+jRlxYQNZ6h+4h0qLrWO4cNec4ixAzSzlY6m3JDQ"}},"unsigned":{"age_ts":1783585298580},"room_id":"!DDSQZabMGckQpzuTFl:shikpooshaan.ir","auth_events":["$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY","$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ","$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ"],"prev_events":["$3Od6EvbJ4mccQ6S_C8DJjvNwFn7ihmJ4QE7N0Ug6w1I"],"content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgAErAHYHrRbZl7GJdFDCWZP2gj36gM21zUfntWmyKcQQAHpGyFGBZnoCf4pEhFNo3M8h3PuK86czOb4Ye/kDRtesRGRawoII9CO4wvMOi2qwlor77W/De7TLtLISEfBxfQ1/kXc0OcaNf0vjQic3dI5Y/Sl27rQ8wAuMVkYpCmMHVp+E5M+wWFIYdPACpzRp/lOB42XXPXOwRJZHL4hvyqmZ5vwbqSdMm9k86OUDVnP6PpQVsLT/dmH4mP2Qi8V04Z0TIHdhkPDpsG1TWB3eknH4+fQrMWCFYJ2LE5AeHmtVS2f2Pu6VR8g/dlmm+Mqu8qxn+77eA3t6KL8yKmVno8A2vnP+hvmGTgqyr0ES0GDCq0BXkKO3rnZGQmKOHiP3yE42mtyIRB3XUXwSnQvVLyu5A4NX6GHPgrMZHkL2Bfnpl8dENWFvkl4OBvg5gwllpDFYKVVY8zi4L2jlkHV1LFnEtYDPhLnH/dR9i2O9jTdIy9jGR5KijQmOPpjjYhDxuoNAjudtdU1SZwSCJ3+ahoJ+968wPuza7qDqzXWFqr2x+UmMTUGkk9nMNvmvnIBOV2mw2+l5wdhYBCrJHwu/CVdR8HLJOHBxDpjhc+leAApsrE+9Tb0NCeAPqdB7HTQj8lFsoJJRzQyPQSgWFWXQ/iK5hHWPexZod8Fe0GLpMXTAOUiFNbU9iSdpyuMBqLRYBspuCf0M9u6iFCX9nfJTMYhmhyFhYLE5ppMuqVUsH2av+ivRqtX9b4LISrqZ90yS/MH7vj5IrU+6EtJr5UXnVAq38N1wO8zuJtQChxJJZkx6oWXS0jGdjeRkuGuIToNJFNnKM0Hm4kflwqJ7H0rPJDTJRhphfsjw0FCKyq8FUmnkoxkBIFeCakul9OTSP6aAoRn3fwHCWBefFnp3mHQ9Bks/vS+b/tBPn1XZ4The38w1IovFhs1anY1SVy2iNDyWv8AVJuVHH92XG20rB8a9wtqPCw1IMWq+csupRN5oxIi6qfQrQxmFzcoWnYGfHBP4wqKLIol04hvemswO5bss824NQ61bNB6pX3Dja/hw+7fvjgDfZoYVAwV7OAtLDyzYKywStIIF1me+rw++fzJTfS7C5mjoXG3fKMCVVhJDx7iDzOo5WW9nTz2kdbyUOaTWaNAAT8HIQtq5SerJy5iPTsZ1txhTheBCpjwswQcbOJc9/Zn+dqi2JzjuKa2S5sINNnmEW/VBttrC1FcwfjS4scNrHOkprkqw+w3Wk+k2W3QzxbvPouM2/JSYM4EhdxmuaoxNl7cv/j/RNi0EZbyIZTH/7u0xlthMKkz/W0ySlsZc3HaLgk9lVBZQbnAXptb8Ew0EpfBYGzvshDigs","device_id":"AOKSEIYZIB","sender_key":"NmM23XC1ZN1NdS7/0ZURWKQxnm9t7xaKYzKUnQ17nlc","session_id":"YqZXWKUPQsFGfn7cohF69Ga2xup8NCxx5P7BbAccocw"},"depth":14,"hashes":{"sha256":"DxQ4pLeYluK3LmmBrBBICrucmVAz0/ibJ+AiikC1MvY"},"origin_server_ts":1783585298580,"sender":"@ali:shikpooshaan.ir","type":"m.room.encrypted"}	3
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
!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8	@testuser:shikpooshaan.ir	\N	["notify",{"set_tweak":"highlight","value":false},{"set_tweak":"sound","value":"default"}]	11	12	1	0	0	main
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
@testuser:shikpooshaan.ir	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	1	12	0	\N	main
@alextaylor:shikpooshaan.ir	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	0	15	0	15	main
@alextaylor:shikpooshaan.ir	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	0	33	0	34	main
\.


--
-- Data for Name: event_push_summary_last_receipt_stream_id; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_push_summary_last_receipt_stream_id (lock, stream_id) FROM stdin;
X	14
\.


--
-- Data for Name: event_push_summary_stream_ordering; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_push_summary_stream_ordering (lock, stream_ordering) FROM stdin;
X	34
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
$E97pMjZjzmrDM-hFyRwC6aqENPN3ixJigBn50-VhHEQ	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	content.name	'alex':1	1783579928790	9
\.


--
-- Data for Name: event_to_state_groups; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_to_state_groups (event_id, state_group) FROM stdin;
$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	2
$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	3
$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	4
$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs	5
$ovWXMhcqZ51rR0-mmT_ebzrZ3c9XWpr256lElWATA5g	6
$aGYMEi1KO534ezshtH0n3_XRs3OZXgi_DY26XrWFLTE	7
$4WW-qYRENg7ChGX-khhMVKLO2asWf8I7EKJWgnuEnMI	8
$E97pMjZjzmrDM-hFyRwC6aqENPN3ixJigBn50-VhHEQ	9
$owPa_25ew4CsxHc1lZakZoynscO0PsDgfqWSWzt7GA0	10
$pmZLd5201Kj0dO2jHeo7HR2HX3MoKEMeDXfHQpHmClc	10
$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8	11
$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM	12
$hJAqFBOtlfAGIpo0e2iPYUmyHUIpeGzHdhy2DOGL5M0	12
$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4	13
$Iy8smKso2nyVLpvpWF929j9Og8e4g79f6knC-jFSylY	13
$WFNOeNnqQFC6pvybcuiouNFeVdoahcKJBga0cY6VdXY	13
$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g	14
$KSmWWmQkmzexNXwiaQhMG6Ec2JDmy7jmZgmlGyXySL8	15
$B-bfbB05RV8t1MKB6YKPsn7xa-KawJRYs-lLGP2CEDI	16
$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ	18
$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	19
$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY	20
$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs	21
$9bQLGiDMN6cfZTQFKMEwuFSUDUIkIAELgVXodLQCCgg	22
$AM_7A_tNjjaTM9klUn_6ZPT43TZaWkerNTyPWRr1wWA	23
$q11DmpDEFKgMjbP76SMow-33zfL47mOYIebpAXwj7Yo	24
$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk	25
$tkhCzNBPYwhauxcDGd86lTAQzSTBjk9UCfQDl-Dcb94	25
$YVY2sBhRnasnpoMwSSbU88Fc-B7KTrQ3G-MMG_vAfEE	25
$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE	26
$xS0cI6IRN-1AwThg1PXRczu-Ll67HXrijUmZ7dZapzM	26
$3Od6EvbJ4mccQ6S_C8DJjvNwFn7ihmJ4QE7N0Ug6w1I	26
$gYc_OPh-U8vTKbHPI-j-vjtTnnvaf8JHMKyZFvLCadk	26
\.


--
-- Data for Name: event_txn_id_device_id; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.event_txn_id_device_id (event_id, room_id, user_id, device_id, txn_id, inserted_ts) FROM stdin;
$Iy8smKso2nyVLpvpWF929j9Og8e4g79f6knC-jFSylY	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	@alextaylor:shikpooshaan.ir	NBQWFWVCQE	888939ccf987401687c826248a5b9b6e	1783582699917
$WFNOeNnqQFC6pvybcuiouNFeVdoahcKJBga0cY6VdXY	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	@alextaylor:shikpooshaan.ir	NBQWFWVCQE	cf1a8b81bf0e438c8a442d52cf540c94	1783582703610
$tkhCzNBPYwhauxcDGd86lTAQzSTBjk9UCfQDl-Dcb94	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	@ali:shikpooshaan.ir	AOKSEIYZIB	a180d17f2a374f18af0068bc202bb384	1783583520205
$YVY2sBhRnasnpoMwSSbU88Fc-B7KTrQ3G-MMG_vAfEE	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	@ali:shikpooshaan.ir	AOKSEIYZIB	6ef927cfccc04ea9aa78d5e18d57fb40	1783583526788
$xS0cI6IRN-1AwThg1PXRczu-Ll67HXrijUmZ7dZapzM	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	@alextaylor:shikpooshaan.ir	NBQWFWVCQE	8eeeb2be092c4a95a0a44726ea09a681	1783583561526
$3Od6EvbJ4mccQ6S_C8DJjvNwFn7ihmJ4QE7N0Ug6w1I	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	@ali:shikpooshaan.ir	AOKSEIYZIB	8010a7606b7c4c7d8269b2e58e763ca9	1783584950361
$gYc_OPh-U8vTKbHPI-j-vjtTnnvaf8JHMKyZFvLCadk	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	@ali:shikpooshaan.ir	AOKSEIYZIB	a1e6e550ae3747fda5315e9971f8a1d3	1783585298735
\.


--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.events (topological_ordering, event_id, type, room_id, content, unrecognized_keys, processed, outlier, depth, origin_server_ts, received_ts, sender, contains_url, instance_name, stream_ordering, state_key, rejection_reason) FROM stdin;
1	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	m.room.create	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	1	1783579928230	1783579928369	@alextaylor:shikpooshaan.ir	f	master	2		\N
2	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	m.room.member	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	2	1783579928513	1783579928579	@alextaylor:shikpooshaan.ir	f	master	3	@alextaylor:shikpooshaan.ir	\N
3	$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	m.room.power_levels	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	3	1783579928732	1783579929068	@alextaylor:shikpooshaan.ir	f	master	4		\N
4	$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs	m.room.join_rules	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	4	1783579928782	1783579929068	@alextaylor:shikpooshaan.ir	f	master	5		\N
5	$ovWXMhcqZ51rR0-mmT_ebzrZ3c9XWpr256lElWATA5g	m.room.guest_access	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	5	1783579928784	1783579929068	@alextaylor:shikpooshaan.ir	f	master	6		\N
6	$aGYMEi1KO534ezshtH0n3_XRs3OZXgi_DY26XrWFLTE	m.room.encryption	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	6	1783579928786	1783579929068	@alextaylor:shikpooshaan.ir	f	master	7		\N
7	$4WW-qYRENg7ChGX-khhMVKLO2asWf8I7EKJWgnuEnMI	m.room.history_visibility	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	7	1783579928788	1783579929068	@alextaylor:shikpooshaan.ir	f	master	8		\N
8	$E97pMjZjzmrDM-hFyRwC6aqENPN3ixJigBn50-VhHEQ	m.room.name	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	8	1783579928790	1783579929068	@alextaylor:shikpooshaan.ir	f	master	9		\N
9	$owPa_25ew4CsxHc1lZakZoynscO0PsDgfqWSWzt7GA0	m.room.avatar	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	9	1783580573162	1783580573230	@alextaylor:shikpooshaan.ir	t	master	10		\N
10	$pmZLd5201Kj0dO2jHeo7HR2HX3MoKEMeDXfHQpHmClc	m.room.encrypted	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	10	1783580804417	1783580804507	@alextaylor:shikpooshaan.ir	f	master	11	\N	\N
11	$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8	m.room.member	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	11	1783582211822	1783582211973	@alextaylor:shikpooshaan.ir	f	master	12	@testuser:shikpooshaan.ir	\N
12	$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM	m.room.member	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	12	1783582218822	1783582218910	@testuser:shikpooshaan.ir	f	master	13	@testuser:shikpooshaan.ir	\N
13	$hJAqFBOtlfAGIpo0e2iPYUmyHUIpeGzHdhy2DOGL5M0	m.room.encrypted	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	13	1783582226427	1783582226513	@testuser:shikpooshaan.ir	f	master	14	\N	\N
14	$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4	m.room.member	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	14	1783582590751	1783582590838	@testuser:shikpooshaan.ir	f	master	15	@testuser:shikpooshaan.ir	\N
15	$Iy8smKso2nyVLpvpWF929j9Og8e4g79f6knC-jFSylY	m.room.redaction	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	15	1783582699832	1783582699911	@alextaylor:shikpooshaan.ir	f	master	16	\N	\N
16	$WFNOeNnqQFC6pvybcuiouNFeVdoahcKJBga0cY6VdXY	m.room.redaction	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	16	1783582703545	1783582703608	@alextaylor:shikpooshaan.ir	f	master	17	\N	\N
17	$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g	m.room.power_levels	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	17	1783582978384	1783582978479	@alextaylor:shikpooshaan.ir	f	master	18		\N
18	$KSmWWmQkmzexNXwiaQhMG6Ec2JDmy7jmZgmlGyXySL8	m.room.history_visibility	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	18	1783583005051	1783583005130	@alextaylor:shikpooshaan.ir	f	master	19		\N
19	$B-bfbB05RV8t1MKB6YKPsn7xa-KawJRYs-lLGP2CEDI	m.room.canonical_alias	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	\N	\N	t	f	19	1783583169621	1783583169711	@alextaylor:shikpooshaan.ir	f	master	20		\N
1	$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ	m.room.create	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	\N	\N	t	f	1	1783583512302	1783583512403	@ali:shikpooshaan.ir	f	master	21		\N
2	$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	m.room.member	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	\N	\N	t	f	2	1783583512517	1783583512588	@ali:shikpooshaan.ir	f	master	22	@ali:shikpooshaan.ir	\N
3	$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY	m.room.power_levels	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	\N	\N	t	f	3	1783583512720	1783583513000	@ali:shikpooshaan.ir	f	master	23		\N
4	$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs	m.room.join_rules	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	\N	\N	t	f	4	1783583512786	1783583513000	@ali:shikpooshaan.ir	f	master	24		\N
5	$9bQLGiDMN6cfZTQFKMEwuFSUDUIkIAELgVXodLQCCgg	m.room.guest_access	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	\N	\N	t	f	5	1783583512788	1783583513000	@ali:shikpooshaan.ir	f	master	25		\N
6	$AM_7A_tNjjaTM9klUn_6ZPT43TZaWkerNTyPWRr1wWA	m.room.encryption	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	\N	\N	t	f	6	1783583512790	1783583513000	@ali:shikpooshaan.ir	f	master	26		\N
7	$q11DmpDEFKgMjbP76SMow-33zfL47mOYIebpAXwj7Yo	m.room.history_visibility	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	\N	\N	t	f	7	1783583512792	1783583513000	@ali:shikpooshaan.ir	f	master	27		\N
8	$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk	m.room.member	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	\N	\N	t	f	8	1783583513158	1783583513284	@ali:shikpooshaan.ir	f	master	28	@alextaylor:shikpooshaan.ir	\N
9	$tkhCzNBPYwhauxcDGd86lTAQzSTBjk9UCfQDl-Dcb94	m.room.encrypted	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	\N	\N	t	f	9	1783583520133	1783583520199	@ali:shikpooshaan.ir	f	master	29	\N	\N
10	$YVY2sBhRnasnpoMwSSbU88Fc-B7KTrQ3G-MMG_vAfEE	m.room.encrypted	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	\N	\N	t	f	10	1783583526724	1783583526786	@ali:shikpooshaan.ir	f	master	30	\N	\N
11	$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE	m.room.member	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	\N	\N	t	f	11	1783583542175	1783583542259	@alextaylor:shikpooshaan.ir	f	master	31	@alextaylor:shikpooshaan.ir	\N
12	$xS0cI6IRN-1AwThg1PXRczu-Ll67HXrijUmZ7dZapzM	m.room.encrypted	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	\N	\N	t	f	12	1783583561464	1783583561522	@alextaylor:shikpooshaan.ir	f	master	32	\N	\N
13	$3Od6EvbJ4mccQ6S_C8DJjvNwFn7ihmJ4QE7N0Ug6w1I	m.room.encrypted	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	\N	\N	t	f	13	1783584950260	1783584950355	@ali:shikpooshaan.ir	f	master	33	\N	\N
14	$gYc_OPh-U8vTKbHPI-j-vjtTnnvaf8JHMKyZFvLCadk	m.room.encrypted	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	\N	\N	t	f	14	1783585298580	1783585298730	@ali:shikpooshaan.ir	f	master	34	\N	\N
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
events	34	master
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
!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	@alextaylor:shikpooshaan.ir	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	join	3
!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	@testuser:shikpooshaan.ir	$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4	leave	15
!DDSQZabMGckQpzuTFl:shikpooshaan.ir	@ali:shikpooshaan.ir	$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	join	22
!DDSQZabMGckQpzuTFl:shikpooshaan.ir	@alextaylor:shikpooshaan.ir	$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE	join	31
\.


--
-- Data for Name: local_media_repository; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.local_media_repository (media_id, media_type, media_length, created_ts, upload_name, user_id, quarantined_by, url_cache, last_access_ts, safe_from_quarantine, authenticated, sha256) FROM stdin;
BoAYGyMZwyNsclmSBMgpqwjS	application/octet-stream	23243	1783585271154	\N	@ali:shikpooshaan.ir	\N	\N	1783585356285	f	t	826127b4ae33a3946de8294c7867c2ef12875a064da52b1a2c665c02326511b9
EesfxWjMijXbeRymYcFIHHko	application/octet-stream	11509634	1783585298150	\N	@ali:shikpooshaan.ir	\N	\N	1783585356285	f	t	54f1889d511cd54c235ea7be9eb05e0efc6e2ead2c776cded388dfd5e303474c
nfwAoKkXAOYczxtRVqrApNgi	image/jpeg	168951	1783583223751	\N	@ali:shikpooshaan.ir	\N	\N	1783585356285	f	t	7e2cbf35e0535a43290321d084d0c369c0c2186703724bb25c12d77f0c7f6c31
fDJPwghfXSGFsTdrzTLFOeZK	application/octet-stream	9137	1783580803690	\N	@alextaylor:shikpooshaan.ir	\N	\N	1783582173482	f	t	cf83b58d1a5a6ab83c7f5331ca8491fe3c0e8f2faddb953c2131531a61715e55
LKhfOyhTLlAgUTeqMdnYBjKW	image/png	1005737	1783580570948	alexvpn.png	@alextaylor:shikpooshaan.ir	\N	\N	1783583553481	f	t	a07000f0b8bfd9caec8bb5d4a3e9348c93e25fd4d79acc3079c2c1ddd123d942
glIjKxJGeoRTJIFKjVpPMkEz	image/png	1005737	1783577671688	alexvpn.png	@alextaylor:shikpooshaan.ir	\N	\N	1783583553481	f	t	a07000f0b8bfd9caec8bb5d4a3e9348c93e25fd4d79acc3079c2c1ddd123d942
QpxFBMFuHqnPfUfACXWIPyab	application/octet-stream	34835	1783584792929	\N	@ali:shikpooshaan.ir	\N	\N	\N	f	t	7bd3c39a89e8f6743bd48a46bbd663d57d263cc4625bf5a5ab857dd64bc5d552
jOaAoSiykbgMlEYlpQrVVlNV	application/octet-stream	22590	1783583526146	\N	@ali:shikpooshaan.ir	\N	\N	1783584813507	f	t	d1bdd35235b3900224ad67586f51ecd4f0e88fc7ec9d86adbea2b1198c416330
fvmIpxfziCVijwUPIaIpYpxz	application/octet-stream	119838	1783583526498	\N	@ali:shikpooshaan.ir	\N	\N	1783584813507	f	t	735e4a4eaddab86ae9c2dd19e7761bd04d46485e633acea0be0877fb715181ac
StnrIascqAoNoTczCyujmEJx	application/octet-stream	17794	1783584929404	\N	@ali:shikpooshaan.ir	\N	\N	\N	f	t	2d864306c2c9cee6c086f7fe1564d2b6bdb3d7d18271486f8546b2a50dbb9f44
evjSQVubOoFvupWlULpRIZxh	application/octet-stream	20598	1783585012310	\N	@ali:shikpooshaan.ir	\N	\N	\N	f	t	c34caccb00f1af9b8d76f5c5f346fe982875922840f7cc974edc0eeb27af66a8
\.


--
-- Data for Name: local_media_repository_thumbnails; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.local_media_repository_thumbnails (media_id, thumbnail_width, thumbnail_height, thumbnail_type, thumbnail_method, thumbnail_length) FROM stdin;
glIjKxJGeoRTJIFKjVpPMkEz	32	32	image/png	crop	2809
glIjKxJGeoRTJIFKjVpPMkEz	96	96	image/png	crop	17965
glIjKxJGeoRTJIFKjVpPMkEz	240	240	image/png	scale	89804
glIjKxJGeoRTJIFKjVpPMkEz	480	480	image/png	scale	320872
glIjKxJGeoRTJIFKjVpPMkEz	600	600	image/png	scale	482974
LKhfOyhTLlAgUTeqMdnYBjKW	32	32	image/png	crop	2809
LKhfOyhTLlAgUTeqMdnYBjKW	96	96	image/png	crop	17965
LKhfOyhTLlAgUTeqMdnYBjKW	240	240	image/png	scale	89804
LKhfOyhTLlAgUTeqMdnYBjKW	480	480	image/png	scale	320872
LKhfOyhTLlAgUTeqMdnYBjKW	600	600	image/png	scale	482974
nfwAoKkXAOYczxtRVqrApNgi	32	32	image/jpeg	crop	1064
nfwAoKkXAOYczxtRVqrApNgi	96	96	image/jpeg	crop	4134
nfwAoKkXAOYczxtRVqrApNgi	160	240	image/jpeg	scale	13803
nfwAoKkXAOYczxtRVqrApNgi	320	480	image/jpeg	scale	47539
nfwAoKkXAOYczxtRVqrApNgi	400	600	image/jpeg	scale	70507
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
BFDAqhkZvEMpKFPHkzfEeCrt	1783586986637	@alextaylor:shikpooshaan.ir
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
339	@alextaylor:shikpooshaan.ir	unavailable	1783585504615	1783589781594	1783589844794	\N	t	master
186	@ali:shikpooshaan.ir	offline	1783585353103	1783585329838	0	\N	f	master
97	@testuser:shikpooshaan.ir	offline	1783582226094	1783582224138	0	\N	f	master
\.


--
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.profiles (user_id, displayname, avatar_url, full_user_id, fields) FROM stdin;
root	root	\N	@root:shikpooshaan.ir	\N
brian	brian	\N	@brian:shikpooshaan.ir	\N
ali	ali	mxc://shikpooshaan.ir/nfwAoKkXAOYczxtRVqrApNgi	@ali:shikpooshaan.ir	\N
alextaylor	alextaylor	mxc://shikpooshaan.ir/glIjKxJGeoRTJIFKjVpPMkEz	@alextaylor:shikpooshaan.ir	{"m.tz": "Asia/Tehran", "us.cloke.msc4175.tz": "Asia/Tehran"}
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
10	@ali:shikpooshaan.ir	\N	mobile_	http	im.vector.app.android	Element X	MyDevice	cXRzOJQKSF-uUKfMghugq0	1783582885824	en	{"url":"https://matrix.org/_matrix/push/v1/notify","format":"event_id_only","default_payload":{"cs":"cd96b787-0f57-4b62-9118-67b1e08acf4c"}}	32	1783583561826	\N	t	AOKSEIYZIB	master
11	@alextaylor:shikpooshaan.ir	\N	OL1jYooNkt7g7x80	http	io.element.elementx.ios.prod	Element X (iOS)	iPhone	YszfQ3Tmn0GYwcgPX3fDqCJd93Xo+UflkH2eidHi1Xs=	1783586101667	en-US	{"url":"https://matrix.org/_matrix/push/v1/notify","format":"event_id_only","default_payload":{"aps":{"alert":{"loc-args":[],"loc-key":"Notification"},"mutable-content":1},"pusher_notification_client_identifier":"db42e96c38cbb41b857dbf32b63b3cb97106cff6ee7dbd253c054581cb4b8012"}}	34	1783585299691	\N	t	NBQWFWVCQE	master
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
!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.read	@alextaylor:shikpooshaan.ir	["$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4"]	{"ts":1783582650764}	main
!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.read	@ali:shikpooshaan.ir	["$xS0cI6IRN-1AwThg1PXRczu-Ll67HXrijUmZ7dZapzM"]	{"ts":1783583561901}	\N
!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.read	@alextaylor:shikpooshaan.ir	["$gYc_OPh-U8vTKbHPI-j-vjtTnnvaf8JHMKyZFvLCadk"]	{"ts":1783585304217}	main
\.


--
-- Data for Name: receipts_linearized; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.receipts_linearized (stream_id, room_id, receipt_type, user_id, event_id, data, instance_name, event_stream_ordering, thread_id) FROM stdin;
9	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.read	@alextaylor:shikpooshaan.ir	$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4	{"ts":1783582650764}	master	15	main
11	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.read	@ali:shikpooshaan.ir	$xS0cI6IRN-1AwThg1PXRczu-Ll67HXrijUmZ7dZapzM	{"ts":1783583561901}	master	32	\N
14	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.read	@alextaylor:shikpooshaan.ir	$gYc_OPh-U8vTKbHPI-j-vjtTnnvaf8JHMKyZFvLCadk	{"ts":1783585304217}	master	34	main
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
$Iy8smKso2nyVLpvpWF929j9Og8e4g79f6knC-jFSylY	$hJAqFBOtlfAGIpo0e2iPYUmyHUIpeGzHdhy2DOGL5M0	f	1783582699927	f
$WFNOeNnqQFC6pvybcuiouNFeVdoahcKJBga0cY6VdXY	$pmZLd5201Kj0dO2jHeo7HR2HX3MoKEMeDXfHQpHmClc	f	1783582703616	f
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
@alextaylor:shikpooshaan.ir	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.fully_read	51	{"event_id":"$B-bfbB05RV8t1MKB6YKPsn7xa-KawJRYs-lLGP2CEDI"}	\N
@alextaylor:shikpooshaan.ir	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.fully_read	56	{"event_id":"$gYc_OPh-U8vTKbHPI-j-vjtTnnvaf8JHMKyZFvLCadk"}	\N
@ali:shikpooshaan.ir	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.fully_read	57	{"event_id":"$gYc_OPh-U8vTKbHPI-j-vjtTnnvaf8JHMKyZFvLCadk"}	\N
\.


--
-- Data for Name: room_alias_servers; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.room_alias_servers (room_alias, server) FROM stdin;
#my-room:shikpooshaan.ir	shikpooshaan.ir
\.


--
-- Data for Name: room_aliases; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.room_aliases (room_alias, room_id, creator) FROM stdin;
#my-room:shikpooshaan.ir	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	@alextaylor:shikpooshaan.ir
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
!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	1
!DDSQZabMGckQpzuTFl:shikpooshaan.ir	1
\.


--
-- Data for Name: room_forgetter_stream_pos; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.room_forgetter_stream_pos (lock, stream_id) FROM stdin;
X	34
\.


--
-- Data for Name: room_memberships; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.room_memberships (event_id, user_id, sender, room_id, membership, forgotten, display_name, avatar_url, event_stream_ordering, participant) FROM stdin;
$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	@alextaylor:shikpooshaan.ir	@alextaylor:shikpooshaan.ir	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	join	0	alextaylor	mxc://shikpooshaan.ir/glIjKxJGeoRTJIFKjVpPMkEz	3	t
$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8	@testuser:shikpooshaan.ir	@alextaylor:shikpooshaan.ir	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	invite	1	testuser	\N	12	f
$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM	@testuser:shikpooshaan.ir	@testuser:shikpooshaan.ir	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	join	1	testuser	\N	13	t
$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4	@testuser:shikpooshaan.ir	@testuser:shikpooshaan.ir	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	leave	1	\N	\N	15	f
$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk	@alextaylor:shikpooshaan.ir	@ali:shikpooshaan.ir	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	invite	0	alextaylor	mxc://shikpooshaan.ir/glIjKxJGeoRTJIFKjVpPMkEz	28	f
$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	@ali:shikpooshaan.ir	@ali:shikpooshaan.ir	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	join	0	ali	mxc://shikpooshaan.ir/nfwAoKkXAOYczxtRVqrApNgi	22	t
$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE	@alextaylor:shikpooshaan.ir	@alextaylor:shikpooshaan.ir	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	join	0	alextaylor	mxc://shikpooshaan.ir/glIjKxJGeoRTJIFKjVpPMkEz	31	t
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
!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	11	1	0	1	0	1	20	0
!DDSQZabMGckQpzuTFl:shikpooshaan.ir	8	2	0	0	0	2	31	0
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
!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	alex	#my-room:shikpooshaan.ir	invite	shared	m.megolm.v1.aes-sha2	mxc://shikpooshaan.ir/LKhfOyhTLlAgUTeqMdnYBjKW	can_join	t	\N	\N
!DDSQZabMGckQpzuTFl:shikpooshaan.ir	\N	\N	invite	invited	m.megolm.v1.aes-sha2	\N	can_join	t	\N	\N
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
!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	f	@alextaylor:shikpooshaan.ir	10	t
!DDSQZabMGckQpzuTFl:shikpooshaan.ir	f	@ali:shikpooshaan.ir	10	t
\.


--
-- Data for Name: scheduled_tasks; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.scheduled_tasks (id, action, status, "timestamp", resource_id, params, result, error) FROM stdin;
delete_old_otks_task	delete_old_otks	complete	1783577038375	\N	\N	\N	\N
CCawcseuGTZaHVXF	update_join_states	complete	1783577673042	@alextaylor:shikpooshaan.ir	{"requester_authenticated_entity":"@alextaylor:shikpooshaan.ir"}	\N	\N
IqzTqdGxUqYnVOzV	update_join_states	complete	1783583224493	@ali:shikpooshaan.ir	{"requester_authenticated_entity":"@ali:shikpooshaan.ir"}	\N	\N
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
2	\N	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	@alextaylor:shikpooshaan.ir	1783582219318
4	7	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	@testuser:shikpooshaan.ir	1783582228543
1	\N	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	@testuser:shikpooshaan.ir	1783582233681
5	\N	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	@testuser:shikpooshaan.ir	1783582639947
6	\N	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	@alextaylor:shikpooshaan.ir	1783583513509
5	\N	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	@ali:shikpooshaan.ir	1783583542901
8	17	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	@alextaylor:shikpooshaan.ir	1783583562197
10	19	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	@ali:shikpooshaan.ir	1783585300532
\.


--
-- Data for Name: sliding_sync_connection_positions; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.sliding_sync_connection_positions (connection_position, connection_key, created_ts) FROM stdin;
4	3	1783582213715
6	2	1783582219514
7	4	1783582228536
8	1	1783582233673
13	6	1783583514145
16	5	1783583542894
17	8	1783583562192
19	10	1783585300526
\.


--
-- Data for Name: sliding_sync_connection_required_state; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.sliding_sync_connection_required_state (required_state_id, connection_key, required_state) FROM stdin;
2	1	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.history_visibility",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.pinned_events",""],["m.room.power_levels",""],["m.room.tombstone",""],["m.room.topic",""],["m.space.child","*"],["m.space.parent","*"],["org.matrix.msc3401.call.member","*"],["org.matrix.msc3672.beacon_info","*"]]
4	3	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.power_levels",""],["org.matrix.msc3401.call.member","*"]]
5	2	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.history_visibility",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.pinned_events",""],["m.room.power_levels",""],["m.room.tombstone",""],["m.room.topic",""],["m.space.child","*"],["m.space.parent","*"],["org.matrix.msc3401.call.member","*"],["org.matrix.msc3672.beacon_info","*"]]
6	4	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.power_levels",""],["org.matrix.msc3401.call.member","*"]]
8	5	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.history_visibility",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.pinned_events",""],["m.room.power_levels",""],["m.room.tombstone",""],["m.room.topic",""],["m.space.child","*"],["m.space.parent","*"],["org.matrix.msc3401.call.member","*"],["org.matrix.msc3672.beacon_info","*"]]
10	6	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.history_visibility",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.pinned_events",""],["m.room.power_levels",""],["m.room.tombstone",""],["m.room.topic",""],["m.space.child","*"],["m.space.parent","*"],["org.matrix.msc3401.call.member","*"],["org.matrix.msc3672.beacon_info","*"]]
13	8	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.power_levels",""],["org.matrix.msc3401.call.member","*"]]
15	10	[["io.element.functional_members",""],["m.room.avatar",""],["m.room.canonical_alias",""],["m.room.create",""],["m.room.encryption",""],["m.room.join_rules",""],["m.room.member","$LAZY"],["m.room.member","$ME"],["m.room.name",""],["m.room.power_levels",""],["org.matrix.msc3401.call.member","*"]]
\.


--
-- Data for Name: sliding_sync_connection_room_configs; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.sliding_sync_connection_room_configs (connection_position, room_id, timeline_limit, required_state_id) FROM stdin;
4	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	16	4
6	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	20	5
7	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	16	6
8	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	20	2
13	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	20	10
16	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	20	8
16	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	20	8
17	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	16	13
19	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	16	15
\.


--
-- Data for Name: sliding_sync_connection_streams; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.sliding_sync_connection_streams (connection_position, stream, room_id, room_status, last_token) FROM stdin;
4	rooms	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	live	\N
4	account_data	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	live	\N
6	rooms	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	live	\N
6	receipts	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	live	\N
6	account_data	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	live	\N
7	rooms	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	live	\N
7	account_data	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	live	\N
8	rooms	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	live	\N
8	receipts	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	live	\N
8	account_data	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	live	\N
13	rooms	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	live	\N
13	receipts	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	live	\N
13	account_data	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	live	\N
16	rooms	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	live	\N
16	receipts	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	live	\N
16	account_data	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	live	\N
16	rooms	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	live	\N
16	receipts	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	live	\N
16	account_data	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	live	\N
17	rooms	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	live	\N
17	account_data	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	live	\N
19	rooms	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	live	\N
19	account_data	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	live	\N
\.


--
-- Data for Name: sliding_sync_connections; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.sliding_sync_connections (connection_key, user_id, effective_device_id, conn_id, created_ts, last_used_ts) FROM stdin;
2	@testuser:shikpooshaan.ir	LLRGRFFCEG	room-list	1783582212271	1783582212271
3	@testuser:shikpooshaan.ir	LLRGRFFCEG	notifications	1783582213713	1783582213713
4	@alextaylor:shikpooshaan.ir	INWEZSCLYH	notifications	1783582228534	1783582228534
1	@alextaylor:shikpooshaan.ir	INWEZSCLYH	room-list	1783580461122	1783582233615
8	@ali:shikpooshaan.ir	AOKSEIYZIB	notifications	1783583562191	1783583562191
5	@alextaylor:shikpooshaan.ir	NBQWFWVCQE	room-list	1783582639928	1783585158078
10	@alextaylor:shikpooshaan.ir	NBQWFWVCQE	notifications	1783585300525	1783585300525
6	@ali:shikpooshaan.ir	AOKSEIYZIB	room-list	1783583512900	1783587851959
\.


--
-- Data for Name: sliding_sync_joined_rooms; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.sliding_sync_joined_rooms (room_id, event_stream_ordering, bump_stamp, room_type, room_name, is_encrypted, tombstone_successor_room_id) FROM stdin;
!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	20	14	\N	alex	t	\N
!DDSQZabMGckQpzuTFl:shikpooshaan.ir	34	34	\N	\N	t	\N
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
!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	@alextaylor:shikpooshaan.ir	@alextaylor:shikpooshaan.ir	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	join	0	3	master	t	\N	\N	f	\N
!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	@testuser:shikpooshaan.ir	@testuser:shikpooshaan.ir	$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4	leave	1	15	master	t	\N	alex	t	\N
!DDSQZabMGckQpzuTFl:shikpooshaan.ir	@ali:shikpooshaan.ir	@ali:shikpooshaan.ir	$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	join	0	22	master	t	\N	\N	f	\N
!DDSQZabMGckQpzuTFl:shikpooshaan.ir	@alextaylor:shikpooshaan.ir	@alextaylor:shikpooshaan.ir	$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE	join	0	31	master	t	\N	\N	t	\N
\.


--
-- Data for Name: state_events; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.state_events (event_id, room_id, type, state_key, prev_state) FROM stdin;
$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.create		\N
$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.member	@alextaylor:shikpooshaan.ir	\N
$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.power_levels		\N
$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.join_rules		\N
$ovWXMhcqZ51rR0-mmT_ebzrZ3c9XWpr256lElWATA5g	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.guest_access		\N
$aGYMEi1KO534ezshtH0n3_XRs3OZXgi_DY26XrWFLTE	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.encryption		\N
$4WW-qYRENg7ChGX-khhMVKLO2asWf8I7EKJWgnuEnMI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.history_visibility		\N
$E97pMjZjzmrDM-hFyRwC6aqENPN3ixJigBn50-VhHEQ	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.name		\N
$owPa_25ew4CsxHc1lZakZoynscO0PsDgfqWSWzt7GA0	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.avatar		\N
$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.member	@testuser:shikpooshaan.ir	\N
$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.member	@testuser:shikpooshaan.ir	\N
$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.member	@testuser:shikpooshaan.ir	\N
$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.power_levels		\N
$KSmWWmQkmzexNXwiaQhMG6Ec2JDmy7jmZgmlGyXySL8	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.history_visibility		\N
$B-bfbB05RV8t1MKB6YKPsn7xa-KawJRYs-lLGP2CEDI	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.canonical_alias		\N
$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.create		\N
$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.member	@ali:shikpooshaan.ir	\N
$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.power_levels		\N
$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.join_rules		\N
$9bQLGiDMN6cfZTQFKMEwuFSUDUIkIAELgVXodLQCCgg	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.guest_access		\N
$AM_7A_tNjjaTM9klUn_6ZPT43TZaWkerNTyPWRr1wWA	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.encryption		\N
$q11DmpDEFKgMjbP76SMow-33zfL47mOYIebpAXwj7Yo	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.history_visibility		\N
$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.member	@alextaylor:shikpooshaan.ir	\N
$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.member	@alextaylor:shikpooshaan.ir	\N
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
12	11
13	12
14	13
15	14
16	15
18	17
19	18
20	19
21	20
22	21
23	22
24	23
25	24
26	25
\.


--
-- Data for Name: state_groups; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.state_groups (id, room_id, event_id) FROM stdin;
1	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI
2	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI
3	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ
4	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI
5	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs
6	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$ovWXMhcqZ51rR0-mmT_ebzrZ3c9XWpr256lElWATA5g
7	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$aGYMEi1KO534ezshtH0n3_XRs3OZXgi_DY26XrWFLTE
8	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$4WW-qYRENg7ChGX-khhMVKLO2asWf8I7EKJWgnuEnMI
9	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$E97pMjZjzmrDM-hFyRwC6aqENPN3ixJigBn50-VhHEQ
10	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$owPa_25ew4CsxHc1lZakZoynscO0PsDgfqWSWzt7GA0
11	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8
12	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM
13	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4
14	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g
15	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$KSmWWmQkmzexNXwiaQhMG6Ec2JDmy7jmZgmlGyXySL8
16	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$B-bfbB05RV8t1MKB6YKPsn7xa-KawJRYs-lLGP2CEDI
17	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ
18	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ
19	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ
20	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY
21	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs
22	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$9bQLGiDMN6cfZTQFKMEwuFSUDUIkIAELgVXodLQCCgg
23	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$AM_7A_tNjjaTM9klUn_6ZPT43TZaWkerNTyPWRr1wWA
24	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$q11DmpDEFKgMjbP76SMow-33zfL47mOYIebpAXwj7Yo
25	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk
26	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE
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
2	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.create		$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI
3	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.member	@alextaylor:shikpooshaan.ir	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ
4	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.power_levels		$VtCG0DEqULjgPGTcXhQFh8_LSdI2YKLMMSbzZJuSkAI
5	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.join_rules		$VhS2RdrhdTuhACK_QXTm03gYtr0-TbWxKtJJVL64DBs
6	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.guest_access		$ovWXMhcqZ51rR0-mmT_ebzrZ3c9XWpr256lElWATA5g
7	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.encryption		$aGYMEi1KO534ezshtH0n3_XRs3OZXgi_DY26XrWFLTE
8	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.history_visibility		$4WW-qYRENg7ChGX-khhMVKLO2asWf8I7EKJWgnuEnMI
9	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.name		$E97pMjZjzmrDM-hFyRwC6aqENPN3ixJigBn50-VhHEQ
10	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.avatar		$owPa_25ew4CsxHc1lZakZoynscO0PsDgfqWSWzt7GA0
11	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.member	@testuser:shikpooshaan.ir	$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8
12	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.member	@testuser:shikpooshaan.ir	$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM
13	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.member	@testuser:shikpooshaan.ir	$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4
14	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.power_levels		$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g
15	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.history_visibility		$KSmWWmQkmzexNXwiaQhMG6Ec2JDmy7jmZgmlGyXySL8
16	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	m.room.canonical_alias		$B-bfbB05RV8t1MKB6YKPsn7xa-KawJRYs-lLGP2CEDI
18	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.create		$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ
19	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.member	@ali:shikpooshaan.ir	$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ
20	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.power_levels		$N9DKdC892I-TtX8rnvVWIX4FixBMf1oRtpFliPkE1JY
21	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.join_rules		$_gJMjn8K4qDlvGGs3S4J5op8Ty511RpUVuIyDGmmpYs
22	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.guest_access		$9bQLGiDMN6cfZTQFKMEwuFSUDUIkIAELgVXodLQCCgg
23	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.encryption		$AM_7A_tNjjaTM9klUn_6ZPT43TZaWkerNTyPWRr1wWA
24	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.history_visibility		$q11DmpDEFKgMjbP76SMow-33zfL47mOYIebpAXwj7Yo
25	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.member	@alextaylor:shikpooshaan.ir	$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk
26	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	m.room.member	@alextaylor:shikpooshaan.ir	$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE
\.


--
-- Data for Name: stats_incremental_position; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.stats_incremental_position (lock, stream_id) FROM stdin;
X	34
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
2	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$DS3EZk7O9EOz8QW4GEY28ScsKV_MEPC_D75YA5BlxDI
3	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$TVJ-LeHVZCNrG9zaUYgsSoK_n-YlCd1bhD1abJx6vlQ
9	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$E97pMjZjzmrDM-hFyRwC6aqENPN3ixJigBn50-VhHEQ
10	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$owPa_25ew4CsxHc1lZakZoynscO0PsDgfqWSWzt7GA0
11	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$pmZLd5201Kj0dO2jHeo7HR2HX3MoKEMeDXfHQpHmClc
12	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$vYLvj-BLlDQ9t2w3IZKeO99-0jA5RMf89RjB82gsII8
13	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$2_tnpwOBlmo_xju_LH47vSgDaUFxRoCpHUAF_9kjToM
14	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$hJAqFBOtlfAGIpo0e2iPYUmyHUIpeGzHdhy2DOGL5M0
15	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$T1iyidheG85DBfZAVbOCIGMWvue7WTIwUkRcDItFKW4
16	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$Iy8smKso2nyVLpvpWF929j9Og8e4g79f6knC-jFSylY
17	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$WFNOeNnqQFC6pvybcuiouNFeVdoahcKJBga0cY6VdXY
18	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$oH25QbhZiibvFa0P--DxF74wskWHlp0Fv5FJ9vxkM9g
19	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$KSmWWmQkmzexNXwiaQhMG6Ec2JDmy7jmZgmlGyXySL8
20	!jvvDKiQEPqzLWBhJvT:shikpooshaan.ir	$B-bfbB05RV8t1MKB6YKPsn7xa-KawJRYs-lLGP2CEDI
21	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$03a3TO8czhgkm6FmCivE77XZyaM73gZSswambe-TMUQ
22	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$LKA_fN00V-oXVQWRI3zwqnaT-smWFIzmtnjW90XatRQ
27	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$q11DmpDEFKgMjbP76SMow-33zfL47mOYIebpAXwj7Yo
28	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$khA8gFsPv5Gdi_0r_QeX5g1jcOj_CDigFwQoujfqtmk
29	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$tkhCzNBPYwhauxcDGd86lTAQzSTBjk9UCfQDl-Dcb94
30	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$YVY2sBhRnasnpoMwSSbU88Fc-B7KTrQ3G-MMG_vAfEE
31	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$5mG25X4vK9cc26UDGdOYMZV20iUNThrdY35f0e0zbVE
32	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$xS0cI6IRN-1AwThg1PXRczu-Ll67HXrijUmZ7dZapzM
33	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$3Od6EvbJ4mccQ6S_C8DJjvNwFn7ihmJ4QE7N0Ug6w1I
34	!DDSQZabMGckQpzuTFl:shikpooshaan.ir	$gYc_OPh-U8vTKbHPI-j-vjtTnnvaf8JHMKyZFvLCadk
\.


--
-- Data for Name: stream_positions; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.stream_positions (stream_name, instance_name, stream_id) FROM stdin;
device_lists_stream	master	37
pushers	master	11
presence_stream	master	339
to_device	master	83
events	master	34
receipts	master	14
account_data	master	57
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
UeKALeXQTaNizWMVpKBuYVfn	1783579300496	{"request_user_id":"@alextaylor:shikpooshaan.ir"}	{"devices":["WMVHAWVONL"]}	/_matrix/client/v3/delete_devices	POST	remove device(s) from your account
kTJnWgtTkiIEQIQVUQBjXlmp	1783581435496	{"registered_user_id":"@testuser:shikpooshaan.ir"}	{"username":"testuser"}	/_matrix/client/v3/register	POST	register a new account
gyitpLmamFkVciuXuxjEDPUi	1783582589647	{"request_user_id":"@testuser:shikpooshaan.ir"}	{"erase":true}	/_matrix/client/v3/account/deactivate	POST	deactivate your account
ipqboDrGSitBVAYcxLCmztzJ	1783582589731	{"request_user_id":"@testuser:shikpooshaan.ir"}	{"erase":true}	/_matrix/client/v3/account/deactivate	POST	deactivate your account
\.


--
-- Data for Name: ui_auth_sessions_credentials; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.ui_auth_sessions_credentials (session_id, stage_type, result) FROM stdin;
UeKALeXQTaNizWMVpKBuYVfn	m.login.password	"@alextaylor:shikpooshaan.ir"
kTJnWgtTkiIEQIQVUQBjXlmp	m.login.dummy	true
ipqboDrGSitBVAYcxLCmztzJ	m.login.password	"@testuser:shikpooshaan.ir"
\.


--
-- Data for Name: ui_auth_sessions_ips; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.ui_auth_sessions_ips (session_id, ip, user_agent) FROM stdin;
UeKALeXQTaNizWMVpKBuYVfn	5.200.126.139	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36
kTJnWgtTkiIEQIQVUQBjXlmp	45.129.36.41	curl/7.81.0
gyitpLmamFkVciuXuxjEDPUi	94.24.18.95	Element X/26.06.1 (iPhone 14 Pro Max; iOS 26.5.2; Scale/3.00)
ipqboDrGSitBVAYcxLCmztzJ	94.24.18.95	Element X/26.06.1 (iPhone 14 Pro Max; iOS 26.5.2; Scale/3.00)
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
@alextaylor:shikpooshaan.ir	HKTASTBOAS	1783555200000	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36
@alextaylor:shikpooshaan.ir	INWEZSCLYH	1783555200000	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)
@alextaylor:shikpooshaan.ir	UJHQSRLCJP	1783555200000	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Element/1.12.23 Chrome/148.0.7778.265 Electron/42.4.1 Safari/537.36
@testuser:shikpooshaan.ir	LLRGRFFCEG	1783555200000	Element X/26.06.1 (iPhone 14 Pro Max; iOS 26.5.2; Scale/3.00)
@alextaylor:shikpooshaan.ir	NBQWFWVCQE	1783555200000	Element X/26.06.1 (iPhone 14 Pro Max; iOS 26.5.2; Scale/3.00)
@ali:shikpooshaan.ir	AOKSEIYZIB	1783555200000	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)
\.


--
-- Data for Name: user_directory; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.user_directory (user_id, room_id, display_name, avatar_url) FROM stdin;
@alextaylor:shikpooshaan.ir	\N	alextaylor	mxc://shikpooshaan.ir/glIjKxJGeoRTJIFKjVpPMkEz
@root:shikpooshaan.ir	\N	root	\N
@brian:shikpooshaan.ir	\N	brian	\N
@ali:shikpooshaan.ir	\N	ali	mxc://shikpooshaan.ir/nfwAoKkXAOYczxtRVqrApNgi
\.


--
-- Data for Name: user_directory_search; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.user_directory_search (user_id, vector) FROM stdin;
@alextaylor:shikpooshaan.ir	'alextaylor':1A,3B 'shikpooshaan.ir':2
@root:shikpooshaan.ir	'root':1A,3B 'shikpooshaan.ir':2
@brian:shikpooshaan.ir	'brian':1A,3B 'shikpooshaan.ir':2
@ali:shikpooshaan.ir	'ali':1A,3B 'shikpooshaan.ir':2
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
X	34
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
alextaylor	0	\\x7b22726f6f6d223a7b227374617465223a7b226c617a795f6c6f61645f6d656d62657273223a747275657d2c2274696d656c696e65223a7b22756e726561645f7468726561645f6e6f74696669636174696f6e73223a747275657d7d7d	@alextaylor:shikpooshaan.ir
\.


--
-- Data for Name: user_ips; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.user_ips (user_id, access_token, device_id, ip, user_agent, last_seen) FROM stdin;
@alextaylor:shikpooshaan.ir	syt_YWxleHRheWxvcg_kxBflEEVbQtDsWSfPzMj_0dzEQq	HKTASTBOAS	5.200.126.139	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36	1783579376217
@alextaylor:shikpooshaan.ir	syt_YWxleHRheWxvcg_kxBflEEVbQtDsWSfPzMj_0dzEQq	HKTASTBOAS	217.28.137.165	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36	1783589781593
@alextaylor:shikpooshaan.ir	syt_YWxleHRheWxvcg_gKhXjovodtgFzQRVcQPc_07hlv8	UJHQSRLCJP	217.28.137.165	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Element/1.12.23 Chrome/148.0.7778.265 Electron/42.4.1 Safari/537.36	1783589782085
@alextaylor:shikpooshaan.ir	syt_YWxleHRheWxvcg_XxMdgbFXDaYoWfheXumt_06005E	NBQWFWVCQE	94.24.18.95	Element X/26.06.1 (iPhone 14 Pro Max; iOS 26.5.2; Scale/3.00)	1783587842303
@testuser:shikpooshaan.ir	syt_dGVzdHVzZXI_GLyMyObmyOPPHFSBCYcj_2EZTsJ	LLRGRFFCEG	94.24.18.95	Element X/26.06.1 (iPhone 14 Pro Max; iOS 26.5.2; Scale/3.00)	1783582569631
@ali:shikpooshaan.ir	syt_YWxp_iksAmmNrgJKCMhAvfZhn_02ul38	AOKSEIYZIB	5.121.245.67	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)	1783587851943
@alextaylor:shikpooshaan.ir	syt_YWxleHRheWxvcg_LEthJJLigshrZihUhQVj_1ljIdP	INWEZSCLYH	168.222.49.232	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)	1783582824728
@alextaylor:shikpooshaan.ir	syt_YWxleHRheWxvcg_LEthJJLigshrZihUhQVj_1ljIdP	INWEZSCLYH	5.121.245.67	Element X/26.07.0 (samsung SM-A165F; Android 16; BP4A.251205.006.A165FXXSADZF2; Sdk 023f5bdce)	1783582832351
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
5	@alextaylor:shikpooshaan.ir	["@alextaylor:shikpooshaan.ir"]	master
18	@testuser:shikpooshaan.ir	["@testuser:shikpooshaan.ir"]	master
35	@ali:shikpooshaan.ir	["@ali:shikpooshaan.ir"]	master
\.


--
-- Data for Name: user_stats_current; Type: TABLE DATA; Schema: public; Owner: synapse
--

COPY public.user_stats_current (user_id, joined_rooms, completed_delta_stream_id) FROM stdin;
@root:shikpooshaan.ir	0	4
@brian:shikpooshaan.ir	0	13
@testuser:shikpooshaan.ir	0	15
@ali:shikpooshaan.ir	1	22
@alextaylor:shikpooshaan.ir	2	31
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
@alextaylor:shikpooshaan.ir	$2b$12$wNkShx/zgDImwKfjJSNpAerQT28qu9HexovUZJXyuZ.zZmUYGU1Wa	1783577190	1	\N	0	\N	\N	\N	\N	0	f	\N	t	f	f
@root:shikpooshaan.ir	$2b$12$TzK/TdnxEdu/AQXU31W.YOudI8tEhUKez7dmHyVF1xJWkb8Mn4U4i	1783580129	1	\N	0	\N	\N	\N	\N	0	f	\N	t	f	f
@brian:shikpooshaan.ir	$2b$12$XOInWQT1GxvtmJCA5cubPutTbY5gO7RncDeuai0E3LPOZBpbErgau	1783582359	0	\N	0	\N	\N	\N	\N	0	f	\N	t	f	f
@testuser:shikpooshaan.ir	\N	1783581744	0	\N	0	\N	\N	\N	\N	1	f	\N	t	f	f
@ali:shikpooshaan.ir	$2b$12$aNDmMMFhzpyETH8KjR6lY.R8hVhqso3f8BjMI4A9gM3uJG.imDnbW	1783582816	0	\N	0	\N	\N	\N	\N	0	f	\N	t	f	f
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
@ali:shikpooshaan.ir	@alextaylor:shikpooshaan.ir	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
@alextaylor:shikpooshaan.ir	@ali:shikpooshaan.ir	!DDSQZabMGckQpzuTFl:shikpooshaan.ir
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

SELECT pg_catalog.setval('public.account_data_sequence', 57, true);


--
-- Name: application_services_txn_id_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.application_services_txn_id_seq', 1, false);


--
-- Name: cache_invalidation_stream_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.cache_invalidation_stream_seq', 142, true);


--
-- Name: device_inbox_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.device_inbox_sequence', 83, true);


--
-- Name: device_lists_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.device_lists_sequence', 37, true);


--
-- Name: e2e_cross_signing_keys_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.e2e_cross_signing_keys_sequence', 10, true);


--
-- Name: event_auth_chain_id; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.event_auth_chain_id', 20, true);


--
-- Name: events_backfill_stream_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.events_backfill_stream_seq', 1, true);


--
-- Name: events_stream_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.events_stream_seq', 34, true);


--
-- Name: instance_map_instance_id_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.instance_map_instance_id_seq', 1, false);


--
-- Name: presence_stream_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.presence_stream_sequence', 339, true);


--
-- Name: push_rules_stream_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.push_rules_stream_sequence', 1, true);


--
-- Name: pushers_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.pushers_sequence', 11, true);


--
-- Name: quarantined_media_id_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.quarantined_media_id_seq', 1, true);


--
-- Name: receipts_sequence; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.receipts_sequence', 14, true);


--
-- Name: sliding_sync_connection_positions_connection_position_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.sliding_sync_connection_positions_connection_position_seq', 19, true);


--
-- Name: sliding_sync_connection_required_state_required_state_id_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.sliding_sync_connection_required_state_required_state_id_seq', 15, true);


--
-- Name: sliding_sync_connections_connection_key_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.sliding_sync_connections_connection_key_seq', 10, true);


--
-- Name: state_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: synapse
--

SELECT pg_catalog.setval('public.state_group_id_seq', 26, true);


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

\unrestrict 8DWfkbK7nSP9pL5BE5DDnorsbpF5S3MFIEnye6XgcZ7vpQL8kCUU94uhAEZ9dHh

