import BaseAutocompleterController, {
  AUTOCOMPLETER_TARGETS, AUTOCOMPLETER_OUTLETS
} from "./base_controller"

/**
 * LocationAutocompleterController - Autocompleter for Location records
 *
 * Supports three modes:
 * - "location": Search existing locations (unordered matching)
 * - "location_containing": Search locations containing a lat/lng (select mode)
 * - "location_google": Create new location with Google geocoding (select mode)
 *
 * Mode can be switched at runtime via the swap() method, which is called by
 * the map and geocode controllers.
 */
export default class LocationAutocompleterController
  extends BaseAutocompleterController {
  // Must redeclare static properties - JavaScript doesn't inherit them
  static targets = AUTOCOMPLETER_TARGETS
  static outlets = AUTOCOMPLETER_OUTLETS

  /**
   * Type-specific configuration for location autocompleters.
   * Starts in "location" mode - can be swapped to other modes at runtime.
   */
  getTypeConfig() {
    return {
      TYPE: "location",
      model: "location",
      UNORDERED: true,
      ACT_LIKE_SELECT: false,
      AUTOFILL_SINGLE_MATCH: false
    }
  }

  /**
   * Uses the appropriate matching strategy based on current TYPE.
   * - location: unordered matching (words can appear in any order)
   * - location_containing/location_google: select mode (show all options)
   */
  populateMatchesForType() {
    if (this.ACT_LIKE_SELECT) {
      this.populateSelect()
    } else {
      this.populateUnordered()
    }
  }
}
