// Los filtros trabajan sobre el listado que Flask ya ha cargado desde PostgreSQL.
const filters = document.querySelector('.filters');
const filterButtons = document.querySelectorAll('[data-filter]');
const groups = document.querySelectorAll('[data-group]');
const filterStatus = document.getElementById('filter-status');

if (filters) {
    filters.hidden = false;
    filterButtons.forEach((button) => {
        button.addEventListener('click', () => {
            const selected = button.dataset.filter;
            filterButtons.forEach((item) => {
                item.setAttribute('aria-pressed', String(item === button));
            });
            groups.forEach((group) => {
                group.hidden = selected !== 'all' && group.dataset.group !== selected;
            });
            filterStatus.textContent = `Mostrando: ${button.textContent.trim()}`;
        });
    });
}

// <dialog> mantiene el foco dentro de la ficha y permite cerrarla con Escape.
const dialog = document.getElementById('player-dialog');
const detailPhoto = document.getElementById('detail-photo');
const detailPlaceholder = document.getElementById('detail-placeholder');
let activeButton = null;

if (dialog && typeof dialog.showModal === 'function') {
    document.querySelectorAll('.player-card').forEach((card) => {
        const button = card.querySelector('.player-detail-button');
        button.hidden = false;
        card.classList.add('is-interactive');
        card.addEventListener('click', () => {
            activeButton = button;
            document.getElementById('detail-name').textContent = card.dataset.name;
            document.getElementById('detail-position').textContent = card.dataset.position;
            const photo = card.querySelector('.player-photo');
            detailPhoto.hidden = !photo;
            detailPlaceholder.hidden = Boolean(photo);
            if (photo) {
                detailPhoto.src = photo.src;
                detailPhoto.alt = photo.alt;
            } else {
                detailPhoto.removeAttribute('src');
                detailPhoto.alt = '';
            }
            dialog.showModal();
            document.body.classList.add('dialog-open');
        });
    });

    dialog.querySelectorAll('[data-close-dialog]').forEach((button) => {
        button.addEventListener('click', () => dialog.close());
    });
    // El fondo queda fuera del rectángulo del panel; pulsarlo cierra la ficha.
    dialog.addEventListener('click', (event) => {
        const bounds = dialog.getBoundingClientRect();
        if (event.target === dialog && (
            event.clientX < bounds.left || event.clientX > bounds.right ||
            event.clientY < bounds.top || event.clientY > bounds.bottom
        )) {
            dialog.close();
        }
    });
    dialog.addEventListener('close', () => {
        document.body.classList.remove('dialog-open');
        activeButton?.focus();
    });
}
