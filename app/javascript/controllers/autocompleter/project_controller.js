import BaseAutocompleterController from "./base_controller"

/**
 * ProjectController - Autocompleter for Project records
 *
 * Uses unordered matching (words can appear in any order).
 * Example: typing "bolete north" matches "North American Boletes"
 */
export default class ProjectController extends BaseAutocompleterController {
  /**
   * Type-specific configuration for project autocompleters.
   */
  getTypeConfig() {
    return {
      TYPE: "project",
      model: "project",
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
