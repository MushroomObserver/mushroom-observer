import { Controller } from "@hotwired/stimulus"
import { escapeHTML, getScrollBarWidth, EVENT_KEYS } from "src/mo_utilities"
import { NL_GENERA, NL_SPECIES, NL_NAMES } from "src/name_list_data"

// Connects to data-controller="name-list"
export default class extends Controller {
  static targets = ["genera", "species", "names"]

  initialize() {
    // Which column key strokes will go to.
    this.FOCUS_COLUMN = null
    // Kludge to tell it to ignore click event on outer div after processing
    // click event within one of the three columns.
    this.IGNORE_UNFOCUS = false
    // Keycode of key that's currently pressed if any (and if focused).
    this.KEY = null
    // Callback used to simulate key repeats.
    this.REPEAT_CALLBACK = null
    // Timing of key repeat.
    this.FIRST_KEY_DELAY = 250
    this.NEXT_KEY_DELAY = 25
    // Accumulator for typed letters, used to search in columns.
    this.WORD = ""
    // Cursor position in each column.
    this.CURSOR = {
      genera: null,
      species: null,
      names: null
    }
    // Current subset of SPECIES that is being displayed.
    this.CURRENT_SPECIES = []

    this.SCROLLBAR_WIDTH = null

    // primers imported from name_list_data.js
    this.GENERA = NL_GENERA
    this.SPECIES = NL_SPECIES
    this.NAMES = NL_NAMES

    // Shared MO utilities imported from mo_utilities.js
    this.escapeHTML = escapeHTML
    this.getScrollBarWidth = getScrollBarWidth
    this.EVENT_KEYS = EVENT_KEYS
  }

  connect() {
    this.element.dataset.stimulus = "connected";

    // These are the div elements for each column.
    this.DIVS = {
      genera: this.generaTarget,
      species: this.speciesTarget,
      names: this.namesTarget
    }

    this.initializeNames()
    this.drawColumn("genera", this.GENERA)
    this.drawColumn("names", this.NAMES)
    this.ourClick("genera", 0) // click on first genus
  }

  // -------------------------------  Events  ---------------------------------

  // Mouse moves over an item.
  ourMouseenter(event) {
    const [column, i] = this.getDataFromLi(event)

    if (this.CURSOR[column] != i)
      document.getElementById(column + i).classList.add("hot")
  }

  // Mouse moves off of an item.
  ourMouseleave(event) {
    const [column, i] = this.getDataFromLi(event)

    if (this.CURSOR[column] != i)
      document.getElementById(column + i).classList.remove("hot", "warm")
  }

  // Click on item.
  ourClick(event) {
    const [column, i] = this.getDataFromLi(event)

    this.WORD = ''
    this.focusSection(column)
    this.moveCursorIn(column, i)
    if (column == 'genera')
      this.selectGenus(this.GENERA[i])
    this.IGNORE_UNFOCUS = true
  }

  // Double-click on item.
  ourDblClick(event) {
    const [column, i] = this.getDataFromLi(event)

    if (column == 'species')
      this.insertName(this.CURRENT_SPECIES[i])
    if (column == 'names')
      this.removeName(this.NAMES[i])
  }

  // Utility to get relevant dataset from event target
  // NOTE: The controller itself prints the <li> with this dataset, below.
  // Must be currentTarget in case user clicks on nested <li><span>
  getDataFromLi(event) {
    const column = event.currentTarget?.dataset.column
    const i = event.currentTarget?.dataset.i
    return [column, i]
  }

  // Are we watching this key event?
  isWatching(event) {
    const c = String.fromCharCode(event.keyCode || event.which).toLowerCase()
    if (c.match(/[a-zA-Z \-]/) && !event.ctrlKey)
      return true
    switch (event.keyCode) {
      case this.EVENT_KEYS.backspace:
      case this.EVENT_KEYS.delete:
      case this.EVENT_KEYS.return:
      case this.EVENT_KEYS.tab:
      case this.EVENT_KEYS.up:
      case this.EVENT_KEYS.down:
      case this.EVENT_KEYS.left:
      case this.EVENT_KEYS.right:
      case this.EVENT_KEYS.home:
      case this.EVENT_KEYS.end:
      case this.EVENT_KEYS.pageup:
      case this.EVENT_KEYS.pagedown:
        return true
    }
    return false
  }

  // Also called when user presses a key.  Disable this if focused.
  ourKeypress(event) {
    if (this.FOCUS_COLUMN && this.isWatching(event)) {
      event.stopPropagation()
      return false
    } else {
      return true
    }
  }

  // Called when user un-presses a key.  Need to know so we can stop repeat.
  ourKeyup(event) {
    this.KEY = null
    if (this.REPEAT_CALLBACK) {
      clearTimeout(this.REPEAT_CALLBACK)
      this.REPEAT_CALLBACK = null
    }
  }

  // Called when user presses a key.  We keep track of where user is typing by
  // updating this.FOCUS_COLUMN (value is 'genera', 'species' or 'names').
  ourKeydown(event) {
    // Cursors, etc. must be explicitly focused to work.
    // (Otherwise you can't use them to navigate through the page as a whole.)
    if (!this.FOCUS_COLUMN || !this.isWatching(event)) return true

    this.KEY = event
    this.processKeystroke(event)

    // Schedule first repeat event.
    this.REPEAT_CALLBACK =
      window.setTimeout(
        () => { this.ourKeyrepeat(this.KEY) }, this.FIRST_KEY_DELAY
      )

    // Stop browser from doing anything with key presses when focused.
    event.stopPropagation()
    return false
  }

  // Called when a key repeats.
  ourKeyrepeat(event) {
    if (this.FOCUS_COLUMN && this.KEY) {
      this.processKeystroke(this.KEY)
      this.REPEAT_CALLBACK =
        window.setTimeout(
          () => { this.ourKeyrepeat(this.KEY) }, this.NEXT_KEY_DELAY
        )
    } else {
      this.KEY = null
    }
  }

  // Process a key stroke.  This happens when the user first presses a key, and
  // periodically after if they keep the key down.
  processKeystroke(event) {
    // Normal letters.
    const c = String.fromCharCode(event.keyCode || event.which).toLowerCase()
    if (c.match(/[a-zA-Z \-]/) && !event.ctrlKey ||
      event.keyCode == this.EVENT_KEYS.backspace) {

      // Update word with new letter or backspace.
      if (event.keyCode != this.EVENT_KEYS.backspace) {
        this.WORD += c
        // If start typing with no focus, assume they mean genus.
        if (!this.FOCUS_COLUMN) this.FOCUS_COLUMN = 'genera'
      } else if (this.WORD != '') {
        this.WORD = this.WORD.substr(0, this.WORD.length - 1)
      }

      // Search for partial word.
      const list = this.FOCUS_COLUMN == 'genera' ? this.GENERA :
        (this.FOCUS_COLUMN == 'species') ? this.CURRENT_SPECIES : this.NAMES
      let word = this.WORD
      if (this.FOCUS_COLUMN == 'species')
        word = this.CURRENT_SPECIES[0].replace(/\*$|\|.*/, '') + ' ' + this.WORD
      this.searchListForWord(list, word)
      return
    }

    // Clear word if user does *anything* else.
    // const old_word = this.WORD
    this.WORD = ''

    // Other strokes.
    let i = this.CURSOR[this.FOCUS_COLUMN]
    switch (event.keyCode) {

      // Move cursor up and down.
      case this.EVENT_KEYS.up:
        if (i != null) this.moveCursorIn(
          this.FOCUS_COLUMN, i - (event.ctrlKey ? 10 : 1)
        )
        break
      case this.EVENT_KEYS.down:
        this.moveCursorIn(
          this.FOCUS_COLUMN, i == null ? 0 : i + (event.ctrlKey ? 10 : 1)
        )
        break
      case this.EVENT_KEYS.pageup:
        if (i != null) this.moveCursorIn(this.FOCUS_COLUMN, i - 20)
        break
      case this.EVENT_KEYS.pagedown:
        this.moveCursorIn(this.FOCUS_COLUMN, i == null ? 20 : i + 20)
        break
      case this.EVENT_KEYS.home:
        if (i != null) this.moveCursorIn(this.FOCUS_COLUMN, 0)
        break
      case this.EVENT_KEYS.end:
        this.moveCursorIn(this.FOCUS_COLUMN, 10000000)
        break

      // Switch columns.
      case this.EVENT_KEYS.left:
        this.FOCUS_COLUMN = (this.FOCUS_COLUMN == 'genera') ? 'names'
          : (this.FOCUS_COLUMN == 'species') ? 'genera' : 'species'
        this.highlightCursors()
        break
      case this.EVENT_KEYS.right:
        this.FOCUS_COLUMN = (this.FOCUS_COLUMN == 'genera') ? 'species'
          : (this.FOCUS_COLUMN == 'species') ? 'names' : 'genera'
        this.highlightCursors()
        break
      case this.EVENT_KEYS.tab:
        if (event.shiftKey) {
          this.FOCUS_COLUMN = (this.FOCUS_COLUMN == 'genera') ? 'names'
            : (this.FOCUS_COLUMN == 'species') ? 'genera' : 'species'
        } else if (this.FOCUS_COLUMN == 'genera') {
          // Select current genus AND move to species column
          // if press tab in genus column.
          this.selectGenus(this.GENERA[i])
          this.FOCUS_COLUMN = 'species'
        } else {
          this.FOCUS_COLUMN = (this.FOCUS_COLUMN == 'species') ? 'names' : 'genera'
        }
        this.highlightCursors()
        break

      // Select an item.
      case this.EVENT_KEYS.return:
        if (this.FOCUS_COLUMN == 'genera' && i != null) {
          this.selectGenus(this.GENERA[i])
          this.FOCUS_COLUMN = 'species'
          this.highlightCursors()
        } else if (this.FOCUS_COLUMN == 'species' && i != null) {
          this.insertName(this.CURRENT_SPECIES[i])
        }
        break

      // Delete item under cursor.
      case this.EVENT_KEYS.delete:
        if (this.FOCUS_COLUMN == 'names' && i != null)
          this.removeName(this.NAMES[i])
        break
    }
  }

  // --------------------------------  HTML  ----------------------------------

  // Change focus from one column to another.
  ourFocus(event) {
    const column = event.target.id
    this.focusSection(column)
  }

  focusSection(column) {
    this.FOCUS_COLUMN = column
    this.highlightCursors()
  }

  // Unfocus to let user scroll the page with keyboard.
  ourUnfocus() {
    if (!this.IGNORE_UNFOCUS) {
      this.FOCUS_COLUMN = null
      this.highlightCursors()
    } else {
      this.IGNORE_UNFOCUS = false
    }
  }

  // Move cursor.
  moveCursorIn(column, new_pos) {
    const old_pos = this.CURSOR[column]
    this.CURSOR[column] = new_pos
    if (old_pos != null)
      document.getElementById(column + old_pos).classList.remove("hot", "warm")
    this.highlightCursors()
    this.scrollToCursorIn(column)
  }

  // Redraw all the cursors.
  highlightCursors() {
    // Make sure there *is* a cursor in the focused column.
    if (this.FOCUS_COLUMN && this.CURSOR[this.FOCUS_COLUMN] == null)
      this.CURSOR[this.FOCUS_COLUMN] = 0
    this.highlightCursor('genera', this.GENERA)
    this.highlightCursor('species', this.CURRENT_SPECIES)
    this.highlightCursor('names', this.NAMES)
  }

  // Draw a single cursor, making sure div is scrolled so we can see it.
  highlightCursor(column, list = []) {
    let i = this.CURSOR[column]
    if (list.length > 0 && i != null) {
      if (i < 0) this.CURSOR[column] = i = 0
      if (i >= list.length) this.CURSOR[column] = i = list.length - 1
      let li_el = document.getElementById(column + i)
      li_el.classList.remove("hot", "warm")
      let heat = (this.FOCUS_COLUMN == column) ? "warm" : "hot"
      li_el.classList.add(heat)
    } else {
      this.CURSOR[column] = null
    }
  }

  // Make sure cursor is visible in a given column.
  scrollToCursorIn(column) {
    let i = this.CURSOR[column] || 0
    let e = document.getElementById(column + i)
    if (!this.SCROLLBAR_WIDTH)
      this.SCROLLBAR_WIDTH = this.getScrollBarWidth(e)
    if (e && e.offsetTop) {
      const column_el = this.DIVS[column]
      const ey = e.offsetTop - e.parentElement.offsetTop
      const eh = e.offsetHeight
      const sy = column_el.scrollTop
      const sh = 450 - this.SCROLLBAR_WIDTH
      let ny = ey + eh > sy + sh ? ey + eh - sh : sy
      ny = (ey < ny) ? ey : ny
      if (sy != ny)
        column_el.scrollTop = ny
    }
  }

  // Draw contents of one of the three columns.
  // Sections: 'genera', 'species', 'names'; lists: GENERA, SPECIES, NAMES.
  drawColumn(column, list = []) {
    const ul = document.createElement("ul")

    for (let i = 0; i < list.length; i++) {
      let name = list[i]
      const x = name.indexOf('|')
      let name_el, name_inner, star
      let author_el = document.createElement("span")

      // the last one:
      if (star = (name.charAt(name.length - 1) == '*')) {
        name = name.substr(0, name.length - 1)
      }

      if (x > 0) {
        author_el.classList.add("normal")
        author_el.innerHTML = this.escapeHTML(name.substr(x + 1))
        name = name.substr(0, x)
      }

      // synonyms
      if (name.charAt(0) == '=') {
        name_el = document.createElement("span")
        name_el.classList.add("ml-2")
        name_el.innerHTML = "= "
        name_inner = document.createElement("strong")
        name_inner.innerHTML = this.escapeHTML(name.substr(2))
        name_el.appendChild(name_inner)
      } else if (star) {
        name_el = document.createElement("strong")
        name_el.innerHTML = this.escapeHTML(name)
      } else {
        name_el = document.createElement("span")
        name_el.innerHTML = this.escapeHTML(name)
      }

      // build the list item
      const li = document.createElement("li")
      li.id = column + i
      li.classList.add("text-nowrap", "name-list-item")
      li.setAttribute("data-column", column)
      li.setAttribute("data-i", i)
      const stimulus_actions = [
        "mouseenter->name-list#ourMouseenter",
        "mouseleave->name-list#ourMouseleave",
        "click->name-list#ourClick",
        "dblclick->name-list#ourDblClick"
      ].join(" ")
      if (column != "species")
        li.setAttribute("data-action", stimulus_actions)

      li.appendChild(name_el).appendChild(author_el)
      ul.appendChild(li)
    }

    this.DIVS[column].appendChild(ul)
  }

  // ------------------------------  Actions  ---------------------------------

  // Select a genus.
  selectGenus(name) {
    let list = [name]
    let last = false
    this.moveCursorIn('species', null)
    if (name.charAt(name.length - 1) == '*')
      name = name.substr(0, name.length - 1)
    name += ' '
    for (let i = 0; i < this.SPECIES.length; i++) {
      const species = this.SPECIES[i]
      if (species.substr(0, name.length) == name ||
        species.charAt(0) == '=' && last) {
        list.push(species)
        last = true
      } else {
        last = false
      }
    }
    this.CURSOR['species'] = null
    this.CURRENT_SPECIES = list
    this.drawColumn('species', list)
    this.scrollToCursorIn('species')
  }

  // Search in list for word and move cursor there.
  searchListForWord(list = [], word) {
    const word_len = word.length
    word = word.toLowerCase()
    for (let i = 0; i < list.length; i++) {
      if (list[i].substr(0, word_len).toLowerCase() == word) {
        this.moveCursorIn(this.FOCUS_COLUMN, i)
        break
      }
    }
  }

  // Insert a name.
  insertName(name) {
    let new_list = []
    let last
    if (name.charAt(0) == '=')
      name = name.substr(2) + '*'
    const name2 = name.replace('*', '')
    let done = false
    for (let i = 0; i < this.NAMES.length; i++) {
      const str = this.NAMES[i]
      if (!done && str.replace('*', '') >= name2) {
        if (str != name)
          new_list.push(name)
        this.CURSOR['names'] = i
        done = true
      }
      new_list.push(str)
      last = str
    }
    if (!done) {
      new_list.push(name)
      this.CURSOR['names'] = new_list.length - 1
    }
    this.NAMES = new_list
    this.drawColumn('names', this.NAMES)
    this.highlightCursors()
    this.scrollToCursorIn('names')
    this.setResults()
  }

  // Remove a name.
  removeName(name) {
    let new_list = []
    for (let i = 0; i < this.NAMES.length; i++)
      if (this.NAMES[i] == name)
        this.CURSOR['names'] = i
      else
        new_list.push(this.NAMES[i])
    this.NAMES = new_list
    this.drawColumn('names', this.NAMES)
    this.highlightCursors()
    this.scrollToCursorIn('names')
    this.setResults()
  }

  // Concat names in this.NAMES and store in hidden 'results' field.
  setResults() {
    let val = ''
    for (let i = 0; i < this.NAMES.length; i++)
      val += this.NAMES[i] + "\n"
    document.getElementById("results").value = val
  }

  // Reverse of above: parse hidden 'results' field, and populate this.NAMES.
  initializeNames() {
    let str = document.getElementById("results").value || ''
    str += "\n"
    let x
    this.NAMES = []
    while ((x = str.indexOf("\n")) >= 0) {
      if (x > 0)
        this.NAMES.push(str.substr(0, x))
      str = str.substr(x + 1)
    }
  }
}
