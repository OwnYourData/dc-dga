# == Schema Information
#
# Table name: knowledgebases
#
#  id          :integer          not null, primary key
#  description :string
#  frontpage   :boolean
#  icon        :string
#  intro       :text
#  lang        :string
#  link        :string
#  position    :integer
#  short       :string
#  title       :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Knowledgebase < ApplicationRecord
end