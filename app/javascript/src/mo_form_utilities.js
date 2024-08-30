export const mo_form_utilities = {
  escapeHTML(str) {
    const HTML_ENTITY_MAP = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': '&quot;',
      "'": '&#39;',
      "/": '&#x2F;'
    };

    return str.replace(/[&<>"'\/]/g, function (s) {
      return HTML_ENTITY_MAP[s];
    });
  },

  getScrollBarWidth() {
    let inner, outer, w1, w2;
    const body = document.body || document.getElementsByTagName("body")[0];

    if (this.scrollbar_width != null)
      return this.scrollbar_width;

    inner = document.createElement('p');
    inner.style.width = "100%";
    inner.style.height = "200px";

    outer = document.createElement('div');
    outer.style.position = "absolute";
    outer.style.top = "0px";
    outer.style.left = "0px";
    outer.style.visibility = "hidden";
    outer.style.width = "200px";
    outer.style.height = "150px";
    outer.style.overflow = "hidden";
    outer.appendChild(inner);

    body.appendChild(outer);
    w1 = inner.offsetWidth;
    outer.style.overflow = 'scroll';
    w2 = inner.offsetWidth;
    if (w1 == w2) w2 = outer.clientWidth;
    body.removeChild(outer);

    this.scrollbar_width = w1 - w2;
    // return scroll_bar_width;
  },

  setCursorPosition(el, pos) {
    if (el.setSelectionRange) {
      el.setSelectionRange(pos, pos);
    } else if (el.createTextRange) {
      const range = el.createTextRange();
      range.collapse(true);
      range.moveEnd('character', pos);
      range.moveStart('character', pos);
      range.select();
    }
  },

  // https://stackoverflow.com/a/74602959/3357635
  getActiveInputSelection() {
    const el = document.activeElement,
      selection = { start: null, end: null, text: '' };

    if (typeof el != "undefined") {
      selection.start = el.selectionStart;
      selection.end = el.selectionEnd;
      selection.text = el.value.substring(selection.start, selection.end);
    }
    return selection;
  }
}

export const EVENT_KEYS = {
  tab: 9,
  return: 13,
  esc: 27,
  backspace: 8,
  delete: 46,
  up: 38,
  down: 40,
  left: 37,
  right: 39,
  pageup: 33,
  pagedown: 34,
  home: 36,
  end: 35
}
