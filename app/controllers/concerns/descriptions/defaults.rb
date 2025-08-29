# frozen_string_literal: true

#  make_description_default::
module Descriptions::Defaults
  extend ActiveSupport::Concern

  included do
    before_action :pass_query_params

    # PUT callback to make a description the default one.
    # Description must be publically readable and writable.
    def update
      return unless (desc = find_description!)

      redirect_to(desc.show_link_args)
      unless desc.fully_public?
        flash_error(:runtime_description_make_default_only_public.t)
        return
      end
      desc.parent.description_id = desc.id
      desc.parent.log(:log_changed_default_description,
                      user: @user.login,
                      name: desc.unique_partial_format_name,
                      touch: true)
      desc.parent.save
    end

    include ::Descriptions
  end
end
