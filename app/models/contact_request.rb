class ContactRequest < ApplicationRecord
  validates :name, :email, :message, presence: true
  validate :honeypot_must_be_blank

  private

  def honeypot_must_be_blank
    if honeypot.present?
      errors.add(:base, "Spam detected")
    end
  end
end

