import BaseAutocompleterController from "./base_controller"

/**
 * RegionController - Autocompleter for Region searches
 *
 * Uses unordered matching with WHOLE_WORDS_ONLY mode.
 * Only sends requests when user finishes typing a word (trailing space/comma).
 * Example: typing "california " matches regions containing "California"
 */
export default class RegionController extends BaseAutocompleterController {
  /**
   * Type-specific configuration for region autocompleters.
   */
  getTypeConfig() {
    return {
      TYPE: "region",
      model: "location",
      UNORDERED: true,
      WHOLE_WORDS_ONLY: true
    }
  }

  /**
   * Uses unordered matching - words can appear in any order.
   */
  populateMatchesForType() {
    this.populateUnordered()
  }
}
