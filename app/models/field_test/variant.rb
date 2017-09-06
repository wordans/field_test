module FieldTest
  class Variant < ActiveRecord::Base
    self.table_name = "field_test_variants"

    has_many :memberships, class_name: "FieldTest::Membership"
    has_many :participants, through: :memberships, source: "FieldTest::Participant"
    has_many :variants, class_name: "FieldTest::Variant"
  end
end
