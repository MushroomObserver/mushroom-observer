import BaseAutocompleterController from "./base_controller"

/**
 * HerbariumController - Autocompleter for Herbarium records
 *
 * Uses unordered matching (words can appear in any order).
 * Example: typing "fun herb" matches "New York Botanical Garden Fungarium"
 */
export default class HerbariumController extends BaseAutocompleterController {
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
