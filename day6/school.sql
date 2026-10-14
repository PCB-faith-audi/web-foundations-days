-- =============================================================
-- Day 6 Assignment: School Database
-- Compatible with SQLite (tested on sqliteonline.com)
-- =============================================================

-- =============================================================
-- 1. CREATE TABLES
-- =============================================================

CREATE TABLE students (
    student_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    first_name    TEXT    NOT NULL,
    last_name     TEXT    NOT NULL,
    email         TEXT    NOT NULL UNIQUE,
    date_of_birth DATE
);

CREATE TABLE courses (
    course_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    course_code TEXT    NOT NULL UNIQUE,
    title       TEXT    NOT NULL,
    credits     INTEGER NOT NULL DEFAULT 3,
    instructor  TEXT
);

CREATE TABLE enrolments (
    enrolment_id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id   INTEGER NOT NULL,
    course_id    INTEGER NOT NULL,
    enrolled_on  DATE    NOT NULL DEFAULT (DATE('now')),
    grade        TEXT,
    FOREIGN KEY (student_id) REFERENCES students (student_id),
    FOREIGN KEY (course_id)  REFERENCES courses  (course_id),
    UNIQUE (student_id, course_id)   -- prevents the same student enrolling on the same course twice
);

-- =============================================================
-- 2. INSERT SAMPLE DATA
-- =============================================================

-- At least 3 students (we add 5; David is intentionally left un-enrolled
-- so the LEFT JOIN query in Query 4 returns a visible result)
INSERT INTO students (first_name, last_name, email, date_of_birth) VALUES
    ('Alice',  'Nkosi',  'alice.nkosi@school.ac',  '2005-03-14'),
    ('Ben',    'Okafor', 'ben.okafor@school.ac',    '2004-11-22'),
    ('Carmen', 'Reyes',  'carmen.reyes@school.ac',  '2005-07-09'),
    ('David',  'Chen',   'david.chen@school.ac',    '2006-01-30'),
    ('Eva',    'Muller', 'eva.muller@school.ac',    '2004-05-18');

-- At least 3 courses (we add 5)
INSERT INTO courses (course_code, title, credits, instructor) VALUES
    ('CS101',   'Introduction to Programming', 4, 'Prof. Williams'),
    ('MATH201', 'Calculus I',                  4, 'Prof. Johnson'),
    ('ENG110',  'Academic Writing',            3, 'Prof. Davis'),
    ('CS202',   'Data Structures',             4, 'Prof. Williams'),
    ('HIS150',  'World History',               3, 'Prof. Patel');

-- At least 5 enrolments (we add 8)
-- Alice  -> CS101, MATH201, ENG110
-- Ben    -> CS101, CS202
-- Carmen -> MATH201, HIS150
-- David  -> (none — demonstrates the LEFT JOIN query)
-- Eva    -> ENG110
INSERT INTO enrolments (student_id, course_id, enrolled_on, grade) VALUES
    (1, 1, '2026-09-01', 'A'),   -- Alice  -> CS101
    (1, 2, '2026-09-01', 'B+'),  -- Alice  -> MATH201
    (1, 3, '2026-09-01', NULL),  -- Alice  -> ENG110  (grade pending)
    (2, 1, '2026-09-01', 'B'),   -- Ben    -> CS101
    (2, 4, '2026-09-02', 'A-'),  -- Ben    -> CS202
    (3, 2, '2026-09-01', 'A'),   -- Carmen -> MATH201
    (3, 5, '2026-09-03', 'C+'),  -- Carmen -> HIS150
    (5, 3, '2026-09-01', 'B+');  -- Eva    -> ENG110

-- =============================================================
-- 3. FIVE REQUIRED QUERIES
-- =============================================================

-- -----------------------------------------------------------------
-- Query 1: All courses for one student (searched by name)
-- -----------------------------------------------------------------
SELECT
    c.course_code,
    c.title,
    c.credits,
    c.instructor,
    e.grade
FROM   enrolments e
JOIN   students   s ON s.student_id = e.student_id
JOIN   courses    c ON c.course_id  = e.course_id
WHERE  s.first_name = 'Alice'
AND    s.last_name  = 'Nkosi'
ORDER  BY c.course_code;

-- -----------------------------------------------------------------
-- Query 2: All students on one course (searched by course code)
-- -----------------------------------------------------------------
SELECT
    s.student_id,
    s.first_name,
    s.last_name,
    s.email,
    e.grade
FROM   enrolments e
JOIN   courses    c ON c.course_id  = e.course_id
JOIN   students   s ON s.student_id = e.student_id
WHERE  c.course_code = 'CS101'
ORDER  BY s.last_name, s.first_name;

-- -----------------------------------------------------------------
-- Query 3: Number of students per course (includes courses with zero enrolments)
-- -----------------------------------------------------------------
SELECT
    c.course_code,
    c.title,
    COUNT(e.student_id) AS student_count
FROM   courses    c
LEFT   JOIN enrolments e ON e.course_id = c.course_id
GROUP  BY c.course_id, c.course_code, c.title
ORDER  BY student_count DESC, c.course_code;

-- -----------------------------------------------------------------
-- Query 4: Students who have no enrolments
-- -----------------------------------------------------------------
SELECT
    s.student_id,
    s.first_name,
    s.last_name,
    s.email
FROM   students   s
LEFT   JOIN enrolments e ON e.student_id = s.student_id
WHERE  e.enrolment_id IS NULL
ORDER  BY s.last_name, s.first_name;

-- -----------------------------------------------------------------
-- Query 5: Update one enrolment's grade
-- Alice's ENG110 grade was NULL; it is now set to 'A-'
-- -----------------------------------------------------------------
UPDATE enrolments
SET    grade = 'A-'
WHERE  student_id = (SELECT student_id FROM students
                     WHERE  first_name = 'Alice' AND last_name = 'Nkosi')
AND    course_id  = (SELECT course_id  FROM courses
                     WHERE  course_code = 'ENG110');

-- Verify the update
SELECT
    s.first_name || ' ' || s.last_name AS student,
    c.course_code,
    e.grade
FROM   enrolments e
JOIN   students   s ON s.student_id = e.student_id
JOIN   courses    c ON c.course_id  = e.course_id
WHERE  s.first_name = 'Alice'
ORDER  BY c.course_code;
