-- 1. Create tables and insert initial data
DROP TABLE IF EXISTS reservations;
DROP TABLE IF EXISTS lab_sessions;

CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    session_name VARCHAR(100),
    available_workstations INT
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INT REFERENCES lab_sessions(session_id),
    lecturer_name VARCHAR(100),
    workstations_reserved INT,
    status VARCHAR(20)
);

INSERT INTO lab_sessions (session_name, available_workstations) VALUES 
('Networking Lab', 20),
('Database Lab', 2),
('AI Lab', 0);

-- 2. Use IF ELSIF ELSE to report workstation status
DO $$
DECLARE
    v_workstations INT;
BEGIN
    SELECT available_workstations INTO v_workstations FROM lab_sessions WHERE session_id = 1;
    
    IF v_workstations = 0 THEN
        RAISE NOTICE 'Session is full';
    ELSIF v_workstations <= 5 THEN
        RAISE NOTICE 'Session is nearly full';
    ELSE
        RAISE NOTICE 'Session has enough workstations';
    END IF;
END $$;

-- 3. Use WHILE and numeric FOR loops
DO $$
DECLARE
    v_reminders INT := 1;
    v_check INT;
BEGIN
    WHILE v_reminders <= 3 LOOP
        RAISE NOTICE 'Session preparation reminder number: %', v_reminders;
        v_reminders := v_reminders + 1;
    END LOOP;

    FOR v_check IN 1..3 LOOP
        RAISE NOTICE 'Workstation check number: %', v_check;
    END LOOP;
END $$;

-- 4. Create reserve_workstations procedure
CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id INT,
    p_lecturer VARCHAR,
    p_workstations INT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_workstations <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: workstations must be greater than zero.';
    END IF;

    SELECT available_workstations INTO v_available FROM lab_sessions WHERE session_id = p_session_id FOR UPDATE;

    IF v_available < p_workstations THEN
        RAISE EXCEPTION 'Not enough workstations available.';
    END IF;

    UPDATE lab_sessions SET available_workstations = available_workstations - p_workstations WHERE session_id = p_session_id;

    INSERT INTO reservations (session_id, lecturer_name, workstations_reserved, status)
    VALUES (p_session_id, p_lecturer, p_workstations, 'RESERVED');
END $$;

-- 5. Call procedure for valid and exceeding requests
CALL reserve_workstations(1, 'Dr. Smith', 5);
CALL reserve_workstations(2, 'Prof. Jones', 1);
-- CALL reserve_workstations(1, 'Dr. Doe', 50); -- Exceeds capacity

-- 6. Create cancel_reservation procedure with idempotency check
CREATE OR REPLACE PROCEDURE cancel_reservation(p_reservation_id INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_session_id INT;
    v_stations INT;
    v_status VARCHAR;
BEGIN
    SELECT session_id, workstations_reserved, status INTO v_session_id, v_stations, v_status 
    FROM reservations WHERE reservation_id = p_reservation_id;

    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation % already cancelled. Workstations not released again.', p_reservation_id;
        RETURN;
    END IF;

    UPDATE lab_sessions SET available_workstations = available_workstations + v_stations WHERE session_id = v_session_id;
    UPDATE reservations SET status = 'CANCELLED' WHERE reservation_id = p_reservation_id;
END $$;

-- Test cancellation twice
CALL cancel_reservation(1);
CALL cancel_reservation(1);

-- 7. Explicit cursor for sessions with few workstations remaining
DO $$
DECLARE
    r_session RECORD;
    c_few_stations CURSOR FOR SELECT session_name, available_workstations FROM lab_sessions WHERE available_workstations <= 5;
BEGIN
    OPEN c_few_stations;
    LOOP
        FETCH c_few_stations INTO r_session;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low availability session: %, Workstations left: %', r_session.session_name, r_session.available_workstations;
    END LOOP;
    CLOSE c_few_stations;
END $$;

-- 8. Exception handling for requesting zero workstations
DO $$
BEGIN
    CALL reserve_workstations(1, 'Dr. Test', 0);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Handled Exception: %', SQLERRM;
END $$;

-- 9. Final queries
SELECT * FROM lab_sessions;
SELECT * FROM reservations;