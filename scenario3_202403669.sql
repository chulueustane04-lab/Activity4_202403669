-- 1. Create tables and insert initial data
DROP TABLE IF EXISTS allocations;
DROP TABLE IF EXISTS hostel_rooms;

CREATE TABLE hostel_rooms (
    room_id SERIAL PRIMARY KEY,
    room_number VARCHAR(20),
    available_bed_spaces INT
);

CREATE TABLE allocations (
    allocation_id SERIAL PRIMARY KEY,
    room_id INT REFERENCES hostel_rooms(room_id),
    student_number VARCHAR(20),
    status VARCHAR(20)
);

INSERT INTO hostel_rooms (room_number, available_bed_spaces) VALUES 
('Block A 101', 3),
('Block A 102', 1),
('Block B 201', 0);

-- 2. Use IF ELSIF ELSE to report room space status
DO $$
DECLARE
    v_spaces INT;
BEGIN
    SELECT available_bed_spaces INTO v_spaces FROM hostel_rooms WHERE room_id = 1;
    
    IF v_spaces = 0 THEN
        RAISE NOTICE 'Room is full';
    ELSIF v_spaces = 1 THEN
        RAISE NOTICE 'Room has one space left';
    ELSE
        RAISE NOTICE 'Room has several spaces';
    END IF;
END $$;

-- 3. Use WHILE and numeric FOR loops
DO $$
DECLARE
    v_days INT := 1;
    v_room_check INT;
BEGIN
    WHILE v_days <= 3 LOOP
        RAISE NOTICE 'Hostel inspection day number: %', v_days;
        v_days := v_days + 1;
    END LOOP;

    FOR v_room_check IN 1..3 LOOP
        RAISE NOTICE 'Room check number: %', v_room_check;
    END LOOP;
END $$;

-- 4. Create allocate_room procedure
CREATE OR REPLACE PROCEDURE allocate_room(
    p_room_id INT,
    p_student_number VARCHAR
)
LANGUAGE plpgsql AS $$
DECLARE
    v_spaces INT;
BEGIN
    IF p_student_number IS NULL OR TRIM(p_student_number) = '' THEN
        RAISE EXCEPTION 'Invalid input: student number cannot be blank.';
    END IF;

    SELECT available_bed_spaces INTO v_spaces FROM hostel_rooms WHERE room_id = p_room_id FOR UPDATE;

    IF v_spaces <= 0 THEN
        RAISE EXCEPTION 'Room is full. No available bed spaces.';
    END IF;

    UPDATE hostel_rooms SET available_bed_spaces = available_bed_spaces - 1 WHERE room_id = p_room_id;

    INSERT INTO allocations (room_id, student_number, status)
    VALUES (p_room_id, p_student_number, 'ALLOCATED');
END $$;

-- 5. Call procedure for valid and full room requests
CALL allocate_room(1, 'CS/2024/001');
CALL allocate_room(2, 'CS/2024/002');
-- CALL allocate_room(3, 'CS/2024/003'); -- Full room request

-- 6. Create check_out procedure with idempotency check
CREATE OR REPLACE PROCEDURE check_out(p_allocation_id INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_room_id INT;
    v_status VARCHAR;
BEGIN
    SELECT room_id, status INTO v_room_id, v_status 
    FROM allocations WHERE allocation_id = p_allocation_id;

    IF v_status = 'CHECKED_OUT' THEN
        RAISE NOTICE 'Allocation % already checked out. Bed space not freed again.', p_allocation_id;
        RETURN;
    END IF;

    UPDATE hostel_rooms SET available_bed_spaces = available_bed_spaces + 1 WHERE room_id = v_room_id;
    UPDATE allocations SET status = 'CHECKED_OUT' WHERE allocation_id = p_allocation_id;
END $$;

-- Test check_out twice
CALL check_out(1);
CALL check_out(1);

-- 7. Explicit cursor for full or nearly full rooms
DO $$
DECLARE
    r_room RECORD;
    c_full_rooms CURSOR FOR SELECT room_number, available_bed_spaces FROM hostel_rooms WHERE available_bed_spaces <= 1;
BEGIN
    OPEN c_full_rooms;
    LOOP
        FETCH c_full_rooms INTO r_room;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Room: %, Spaces remaining: %', r_room.room_number, r_room.available_bed_spaces;
    END LOOP;
    CLOSE c_full_rooms;
END $$;

-- 8. Exception handling for blank student number
DO $$
BEGIN
    CALL allocate_room(1, '');
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Handled Exception: %', SQLERRM;
END $$;

-- 9. Final queries
SELECT * FROM hostel_rooms;
SELECT * FROM allocations;