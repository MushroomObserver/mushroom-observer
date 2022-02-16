# frozen_string_literal: true

module Types
  class BaseField < GraphQL::Schema::Field
    argument_class(Types::BaseArgument)
    # attr_accessor :require_admin, :require_owner

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
      # puts("ctx[:current_user]")
      # puts(ctx[:current_user])
      if ctx[:current_user].nil?
        false
      else
        ctx[:current_user]&.admin? ||
          (ctx[:current_user]&.id == owner_id(obj))
      end
    end

    # need access to obj here to determine owner_id
    # def visible?(ctx)
    #   # if `only_show_admin:` given, require the current user to be admin
    #   super && (@only_show_admin ? ctx[:current_user]&.admin? : true)
    #   super && (@only_show_owner ? owner_or_admin(obj, ctx) : true)
    # end

    # Field #authorized? methods are called before resolving a field
    # Note this effectively blocks resolution of a query field, eg user.email
    # But we need to enable unauthorized search for user by email in login
    def authorized?(obj, args, ctx)
      # if `require_admin:` was given, require current user to be an admin
      super && (@require_admin ? ctx[:current_user]&.admin? : true)
      super && (@require_owner ? owner_or_admin(obj, ctx) : true)
    end
  end
end
