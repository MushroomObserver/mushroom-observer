import BaseAutocompleterController, {
  AUTOCOMPLETER_TARGETS, AUTOCOMPLETER_OUTLETS
} from "./base_controller"

/**
 * RegionController - Autocompleter for Region searches
 *
 * Uses unordered matching with WHOLE_WORDS_ONLY mode.
 * Only sends requests when user finishes typing a word (trailing space/comma).
 * Example: typing "california " matches regions containing "California"
 */
export default class RegionController extends BaseAutocompleterController {
  // Must redeclare static properties - JavaScript doesn't inherit them
  static targets = AUTOCOMPLETER_TARGETS
  static outlets = AUTOCOMPLETER_OUTLETS

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
