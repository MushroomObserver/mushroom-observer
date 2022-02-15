# frozen_string_literal: true

module Types
  class BaseField < GraphQL::Schema::Field
    argument_class(Types::BaseArgument)
    # attr_accessor :require_admin, :require_owner

    # Pass `field ..., require_admin: true` to reject non-admin users from field
    # def initialize(*args, **kwargs, require_admin: false, &block)
    #   @require_admin = require_admin
    #   # @require_owner = require_owner
    #   super(*args, **kwargs, &block)
    # end

    # def owner_id
    #   object.has_attribute?(:user_id) ? object.user_id : object.id
    # end

    # def owner_or_admin
    #   ctx[:current_user]&.admin? || (ctx[:current_user]&.id === owner_id)
    # end

    # Field #authorized? methods are called before resolving a field
    # def authorized?(obj, args, ctx)
    #   # if `require_admin:` was given, require current user to be an admin
    #   super && (@require_admin ? ctx[:current_user]&.admin? : true)
    #   super && (@require_owner ? owner_or_admin : true)
    # end
  end
end
