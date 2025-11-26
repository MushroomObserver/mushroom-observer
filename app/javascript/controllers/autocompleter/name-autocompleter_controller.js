import BaseAutocompleterController from "./base_controller"

/**
 * NameAutocompleterController - Autocompleter for Name (taxon) records
 *
 * Uses collapsed matching strategy - autocompletes word by word.
 * First completes genus, then species, then variety, etc.
 * Example: "Agar" → "Agaricus " → "Agaricus camp" → "Agaricus campestris"
 */
export default class NameAutocompleterController extends BaseAutocompleterController {
  /**
   * Type-specific configuration for name autocompleters.
   */
  getTypeConfig() {
    return {
      TYPE: "name",
      model: "name",
      COLLAPSE: 1
    }
  }

  /**
   * Uses collapsed matching - autocompletes word by word.
   */
  populateMatchesForType() {
    this.populateCollapsed()
  }
}
