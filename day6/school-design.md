# School Database — Design Notes

## Table Descriptions

### `students`

Stores one record per person enrolled at the school.

| Column | Type | Constraint | Purpose |
|---|---|---|---|
| `student_id` | INTEGER | PRIMARY KEY | Auto-incrementing surrogate key |
| `first_name` | TEXT | NOT NULL | A student must have a first name |
| `last_name` | TEXT | NOT NULL | A student must have a last name |
| `email` | TEXT | NOT NULL UNIQUE | Used as login / contact identifier; no two students may share an address |
| `date_of_birth` | DATE | — | Optional demographic data |

### `courses`

Stores one record per course offered by the school, independent of who is enrolled.

| Column | Type | Constraint | Purpose |
|---|---|---|---|
| `course_id` | INTEGER | PRIMARY KEY | Auto-incrementing surrogate key |
| `course_code` | TEXT | NOT NULL UNIQUE | Short human-readable code (e.g. `CS101`); unique so it can serve as a natural lookup key |
| `title` | TEXT | NOT NULL | Full course name |
| `credits` | INTEGER | NOT NULL DEFAULT 3 | Credit hours; defaults to 3 so it can be omitted on insert |
| `instructor` | TEXT | — | Optional — may be unassigned at creation time |

### `enrolments`

The join table that links students to courses. Each row records **the fact that a specific student is enrolled in a specific course**, and holds the mutable `grade` that is updated once the course is assessed.

| Column | Type | Constraint | Purpose |
|---|---|---|---|
| `enrolment_id` | INTEGER | PRIMARY KEY | Surrogate key for the enrolment row itself |
| `student_id` | INTEGER | NOT NULL, FK → `students` | Identifies the student |
| `course_id` | INTEGER | NOT NULL, FK → `courses` | Identifies the course |
| `enrolled_on` | DATE | NOT NULL DEFAULT today | Audit trail — when the enrolment was created |
| `grade` | TEXT | — | NULLable — starts empty, updated when the course is graded |
| `UNIQUE(student_id, course_id)` | — | — | Database-level guard preventing a student from enrolling on the same course twice |

---

## Relationships

### One-to-many: `students` → `enrolments`

One student can have many enrolment rows, but each enrolment row belongs to exactly **one** student.  
→ `enrolments.student_id` is the "many" side (the foreign key).

### One-to-many: `courses` → `enrolments`

One course can appear in many enrolment rows, but each enrolment row belongs to exactly **one** course.  
→ `enrolments.course_id` is the "many" side (the foreign key).

### Many-to-many: `students` ↔ `courses`

A student can take many courses, and a course can be taken by many students. This **cannot** be stored directly in either table without repeating data or using comma-separated lists — both of which break normalisation. The solution is a **join table** (`enrolments`) whose rows each represent one unique `(student, course)` pair, turning the many-to-many into two one-to-many relationships the database can enforce with foreign keys.

The join table also serves as the natural home for data that only exists *because of the relationship* — in this case, the `grade` and `enrolled_on` date, which belong neither to the student alone nor to the course alone.

---

## Recommended Index

```sql
CREATE INDEX idx_enrolments_student_id ON enrolments (student_id);
```

**Reason:** The most common query in a student-facing application will be "fetch all courses for a given student" (e.g., a dashboard page load). Without an index, SQLite performs a full sequential scan of the entire `enrolments` table for every request. With this index, lookups by `student_id` become O(log n), keeping response times fast even as the enrolments table grows to hundreds of thousands of rows. A companion index on `course_id` (`idx_enrolments_course_id`) would similarly speed up course-roster lookups.

---

## SQL vs NoSQL

For a school enrolment system I would choose **SQL** — specifically SQLite for local development and PostgreSQL in production. The data is highly structured and relational by nature: a student, a course, and an enrolment are distinct, well-defined entities connected by clear foreign-key relationships, and the integrity rules — unique emails, no duplicate enrolments, grades only for valid `(student, course)` pairs — are exactly what relational constraints and ACID transactions are designed to enforce. Queries like "count students per course" or "find students with no enrolments" are expressed cleanly and efficiently in standard SQL using `GROUP BY` and `LEFT JOIN`, whereas the same logic in a document store such as MongoDB would require application-side joins or heavily denormalised, duplicated data that can drift out of sync. A NoSQL store would only become attractive if the schema were genuinely unpredictable (e.g., every course storing a completely different set of metadata fields) or if the system needed to scale writes across many shards at internet scale — neither of which applies to a typical school database.
