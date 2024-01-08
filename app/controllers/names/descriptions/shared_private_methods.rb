# frozen_string_literal: true

module Names::Descriptions
  module SharedPrivateMethods
    private

    # This either finds a description by id, or sets the ivar from the param.
    def find_description!(id = nil)
      desc_id = id || params[:id]
      @description = NameDescription.includes(show_includes).strict_loading.
                     find_by(id: desc_id) ||
                     flash_error_and_goto_index(NameDescription, desc_id)
    end

    def show_includes
      [{ admin_groups: { users: :user_groups } },
       :authors,
       :comments,
       :editors,
       :interests,
       :license,
       { name: [{ description: :reviewer },
                { descriptions: :reviewer },
                :interests,
                :rss_log,
                { synonym: :names }] },
       { name_description_admins: :user_group },
       :name_description_authors,
       :name_description_editors,
       { name_description_readers: :user_group },
       { name_description_writers: :user_group },
       :project,
       { reader_groups: { users: :user_groups } },
       :reviewer,
       { user: :user_groups },
       :versions,
       { writer_groups: { users: :user_groups } }]
    end
  end
end
