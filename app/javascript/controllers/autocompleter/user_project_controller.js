import BaseAutocompleterController, {
  AUTOCOMPLETER_TARGETS, AUTOCOMPLETER_OUTLETS
} from "controllers/autocompleter/base_controller"

/**
 * UserProjectController - Autocompleter for Projects the current
 * user belongs to (server-side: Autocomplete::ForUserProject).
 *
 * Uses unordered matching (words can appear in any order), same as
 * the plain project autocompleter.
 */
export default class UserProjectController extends BaseAutocompleterController {
  // Must redeclare static properties - JavaScript doesn't inherit them
  static targets = AUTOCOMPLETER_TARGETS
  static outlets = AUTOCOMPLETER_OUTLETS

  /**
   * Type-specific configuration for user-project autocompleters.
   */
  getTypeConfig() {
    return {
      TYPE: "user_project",
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
