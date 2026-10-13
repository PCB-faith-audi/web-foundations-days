/**
 * day5/users.js
 * Fetches users from JSONPlaceholder, renders them as cards,
 * and provides live client-side filtering by name.
 */

const API_URL = 'https://jsonplaceholder.typicode.com/users';

// DOM references
const loadBtn    = document.getElementById('load-users');
const filterInput = document.getElementById('filter-input');
const statusEl   = document.getElementById('status');
const usersList  = document.getElementById('users-list');

// Module-level cache of all fetched users
let allUsers = [];

/* ── Status helper ─────────────────────────────────────── */
function setStatus(message, type = '') {
  statusEl.textContent = message;
  statusEl.className   = type; // '', 'loading', 'success', 'error'
}

/* ── Render ────────────────────────────────────────────── */
/**
 * Renders an array of user objects into #users-list.
 * Uses createElement / textContent only (no innerHTML).
 * @param {Array} list - Array of user objects to display.
 */
function renderUsers(list) {
  // Clear existing cards
  usersList.replaceChildren();

  if (list.length === 0) {
    const msg = document.createElement('li');
    msg.className   = 'empty-msg';
    msg.textContent = 'No users match your filter.';
    usersList.appendChild(msg);
    return;
  }

  list.forEach((user) => {
    const li = document.createElement('li');

    // Name
    const name = document.createElement('p');
    name.className   = 'user-name';
    name.textContent = user.name;

    // Email
    const email = document.createElement('p');
    email.className   = 'user-email';
    email.textContent = user.email;

    // City & Company (grouped)
    const meta = document.createElement('div');
    meta.className = 'user-meta';

    const city = document.createElement('span');
    city.textContent = user.address.city;

    const company = document.createElement('span');
    company.textContent = user.company.name;

    meta.appendChild(city);
    meta.appendChild(company);

    li.appendChild(name);
    li.appendChild(email);
    li.appendChild(meta);
    usersList.appendChild(li);
  });
}

/* ── Fetch ─────────────────────────────────────────────── */
/**
 * Fetches users from the API and populates allUsers.
 * Uses async/await with try/catch/finally for robust error handling.
 */
async function loadUsers() {
  // Disable button while loading
  loadBtn.disabled = true;
  setStatus('Loading users…', 'loading');

  try {
    const response = await fetch(API_URL);

    if (!response.ok) {
      throw new Error(`Server error: ${response.status} ${response.statusText}`);
    }

    const data = await response.json();

    allUsers = data;
    renderUsers(allUsers);
    setStatus(`✓ ${allUsers.length} users loaded successfully.`, 'success');

    // Enable filtering now that data is available
    filterInput.disabled = false;
    filterInput.focus();
  } catch (error) {
    setStatus(`✗ Failed to load users — ${error.message}`, 'error');
    // Keep the list empty / clear it on error
    usersList.replaceChildren();
  } finally {
    // Always re-enable the button so the user can retry
    loadBtn.disabled = false;
  }
}

/* ── Filter ────────────────────────────────────────────── */
/**
 * Listens for typing in the filter box and renders
 * only users whose name contains the query (case-insensitive).
 * No new network request is made.
 */
filterInput.addEventListener('input', () => {
  const query = filterInput.value.trim().toLowerCase();

  if (query === '') {
    // Show all users when filter is cleared
    renderUsers(allUsers);
    setStatus(`✓ ${allUsers.length} users loaded successfully.`, 'success');
    return;
  }

  const filtered = allUsers.filter((user) =>
    user.name.toLowerCase().includes(query)
  );

  renderUsers(filtered);

  if (filtered.length === 0) {
    setStatus('No users match your filter.', '');
  } else {
    setStatus(`Showing ${filtered.length} of ${allUsers.length} users.`, 'success');
  }
});

/* ── Boot ──────────────────────────────────────────────── */
// Keep the filter disabled until data has been loaded
filterInput.disabled = true;

// Wire up the button
loadBtn.addEventListener('click', loadUsers);
