# == Schema Information
#
# Table name: access_requests
#
#  id         :integer          not null, primary key
#  email      :string
#  guid       :string
#  name       :string
#  note       :text
#  reference  :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer
#
# Indexes
#
#  index_access_requests_on_user_id  (user_id)
#
# Foreign Keys
#
#  user_id  (user_id => users.id)
#
class AccessRequest < ApplicationRecord
end