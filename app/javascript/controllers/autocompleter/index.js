/**
 * Autocompleter Controllers and Mixins
 *
 * These modules provide modular functionality for autocompleter controllers.
 * - BaseAutocompleterController: Core functionality all autocompleters share
 * - Type-specific controllers: Extend Base with type-specific matching logic
 * - Mixins: Optional functionality that can be composed into controllers
 *
 * Controller naming convention:
 * - Files: {type}_controller.js
 * - Stimulus identifier: autocompleter--{type}
 * - Example: data-controller="autocompleter--user"
 */

// Base controller
export { default as BaseAutocompleterController } from "./base_controller";

// Type-specific controllers
export { default as UserController } from "./user_controller";
export { default as NameController } from "./name_controller";
export { default as LocationController } from "./location_controller";
export { default as HerbariumController } from "./herbarium_controller";
export { default as ProjectController } from "./project_controller";
export { default as SpeciesListController } from "./species_list_controller";
export { default as CladeController } from "./clade_controller";
export { default as RegionController } from "./region_controller";

// Mixins
export { MultiValueMixin } from "./multi_value_mixin";
export { MapIntegrationMixin } from "./map_integration_mixin";
