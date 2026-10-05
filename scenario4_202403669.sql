-- 1. Create tables and insert initial data
DROP TABLE IF EXISTS dispensing_records;
DROP TABLE IF EXISTS medicines;

CREATE TABLE medicines (
    medicine_id SERIAL PRIMARY KEY,
    medicine_name VARCHAR(100),
    stock_quantity INT
);

CREATE TABLE dispensing_records (
    record_id SERIAL PRIMARY KEY,
    medicine_id INT REFERENCES medicines(medicine_id),
    student_number VARCHAR(20),
    quantity INT,
    status VARCHAR(20)
);

INSERT INTO medicines (medicine_name, stock_quantity) VALUES 
('Paracetamol', 50),
('Amoxicillin', 4),
('Ibuprofen', 0);

-- 2. Use IF ELSIF ELSE to report medicine stock status
DO $$
DECLARE
    v_stock INT;
BEGIN
    SELECT stock_quantity INTO v_stock FROM medicines WHERE medicine_id = 3;
    
    IF v_stock = 0 THEN
        RAISE NOTICE 'Medicine is out of stock';
    ELSIF v_stock <= 10 THEN
        RAISE NOTICE 'Medicine is low on stock';
    ELSE
        RAISE NOTICE 'Medicine is sufficiently stocked';
    END IF;
END $$;

-- 3. Use WHILE and numeric FOR loops
DO $$
DECLARE
    v_days INT := 1;
    v_shelf INT;
BEGIN
    WHILE v_days <= 3 LOOP
        RAISE NOTICE 'Stock review day number: %', v_days;
        v_days := v_days + 1;
    END LOOP;

    FOR v_shelf IN 1..3 LOOP
        RAISE NOTICE 'Shelf inspection number: %', v_shelf;
    END LOOP;
END $$;

-- 4. Create dispense_medicine procedure
CREATE OR REPLACE PROCEDURE dispense_medicine(
    p_medicine_id INT,
    p_student_number VARCHAR,
    p_quantity INT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_stock INT;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: must be a positive number.';
    END IF;

    SELECT stock_quantity INTO v_stock FROM medicines WHERE medicine_id = p_medicine_id FOR UPDATE;

    IF v_stock < p_quantity THEN
        RAISE EXCEPTION 'Insufficient stock to dispense requested quantity.';
    END IF;

    UPDATE medicines SET stock_quantity = stock_quantity - p_quantity WHERE medicine_id = p_medicine_id;

    INSERT INTO dispensing_records (medicine_id, student_number, quantity, status)
    VALUES (p_medicine_id, p_student_number, p_quantity, 'DISPENSED');
END $$;

-- 5. Call procedure for valid quantities and one exceeding request
CALL dispense_medicine(1, 'S101', 5);
CALL dispense_medicine(2, 'S102', 2);
-- CALL dispense_medicine(3, 'S103', 5); -- Exceeds stock

-- 6. Create reverse_dispensing procedure with idempotency check
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_record_id INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_med_id INT;
    v_qty INT;
    v_status VARCHAR;
BEGIN
    SELECT medicine_id, quantity, status INTO v_med_id, v_qty, v_status 
    FROM dispensing_records WHERE record_id = p_record_id;

    IF v_status = 'REVERSED' THEN
        RAISE NOTICE 'Record % already reversed. Stock not restored again.', p_record_id;
        RETURN;
    END IF;

    UPDATE medicines SET stock_quantity = stock_quantity + v_qty WHERE medicine_id = v_med_id;
    UPDATE dispensing_records SET status = 'REVERSED' WHERE record_id = p_record_id;
END $$;

-- Test reversal twice
CALL reverse_dispensing(1);
CALL reverse_dispensing(1);

-- 7. Explicit cursor for medicines below a low-stock threshold (<= 10)
DO $$
DECLARE
    r_med RECORD;
    c_low_threshold CURSOR FOR SELECT medicine_name, stock_quantity FROM medicines WHERE stock_quantity <= 10;
BEGIN
    OPEN c_low_threshold;
    LOOP
        FETCH c_low_threshold INTO r_med;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low stock medicine: %, Quantity: %', r_med.medicine_name, r_med.stock_quantity;
    END LOOP;
    CLOSE c_low_threshold;
END $$;

-- 8. Exception handling for negative dispensing quantity
DO $$
BEGIN
    CALL dispense_medicine(1, 'S999', -3);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Handled Exception: %', SQLERRM;
END $$;

-- 9. Final queries
SELECT * FROM medicines;
SELECT * FROM dispensing_records;