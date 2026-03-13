import BaseAutocompleterController, {
  AUTOCOMPLETER_TARGETS, AUTOCOMPLETER_OUTLETS
} from "controllers/autocompleter/base_controller"

/**
 * HerbariumController - Autocompleter for Herbarium records
 *
 * Uses unordered matching (words can appear in any order).
 * Example: typing "fun herb" matches "New York Botanical Garden Fungarium"
 */
export default class HerbariumController extends BaseAutocompleterController {
  // Must redeclare static properties - JavaScript doesn't inherit them
  static targets = AUTOCOMPLETER_TARGETS
  static outlets = AUTOCOMPLETER_OUTLETS

  /**
   * Type-specific configuration for herbarium autocompleters.
   */
  getTypeConfig() {
    return {
      TYPE: "herbarium",
      model: "herbarium",
      UNORDERED: true
    }
  }

  /**
   * Uses unordered matching - words can appear in any order.
   */
  populateMatchesForType() {
    this.populateUnordered()
  }
}
