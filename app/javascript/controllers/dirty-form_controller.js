import { Controller } from "@hotwired/stimulus";

// Warns the user before navigating away from a form with unsaved
// changes. Attach with data-controller="dirty-form" on a <form>;
// add data-action="submit->dirty-form#allowSubmit" so the warning
// is suppressed on intentional submission. Issue #4148.
//
// Handles two navigation paths:
//
//   * Browser-level (closing the tab, typing a new URL, hard
//     reload) — uses the native `beforeunload` event. The
//     browser's standard "Changes you made may not be saved"
//     dialog appears; modern browsers ignore custom message text.
//   * Turbo-driven (clicking a Turbo-handled link, including
//     other tabs and sub-tabs) — uses `turbo:before-visit`. Since
//     `beforeunload` does not fire on Turbo navigations, we
//     present `window.confirm` and call `preventDefault()` if the
//     user cancels.
export default class extends Controller {
  connect() {
    this.dirty = false;
    this.snapshot = this.serialize();
    this.boundInputHandler = this.checkDirty.bind(this);
    this.boundBeforeUnload = this.beforeUnload.bind(this);
    this.boundBeforeVisit = this.beforeVisit.bind(this);

    this.element.addEventListener("input", this.boundInputHandler);
    this.element.addEventListener("change", this.boundInputHandler);
    window.addEventListener("beforeunload", this.boundBeforeUnload);
    document.addEventListener("turbo:before-visit", this.boundBeforeVisit);
  }

  disconnect() {
    this.element.removeEventListener("input", this.boundInputHandler);
    this.element.removeEventListener("change", this.boundInputHandler);
    window.removeEventListener("beforeunload", this.boundBeforeUnload);
    document.removeEventListener("turbo:before-visit", this.boundBeforeVisit);
  }

  // Wired via data-action submit->dirty-form#allowSubmit so an
  // intentional Save bypasses the warning.
  allowSubmit() {
    this.dirty = false;
  }

  checkDirty() {
    this.dirty = this.serialize() !== this.snapshot;
  }

  beforeUnload(event) {
    if (!this.dirty) return;
    // Setting returnValue is what triggers the native dialog;
    // modern browsers ignore the actual string and use their own.
    event.preventDefault();
    event.returnValue = "";
    return "";
  }

  beforeVisit(event) {
    if (!this.dirty) return;
    const message = "Changes you made may not be saved. Leave anyway?";
    if (!window.confirm(message)) {
      event.preventDefault();
    }
  }

  // Serialize the form's input values into a stable string so we
  // can detect any change. FormData is keyed by input name and
  // preserves order, which is enough for a snapshot.
  serialize() {
    const data = new FormData(this.element);
    const parts = [];
    for (const [key, value] of data.entries()) {
      // Skip File objects (their identity changes on every read).
      if (value instanceof File) continue;
      parts.push(`${key}=${value}`);
    }
    return parts.join("&");
  }
}
