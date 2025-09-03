// Simple helpers to show/hide Bootstrap 5 modals from Blazor
window.bootstrapInterop = {
  showModal: function (selector) {
    const el = document.querySelector(selector);
    if (!el) return;
    const modal = bootstrap.Modal.getOrCreateInstance(el);
    modal.show();
  },
  hideModal: function (selector) {
    const el = document.querySelector(selector);
    if (!el) return;
    const modal = bootstrap.Modal.getInstance(el);
    if (modal) modal.hide();
  }
};
