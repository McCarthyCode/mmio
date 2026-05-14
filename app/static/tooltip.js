const tooltipElements = document.querySelectorAll('[data-bs-toggle="tooltip"]');
const tooltips = [...tooltipElements].map(
  element => [element, new bootstrap.Tooltip(element)]
);
