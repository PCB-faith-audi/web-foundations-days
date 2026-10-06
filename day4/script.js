// Select the elements
const noteText = document.getElementById("note-text");
const charCount = document.getElementById("char-count");
const wordCount = document.getElementById("word-count");
const clearBtn = document.getElementById("clear-btn");
const themeToggle = document.getElementById("theme-toggle");


// Update character and word counts
function updateCounts() {
  const text = noteText.value;
  const characters = text.length;

  const trimmedText = text.trim();
  const words = trimmedText === ""
    ? 0
    : trimmedText.split(/\s+/).length;

  charCount.textContent = `${characters} / 200 characters`;
  wordCount.textContent = `${words} words`;

  // Remove old warning classes
  charCount.classList.remove("warning", "over");

  // Add the correct class
  if (characters > 200) {
    charCount.classList.add("over");
  } else if (characters > 180) {
    charCount.classList.add("warning");
  }
}


// Save the note as a draft
function saveDraft() {
  localStorage.setItem("noteDraft", noteText.value);
}


// Update counts and save draft whenever the user types
noteText.addEventListener("input", () => {
  updateCounts();
  saveDraft();
});


// Clear the note
function clearNote() {
  noteText.value = "";
  updateCounts();
  localStorage.removeItem("noteDraft");
}


// Clear button
clearBtn.addEventListener("click", clearNote);


// Pressing Escape inside the textarea also clears the note
noteText.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    clearNote();
  }
});


// Change the theme button label
function updateThemeButton() {
  if (document.body.classList.contains("dark")) {
    themeToggle.textContent = "Light mode";
  } else {
    themeToggle.textContent = "Dark mode";
  }
}


// Theme toggle
themeToggle.addEventListener("click", () => {
  document.body.classList.toggle("dark");

  const isDark = document.body.classList.contains("dark");

  localStorage.setItem("theme", isDark ? "dark" : "light");

  updateThemeButton();
});


// Restore saved data when the page loads
const savedDraft = localStorage.getItem("noteDraft");

if (savedDraft !== null) {
  noteText.value = savedDraft;
}


// Restore saved theme
const savedTheme = localStorage.getItem("theme");

if (savedTheme === "dark") {
  document.body.classList.add("dark");
}


// Update the button label and counters
updateThemeButton();
updateCounts();