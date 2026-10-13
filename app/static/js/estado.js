// Solo consultamos Flask. El navegador nunca conecta directamente con la base.
const statusPanel = document.querySelector('[data-health-url]');

if (statusPanel) {
    const message = document.getElementById('status-message');
    const updated = document.getElementById('status-updated');

    function setService(service, state, label) {
        const item = statusPanel.querySelector(`[data-service="${service}"]`);
        item.dataset.state = state;
        const value = item.querySelector('strong');
        if (value.textContent !== label) value.textContent = label;
    }

    function setMessage(text) {
        if (message.textContent !== text) message.textContent = text;
    }

    async function checkServices() {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 8000);
        try {
            const response = await fetch(statusPanel.dataset.healthUrl, {
                cache: 'no-store',
                signal: controller.signal,
            });
            // HTTP 503 también contiene JSON: Flask responde, pero la base falla.
            if (response.status !== 200 && response.status !== 503) {
                throw new Error('Respuesta de estado no disponible');
            }
            const data = await response.json();
            if (data.services?.web !== 'connected' ||
                !['connected', 'disconnected'].includes(data.services.db) ||
                !['not_applicable', 'not_integrated'].includes(data.services.cache)) {
                throw new Error('Respuesta de estado no reconocida');
            }
            const dbConnected = data.services.db === 'connected';
            setService('web', 'connected', 'Disponible');
            setService('db', dbConnected ? 'connected' : 'disconnected',
                dbConnected ? 'Conectado' : 'Sin conexión');
            setService('cache', 'neutral', data.services.cache === 'not_integrated'
                ? 'Pendiente de integrar' : 'No aplica en desarrollo');
            setMessage(dbConnected
                ? 'Servicios disponibles. Recarga la página para actualizar el listado.'
                : 'La web responde, pero no puede consultar la base. Los jugadores ya cargados pueden seguir visibles.');
            updated.textContent = `Última comprobación: ${new Date().toLocaleTimeString('es-ES')}`;
        } catch {
            setService('web', 'unknown', 'Sin respuesta');
            setService('db', 'unknown', 'Desconocido');
            setMessage('No se puede comprobar la conexión con el servidor. Se volverá a intentar automáticamente.');
            updated.textContent = `Último intento: ${new Date().toLocaleTimeString('es-ES')}`;
        } finally {
            clearTimeout(timeout);
            // Esperamos a terminar: nunca se solapan dos comprobaciones.
            setTimeout(checkServices, 5000);
        }
    }

    setService('web', 'unknown', 'Comprobando…');
    setService('db', 'unknown', 'Comprobando…');
    setMessage('Comprobando las conexiones…');
    checkServices();
}
