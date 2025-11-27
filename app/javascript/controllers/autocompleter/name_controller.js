import BaseAutocompleterController, {
  AUTOCOMPLETER_TARGETS, AUTOCOMPLETER_OUTLETS
} from "./base_controller"

/**
 * NameAutocompleterController - Autocompleter for Name (taxon) records
 *
 * Uses collapsed matching strategy - autocompletes word by word.
 * First completes genus, then species, then variety, etc.
 * Example: "Agar" → "Agaricus " → "Agaricus camp" → "Agaricus campestris"
 */
export default class NameAutocompleterController extends BaseAutocompleterController {
  // Must redeclare static properties - JavaScript doesn't inherit them
  static targets = AUTOCOMPLETER_TARGETS
  static outlets = AUTOCOMPLETER_OUTLETS

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
