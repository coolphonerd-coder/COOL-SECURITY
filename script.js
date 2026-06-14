const menuBtn = document.getElementById('menuBtn');
const nav = document.getElementById('nav');

menuBtn.addEventListener('click', () => {
  nav.classList.toggle('open');
});

document.querySelectorAll('#nav a').forEach(link => {
  link.addEventListener('click', () => nav.classList.remove('open'));
});

document.getElementById('quoteForm').addEventListener('submit', function(e){
  e.preventDefault();

  const nombre = document.getElementById('nombre').value.trim();
  const telefono = document.getElementById('telefono').value.trim();
  const servicio = document.getElementById('servicio').value.trim();
  const ubicacion = document.getElementById('ubicacion').value.trim();
  const mensaje = document.getElementById('mensaje').value.trim();

  const texto = `Hola COOL SECURITY, quiero una cotización.%0A%0A` +
    `Nombre: ${encodeURIComponent(nombre)}%0A` +
    `Teléfono: ${encodeURIComponent(telefono)}%0A` +
    `Servicio: ${encodeURIComponent(servicio)}%0A` +
    `Ubicación: ${encodeURIComponent(ubicacion)}%0A` +
    `Comentario: ${encodeURIComponent(mensaje)}`;

  window.open(`https://wa.me/18095095225?text=${texto}`, '_blank');
});
