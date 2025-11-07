# == Schema Information
#
# Table name: users
#
#  id                            :integer          not null, primary key
#  bpk                           :string
#  did                           :string
#  did_valid_until               :string
#  email                         :string
#  email_verification_expires_at :datetime
#  email_verification_token      :string
#  email_verified                :string
#  email_verified_at             :datetime
#  given_name                    :string
#  ida_auth_time                 :integer
#  last_name                     :string
#  postcode                      :string
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#
# Indexes
#
#  index_users_on_bpk  (bpk)
#  index_users_on_did  (did)
#
class User < ApplicationRecord
end