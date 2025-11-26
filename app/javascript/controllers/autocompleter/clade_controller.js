import BaseAutocompleterController from "./base_controller"

/**
 * CladeController - Autocompleter for Clade (taxonomic) searches
 *
 * Uses normal substring matching (default mode).
 * Example: typing "agaric" matches "Agaricales", "Agaricus"
 */
export default class CladeController extends BaseAutocompleterController {
  /**
   * Type-specific configuration for clade autocompleters.
   */
  getTypeConfig() {
    return {
      TYPE: "clade",
      model: "name"
    }
  }

  // Uses default populateMatchesForType() which calls populateNormal()
}
