# frozen_string_literal: true

module Types
  class BaseField < GraphQL::Schema::Field
    argument_class(Types::BaseArgument)

    # Pass `field ..., require_admin: true` to reject non-admin users from field
    def initialize(*args, require_admin: false, require_owner: false,
                   **kwargs, &block)
      @require_admin = require_admin
      @require_owner = require_owner
      super(*args, **kwargs, &block)
    end

    def owner_id(obj)
      obj.has_attribute?(:user_id) ? obj.user_id : obj.id
    end

    def owner_or_admin(obj, ctx)
      if ctx[:current_user].nil?
        false
      else
        ctx[:current_user]&.admin? ||
          (ctx[:current_user]&.id == owner_id(obj))
      end
    end

    # Field #authorized? methods are called before resolving a field
    # Note this effectively blocks resolution of a query field, eg user.email
    def authorized?(obj, args, ctx)
      return false unless super
      # if `require_admin: true`, require current user to be an admin
      return false if @require_admin && !ctx[:current_user]&.admin?
      # if `require_owner: true`, require current user to be obj owner or admin
      return false if @require_owner && !owner_or_admin(obj, ctx)

      true
    end
  end
end
