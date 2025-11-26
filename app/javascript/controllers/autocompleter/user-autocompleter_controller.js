import BaseAutocompleterController from "./base_controller"

/**
 * UserAutocompleterController - Autocompleter for User records
 *
 * Uses unordered matching (words can appear in any order).
 * Example: typing "roy hall" matches "Roy Halling"
 */
export default class UserAutocompleterController extends BaseAutocompleterController {
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
