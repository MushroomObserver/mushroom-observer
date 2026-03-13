import BaseAutocompleterController, {
  AUTOCOMPLETER_TARGETS, AUTOCOMPLETER_OUTLETS
} from "controllers/autocompleter/base_controller"

/**
 * CladeController - Autocompleter for Clade (taxonomic) searches
 *
 * Uses normal substring matching (default mode).
 * Example: typing "agaric" matches "Agaricales", "Agaricus"
 */
export default class CladeController extends BaseAutocompleterController {
  // Must redeclare static properties - JavaScript doesn't inherit them
  static targets = AUTOCOMPLETER_TARGETS
  static outlets = AUTOCOMPLETER_OUTLETS

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
