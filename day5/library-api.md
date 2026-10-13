# Library Books API Design

A RESTful API for managing a library's book catalogue. All responses are `application/json`.
Base URL: `https://api.library.example.com/v1`

---

## Endpoints

### 1. List all books

| Field | Value |
|-------|-------|
| **Method** | `GET` |
| **Path** | `/books` |
| **Description** | Returns a paginated list of every book in the catalogue. |
| **Query params** | `page` (default 1), `limit` (default 20) |
| **Success status** | `200 OK` |

**Example response (truncated):**
```json
[
  {
    "id": 1,
    "title": "Clean Code",
    "author": "Robert C. Martin",
    "isbn": "9780132350884",
    "available": true
  }
]
```

---

### 2. Get a single book

| Field | Value |
|-------|-------|
| **Method** | `GET` |
| **Path** | `/books/:id` |
| **Description** | Returns full details for the book with the given ID. |
| **Success status** | `200 OK` |

**Example response:**
```json
{
  "id": 1,
  "title": "Clean Code",
  "author": "Robert C. Martin",
  "isbn": "9780132350884",
  "genre": "Software Engineering",
  "year": 2008,
  "available": true
}
```

---

### 3. Create a book

| Field | Value |
|-------|-------|
| **Method** | `POST` |
| **Path** | `/books` |
| **Description** | Adds a new book record to the catalogue. |
| **Success status** | `201 Created` |

**Example request body:**
```json
{
  "title": "The Pragmatic Programmer",
  "author": "Andrew Hunt",
  "isbn": "9780135957059",
  "genre": "Software Engineering",
  "year": 2019
}
```

**Example response:**
```json
{
  "id": 42,
  "title": "The Pragmatic Programmer",
  "author": "Andrew Hunt",
  "isbn": "9780135957059",
  "genre": "Software Engineering",
  "year": 2019,
  "available": true
}
```

---

### 4. Update a book (full replacement)

| Field | Value |
|-------|-------|
| **Method** | `PUT` |
| **Path** | `/books/:id` |
| **Description** | Fully replaces the book record identified by `:id`. |
| **Success status** | `200 OK` |

**Example request body:**
```json
{
  "title": "The Pragmatic Programmer",
  "author": "Andrew Hunt",
  "isbn": "9780135957059",
  "genre": "Software Engineering",
  "year": 2019,
  "available": false
}
```

**Example response:**
```json
{
  "id": 42,
  "title": "The Pragmatic Programmer",
  "author": "Andrew Hunt",
  "isbn": "9780135957059",
  "genre": "Software Engineering",
  "year": 2019,
  "available": false
}
```

---

### 5. Delete a book

| Field | Value |
|-------|-------|
| **Method** | `DELETE` |
| **Path** | `/books/:id` |
| **Description** | Permanently removes the book with the given ID from the catalogue. |
| **Success status** | `204 No Content` |

> No request body or response body required.

---

### 6. List books by author

| Field | Value |
|-------|-------|
| **Method** | `GET` |
| **Path** | `/books?author=:name` |
| **Description** | Returns all books whose author field contains the given query string (case-insensitive). No new resource is introduced — this is a filtered view of the collection. |
| **Query param** | `author` — partial or full author name to search for |
| **Success status** | `200 OK` |

**Example request:**
```
GET /books?author=Martin
```

**Example response:**
```json
[
  {
    "id": 1,
    "title": "Clean Code",
    "author": "Robert C. Martin",
    "isbn": "9780132350884",
    "available": true
  },
  {
    "id": 7,
    "title": "The Clean Coder",
    "author": "Robert C. Martin",
    "isbn": "9780137081073",
    "available": false
  }
]
```

---

## Error Codes

### `400 Bad Request`

The server cannot process the request because the client sent invalid or incomplete data.

- **When it happens:**
  - A required field (`title`, `author`, or `isbn`) is missing from a `POST` or `PUT` body.
  - The `isbn` value fails format validation.
  - A query parameter has an unexpected type (e.g. `page=abc`).

**Example response:**
```json
{
  "error": "Bad Request",
  "message": "The field 'title' is required and cannot be empty.",
  "status": 400
}
```

---

### `404 Not Found`

The requested resource does not exist on the server.

- **When it happens:**
  - `GET /books/9999` — no book with ID 9999 exists.
  - `PUT /books/9999` — attempting to update a non-existent record.
  - `DELETE /books/9999` — attempting to delete a non-existent record.

**Example response:**
```json
{
  "error": "Not Found",
  "message": "No book with id 9999 was found.",
  "status": 404
}
```
