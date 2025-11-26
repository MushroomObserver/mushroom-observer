/**
 * Autocompleter Controllers and Mixins
 *
 * These modules provide modular functionality for autocompleter controllers.
 * - BaseAutocompleterController: Core functionality all autocompleters share
 * - Type-specific controllers: Extend Base with type-specific matching logic
 * - Mixins: Optional functionality that can be composed into controllers
 *
 * Controller naming convention:
 * - Files: {type}-autocompleter_controller.js
 * - Stimulus identifier: autocompleter--{type}-autocompleter
 * - Example: data-controller="autocompleter--user-autocompleter"
 */

// Base controller
export { default as BaseAutocompleterController } from "./base_controller";

// Type-specific controllers
export {
  default as UserAutocompleterController
} from "./user-autocompleter_controller";
export {
  default as NameAutocompleterController
} from "./name-autocompleter_controller";
export {
  default as LocationAutocompleterController
} from "./location-autocompleter_controller";

// Mixins
export { MultiValueMixin } from "./multi_value_mixin";
export { MapIntegrationMixin } from "./map_integration_mixin";
