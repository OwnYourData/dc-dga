# == Schema Information
#
# Table name: events
#
#  id           :integer          not null, primary key
#  event        :string
#  event_object :text
#  event_type   :integer
#  timestamp    :datetime
#  user         :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  store_id     :integer
#
# Indexes
#
#  index_events_on_user  (user)
#
class Event < ApplicationRecord
end