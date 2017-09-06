module FieldTest
  class Membership < ActiveRecord::Base
    self.table_name = "field_test_memberships"

    has_many :events, class_name: "FieldTest::Event"
    belongs_to :participant, class_name: "FieldTest::Participant"
    belongs_to :experiment, class_name: "FieldTest::Experiment"
    belongs_to :variant, class_name: "FieldTest::Variant"

    validates :participant, presence: true
    validates :experiment, presence: true
    validates :variant, presence: true

    validate do |membership|
      unless membership.experiment.variants.include?(membership.variant)
        errors.add(:experiment, "Variant does not belong to the experiment")
        errors.add(:variant, "Variant does not belong to the experiment")
      end
    end

  end
end
