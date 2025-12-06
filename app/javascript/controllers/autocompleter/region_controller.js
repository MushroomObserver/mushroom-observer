import BaseAutocompleterController, {
  AUTOCOMPLETER_TARGETS, AUTOCOMPLETER_OUTLETS
} from "./base_controller"

/**
 * RegionController - Autocompleter for Region searches
 *
 * Uses unordered matching. Results are preserved in server order (by box_area)
 * so broader regions appear first.
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
      PRESERVE_ORDER: true
    }
  }

  /**
   * Uses unordered matching - words can appear in any order.
   */
  populateMatchesForType() {
    this.populateUnordered()
  }
}
