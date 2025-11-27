import BaseAutocompleterController, {
  AUTOCOMPLETER_TARGETS, AUTOCOMPLETER_OUTLETS
} from "./base_controller"

/**
 * UserAutocompleterController - Autocompleter for User records
 *
 * Uses unordered matching (words can appear in any order).
 * Example: typing "roy hall" matches "Roy Halling"
 */
export default class UserAutocompleterController extends BaseAutocompleterController {
  // Must redeclare static properties - JavaScript doesn't inherit them
  static targets = AUTOCOMPLETER_TARGETS
  static outlets = AUTOCOMPLETER_OUTLETS

  /**
   * Type-specific configuration for user autocompleters.
   */
  getTypeConfig() {
    return {
      TYPE: "user",
      model: "user",
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
