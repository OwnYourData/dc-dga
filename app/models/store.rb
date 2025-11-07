# == Schema Information
#
# Table name: stores
#
#  id         :integer          not null, primary key
#  did        :string
#  dri        :string
#  item       :text
#  key        :string
#  meta       :text
#  repo       :string
#  schema     :string
#  user       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_stores_on_repo           (repo)
#  index_stores_on_user           (user)
#  index_stores_on_user_and_repo  (user,repo)
#
class Store < ApplicationRecord
  has_one_attached :pdf
end
