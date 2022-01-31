# frozen_string_literal: true

# The MO way is more complicated because admins
# * I log in, setting session_user
# * I turn on admin mode
# * I switch to another user, changing session_user, but saving my old session_user in real_user_id
# * when I'm done, I "logout"
# * but logout sees that real_user_id is present, so it just switches session_user back to my old session_user and clears real_user_id turning off the "sudo" mode
