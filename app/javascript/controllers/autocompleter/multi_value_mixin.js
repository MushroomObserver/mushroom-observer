/**
 * MultiValueMixin - Handles multiple value autocompleter logic
 *
 * This mixin provides functionality for autocompleters that accept multiple
 * values separated by a SEPARATOR (e.g., "\n" for search forms).
 *
 * Features:
 * - Tracks multiple hidden IDs as comma-separated values
 * - Manages "keepers" array to store selected {name, id} pairs
 * - Handles search token extraction for the current segment
 * - Syncs hidden IDs with input values when items are added/removed
 *
 * Usage: Object.assign(this, MultiValueMixin) in controller initialize()
 */

export const MultiValueMixin = {
  // ---------------------- Search Token (Multi) ----------------------

  // Get index of first character and character after last of current token.
  searchTokenExtents() {
    const val = this.inputTarget.value;
    let start = val.lastIndexOf(this.SEPARATOR),
      end = val.length;

    if (start < 0)
      start = 0;
    else
      start += this.SEPARATOR.length;

    return { start, end };
  },

  // When there are multiple values separated by a separator.
  getSearchTokenIndex() {
    this.verbose("MultiValueMixin:getSearchTokenIndex()");
    const token = this.getLastInput();
    return this.getInputIndexOf(token);
  },

  getInputIndexOf(token) {
    this.verbose("MultiValueMixin:getInputIndexOf()");
    const idx = this.getInputArray().indexOf(token);
    this.verbose(idx);
    return idx;
  },

  getLastInput() {
    this.verbose("MultiValueMixin:getLastInput()");
    const token = this.getInputArray().pop();
    this.verbose(token);
    return token;
  },

  getInputArray() {
    this.verbose("MultiValueMixin:getInputArray()");
    const input_value = this.inputTarget.value;
    const input_array = (() => {
      // Don't return an array with an empty string, return an empty array.
      if (input_value == "") {
        return [];
      } else {
        return input_value.split(this.SEPARATOR).map((v) => v.trim());
      }
    })();
    this.verbose(input_array);
    return input_array;
  },

  getInputCount() {
    this.verbose("MultiValueMixin:getInputCount()");
    const count = this.getInputArray().length;
    this.verbose(count);
    return count;
  },

  // ---------------------- Hidden ID Management (Multi) ----------------------

  // add the new id at the same index of the array as the search token.
  // Converts array back to string.
  updateHiddenTargetValueMultiple(match) {
    this.verbose("MultiValueMixin:updateHiddenTargetValueMultiple()");
    let new_array = this.stored_ids,
      idx = this.getSearchTokenIndex(),
      { name, id } = match,
      new_data = { name, id };

    if (idx > -1) {
      new_array[idx] = parseInt(match['id']);
      this.hiddenTarget.value = new_array.join(",");
      this.keepers[idx] = new_data;
    }
  },

  // Multiple: We have to be careful here to delete only the id that is
  // at the same index as the search token. Otherwise it keeps deleting.
  clearLastHiddenIdAndKeeper() {
    this.verbose("MultiValueMixin:clearLastHiddenIdAndKeeper()");
    // not worried about integers here
    let hidden_ids = this.hiddenIdsAsIntegerArray(),
      idx = this.getSearchTokenIndex();

    this.verbose("MultiValueMixin:hidden_ids: ")
    this.verbose(JSON.stringify(hidden_ids));
    this.verbose("MultiValueMixin:idx: ")
    this.verbose(idx);

    if (idx > -1 && hidden_ids.length > idx) {
      hidden_ids.splice(idx, 1);
      this.hiddenTarget.value = hidden_ids.join(",");
      // also clear the dataset
      if (this.keepers.length > idx) {
        this.verbose("MultiValueMixin:keepers: ")
        this.verbose(JSON.stringify(this.keepers));
        this.keepers.splice(idx, 1);
      }
    }
  },

  storeCurrentHiddenDataMultiple() {
    this.verbose("MultiValueMixin:storeCurrentHiddenDataMultiple()");
    this.stored_ids = this.hiddenIdsAsIntegerArray();
    this.verbose("stored_ids: " + JSON.stringify(this.stored_ids));
  },

  hiddenIdsChangedMultiple() {
    const hidden_ids = this.hiddenIdsAsIntegerArray();

    if (JSON.stringify(hidden_ids) == JSON.stringify(this.stored_ids)) {
      this.verbose("MultiValueMixin: hidden_ids did not change");
    } else {
      clearTimeout(this.data_timer);
      this.data_timer = setTimeout(() => {
        this.verbose("MultiValueMixin: hidden_ids changed");
        this.verbose("MultiValueMixin:hidden_ids: ")
        this.verbose(JSON.stringify(hidden_ids));
        this.cssHasIdOrNo(this.lastHiddenTargetValue());
        this.inputTarget.focus();
      }, 750)
    }
  },

  hiddenIdsAsIntegerArray() {
    return this.hiddenTarget.value.
      split(",").map((e) => parseInt(e.trim())).filter(Number);
  },

  // ---------------------- Keepers Sync ----------------------

  // check if any names in `keepers` are not in the input values.
  // if so, remove them from the keepers and the hidden input.
  removeUnusedKeepersAndIds() {
    if (!this.SEPARATOR || this.keepers == []) return;

    this.verbose("MultiValueMixin:removeUnusedKeepersAndIds()");
    this.verbose("MultiValueMixin:keepers: ")
    this.verbose(JSON.stringify(this.keepers));

    const input_names = this.getInputArray(),
      hidden_ids = this.hiddenIdsAsIntegerArray();
    this.verbose("MultiValueMixin:input_names: ")
    this.verbose(JSON.stringify(input_names));
    this.verbose("MultiValueMixin:hidden_ids: ")
    this.verbose(JSON.stringify(hidden_ids));

    this.keepers.filter((d) => !input_names.includes(d.name)).forEach((d) => {
      const idx = hidden_ids.indexOf(d.id);
      if (idx > -1) {
        hidden_ids.splice(idx, 1);
      }
      const kidx = this.keepers.indexOf(d);
      if (kidx > -1) {
        this.keepers.splice(kidx, 1);
      }
    });
    // update the hidden input
    this.hiddenTarget.value = hidden_ids.join(",");
    // also check for missing?
    this.addMissingKeepersAndIds(input_names);
  },

  // If the input names don't match what's stored in our keepers or hidden ids,
  // we need to add them in. NOTE: The fetch response that updates keepers and
  // ids expects for the keepers and ids to be the same length and at the same
  // index as the input names, so we can't just push things into arrays. We
  // need to arrange them at the right index for each existing keeper and id.
  // Account for pasting into an existing list.
  addMissingKeepersAndIds(input_names) {
    if (input_names.length == 0) return;

    this.verbose("MultiValueMixin:addMissingKeepersAndIds()");
    // Prepare null values in the array where we need to add new keepers
    this.addMissingKeepers(input_names);
    // Do the same for the hidden IDs. Check these against the keeper ids.
    this.addMissingHiddenIds(input_names);

    // Now try to fetch records for the missing input names
    const missing = input_names.filter((n) => {
      return !this.keepers.map((d) => d.name).includes(n);
    });

    if (missing.length > 0) {
      this.fetchMissingRecords(missing);
    }
  },

  addMissingKeepers(input_names) {
    if (!(this.keepers.length < input_names.length)) return;

    const new_keepers = new Array(input_names.length).
      fill({ name: null, id: null });
    if (this.keepers.length > 0) {
      // Put current keepers in the right positions in the new array
      input_names.forEach((n, i) => {
        const idx = this.keepers.map((d) => d.name).indexOf(n);
        if (idx > -1) {
          new_keepers[i] = this.keepers[idx];
        }
      });
    }
    this.keepers = new_keepers;
  },

  addMissingHiddenIds(input_names) {
    const hidden_ids = this.hiddenIdsAsIntegerArray();
    if (!(hidden_ids.length < input_names.length)) return;

    const new_ids = new Array(input_names.length).fill(null);
    if (hidden_ids.length > 0) {
      // Put current ids in the right positions in the new array
      this.keepers.forEach((n, i) => {
        const idx = hidden_ids.indexOf(n.id);
        if (idx > -1) {
          new_ids[i] = hidden_ids[idx];
        }
      });
    }
    this.hiddenTarget.value = new_ids.join(",");
  },

  // ---------------------- Fetch Missing Records ----------------------

  // Fetch records for the missing input names.
  fetchMissingRecords(missing) {
    this.verbose("MultiValueMixin:fetchMissingRecords(missing): ")
    this.verbose(JSON.stringify(missing));
    // send these staggered so they don't cancel each other.
    missing.forEach((token, i) => {
      setTimeout(() => {
        this.matchOneToken(token);
      }, i * 450);
    });
  },

  // For multiple-value autocompleters, try to get a matching record for a
  // single input value. This is for the case where the user pastes in an array
  // of values, so it's skipping the single match process.
  matchOneToken(token) {
    const query_params = { string: token, ...this.request_params }
    query_params["whole"] = true;
    query_params["all"] = true;
    query_params["exact"] = true;

    // Make request.
    this.sendFetchRequest(query_params, true);
  },

  // If we get a match, add the record to the hidden input and keepers array.
  processMatchFetchResponse(new_primer) {
    this.verbose("MultiValueMixin:processMatchFetchResponse()");
    this.verbose("MultiValueMixin:new_primer: ")
    this.verbose(JSON.stringify(new_primer));

    // Clear flag telling us request is pending.
    this.fetch_request = null;

    // If results, we're going to assume the first match is an exact match.
    if (new_primer.length > 0) {
      let exact_match = new_primer[0];
      // The match may have extra data we don't need in the keepers.
      // We only need the id and name.
      exact_match = { id: exact_match['id'], name: exact_match['name'] };
      // Order is important here. Figure out where the match is in the input.
      const idx = this.getInputIndexOf(exact_match['name']);
      if (idx == -1) { return; }

      let hidden_ids = this.hiddenIdsAsIntegerArray();
      // if the exact match is not in the hidden ids, add it at the right index.
      if (!hidden_ids.includes(exact_match['id'])) {
        hidden_ids.splice(idx, 1, exact_match['id']);
        this.hiddenTarget.value = hidden_ids.join(",");
      }
      // if it's not in keepers, add it at the right index. (Note extra data
      // would block the match here.)
      if (!this.keepers.includes(exact_match)) {
        this.keepers.splice(idx, 1, exact_match);
      }
    }
  }
};

export default MultiValueMixin;
