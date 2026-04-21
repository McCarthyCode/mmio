// Check system preference
const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

// Set initial theme
if (prefersDark) {
  document.documentElement.setAttribute('data-bs-theme', 'dark');
} else {
  document.documentElement.setAttribute('data-bs-theme', 'light');
}

// Listen for system changes
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
  if (e.matches) {
    document.documentElement.setAttribute('data-bs-theme', 'dark');
  } else {
    document.documentElement.setAttribute('data-bs-theme', 'light');
  }
});
