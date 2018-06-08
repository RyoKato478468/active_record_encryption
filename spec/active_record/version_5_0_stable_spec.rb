# frozen_string_literal: true

# rubocop:disable all
RSpec.describe 'ActiveRecord::Version50Stable' do
  next unless Gem::Version.create('5.0') <= ActiveRecord.gem_version && ActiveRecord.gem_version < Gem::Version.create('5.1')

  # 198bc1f785a7b826dfd50ccb068fdcbe463b34f6
  # Copy from rails/rails - activerecord/test/cases/dirty_test.rb
  describe 'compatible' do
    include InTimeZone
    include WithTimezoneConfig
    include ActiveRecordAssertion

    include_context 'with activerecord model'

    # Dummy to force column loads so query counts are clean.
    before do
      Person.create(first_name: 'foo')
      SQLCounter.clear_log

      # Stub connection
      allow(ActiveRecord::Base).to receive(:connection).and_return(Sqlite3Adapter.connection)
      stub_const('ActiveRecord::SQLCounter', SQLCounter)
    end

    # :%s!^    def\s*\(.*\)!test '\1' do!g
    # :%s!^    test\(.*\)!    example!g

    example 'test_attribute_changes' do
      # New record - no changes.
      pirate = Pirate.new
      assert_equal false, pirate.catchphrase_changed?
      assert_equal false, pirate.non_validated_parrot_id_changed?

      # Change catchphrase.
      pirate.catchphrase = 'arrr'
      assert pirate.catchphrase_changed?
      assert_nil pirate.catchphrase_was
      assert_equal [nil, 'arrr'], pirate.catchphrase_change

      # Saved - no changes.
      pirate.save!
      assert !pirate.catchphrase_changed?
      assert_nil pirate.catchphrase_change

      # Same value - no changes.
      pirate.catchphrase = 'arrr'
      assert !pirate.catchphrase_changed?
      assert_nil pirate.catchphrase_change
    end

    example 'test_time_attributes_changes_with_time_zone' do
      in_time_zone 'Paris' do
        target = Class.new(ActiveRecord::Base)
        target.table_name = 'pirates'

        # New record - no changes.
        pirate = target.new
        assert !pirate.created_on_changed?
        assert_nil pirate.created_on_change

        # Saved - no changes.
        pirate.catchphrase = 'arrrr, time zone!!'
        pirate.save!
        assert !pirate.created_on_changed?
        assert_nil pirate.created_on_change

        # Change created_on.
        old_created_on = pirate.created_on
        pirate.created_on = Time.now - 1.day
        assert pirate.created_on_changed?
        assert_kind_of ActiveSupport::TimeWithZone, pirate.created_on_was
        assert_equal old_created_on, pirate.created_on_was
        pirate.created_on = old_created_on
        assert !pirate.created_on_changed?
      end
    end

    example 'test_setting_time_attributes_with_time_zone_field_to_itself_should_not_be_marked_as_a_change' do
      in_time_zone 'Paris' do
        target = Class.new(ActiveRecord::Base)
        target.table_name = 'pirates'

        pirate = target.create!
        pirate.created_on = pirate.created_on
        assert !pirate.created_on_changed?
      end
    end

    example 'test_time_attributes_changes_without_time_zone_by_skip' do
      in_time_zone 'Paris' do
        target = Class.new(ActiveRecord::Base)
        target.table_name = 'pirates'

        target.skip_time_zone_conversion_for_attributes = [:created_on]

        # New record - no changes.
        pirate = target.new
        assert !pirate.created_on_changed?
        assert_nil pirate.created_on_change

        # Saved - no changes.
        pirate.catchphrase = 'arrrr, time zone!!'
        pirate.save!
        assert !pirate.created_on_changed?
        assert_nil pirate.created_on_change

        # Change created_on.
        old_created_on = pirate.created_on
        pirate.created_on = Time.now + 1.day
        assert pirate.created_on_changed?
        # kind_of does not work because
        # ActiveSupport::TimeWithZone.name == 'Time'
        assert_instance_of Time, pirate.created_on_was
        assert_equal old_created_on, pirate.created_on_was
      end
    end

    example 'test_time_attributes_changes_without_time_zone' do
      with_timezone_config aware_attributes: false do
        target = Class.new(ActiveRecord::Base)
        target.table_name = 'pirates'

        # New record - no changes.
        pirate = target.new
        assert !pirate.created_on_changed?
        assert_nil pirate.created_on_change

        # Saved - no changes.
        pirate.catchphrase = 'arrrr, time zone!!'
        pirate.save!
        assert !pirate.created_on_changed?
        assert_nil pirate.created_on_change

        # Change created_on.
        old_created_on = pirate.created_on
        pirate.created_on = Time.now + 1.day
        assert pirate.created_on_changed?
        # kind_of does not work because
        # ActiveSupport::TimeWithZone.name == 'Time'
        assert_instance_of Time, pirate.created_on_was
        assert_equal old_created_on, pirate.created_on_was
      end
    end

    example 'test_aliased_attribute_changes' do
      # the actual attribute here is name, title is an
      # alias setup via alias_attribute
      parrot = Parrot.new
      assert !parrot.title_changed?
      assert_nil parrot.title_change

      parrot.name = 'Sam'
      assert parrot.title_changed?
      assert_nil parrot.title_was
      assert_equal parrot.name_change, parrot.title_change
    end

    example 'test_restore_attribute!' do
      pirate = Pirate.create!(catchphrase: 'Yar!')
      pirate.catchphrase = 'Ahoy!'

      pirate.restore_catchphrase!
      assert_equal 'Yar!', pirate.catchphrase
      assert_equal({}, pirate.changes)
      assert !pirate.catchphrase_changed?
    end

    example 'test_nullable_number_not_marked_as_changed_if_new_value_is_blank' do
      pirate = Pirate.new

      ['', nil].each do |value|
        pirate.parrot_id = value
        assert !pirate.parrot_id_changed?
        assert_nil pirate.parrot_id_change
      end
    end

    example 'test_nullable_decimal_not_marked_as_changed_if_new_value_is_blank' do
      numeric_data = NumericData.new

      ['', nil].each do |value|
        numeric_data.bank_balance = value
        assert !numeric_data.bank_balance_changed?
        assert_nil numeric_data.bank_balance_change
      end
    end

    example 'test_nullable_float_not_marked_as_changed_if_new_value_is_blank' do
      numeric_data = NumericData.new

      ['', nil].each do |value|
        numeric_data.temperature = value
        assert !numeric_data.temperature_changed?
        assert_nil numeric_data.temperature_change
      end
    end

    example 'test_nullable_datetime_not_marked_as_changed_if_new_value_is_blank' do
      in_time_zone 'Edinburgh' do
        target = Class.new(ActiveRecord::Base)
        target.table_name = 'topics'

        topic = target.create
        assert_nil topic.written_on

        ['', nil].each do |value|
          topic.written_on = value
          assert_nil topic.written_on
          assert !topic.written_on_changed?
        end
      end
    end

    example 'test_integer_zero_to_string_zero_not_marked_as_changed' do
      pirate = Pirate.new
      pirate.parrot_id = 0
      pirate.catchphrase = 'arrr'
      assert pirate.save!

      assert !pirate.changed?

      pirate.parrot_id = '0'
      assert !pirate.changed?
    end

    example 'test_integer_zero_to_integer_zero_not_marked_as_changed' do
      pirate = Pirate.new
      pirate.parrot_id = 0
      pirate.catchphrase = 'arrr'
      assert pirate.save!

      assert !pirate.changed?

      pirate.parrot_id = 0
      assert !pirate.changed?
    end

    example 'test_float_zero_to_string_zero_not_marked_as_changed' do
      data = NumericData.new temperature: 0.0
      data.save!

      assert_not data.changed?

      data.temperature = '0'
      assert_empty data.changes

      data.temperature = '0.0'
      assert_empty data.changes

      data.temperature = '0.00'
      assert_empty data.changes
    end

    example 'test_zero_to_blank_marked_as_changed' do
      pirate = Pirate.new
      pirate.catchphrase = 'Yarrrr, me hearties'
      pirate.parrot_id = 1
      pirate.save

      # check the change from 1 to ''
      pirate = Pirate.find_by_catchphrase('Yarrrr, me hearties')
      pirate.parrot_id = ''
      assert pirate.parrot_id_changed?
      assert_equal([1, nil], pirate.parrot_id_change)
      pirate.save

      # check the change from nil to 0
      pirate = Pirate.find_by_catchphrase('Yarrrr, me hearties')
      pirate.parrot_id = 0
      assert pirate.parrot_id_changed?
      assert_equal([nil, 0], pirate.parrot_id_change)
      pirate.save

      # check the change from 0 to ''
      pirate = Pirate.find_by_catchphrase('Yarrrr, me hearties')
      pirate.parrot_id = ''
      assert pirate.parrot_id_changed?
      assert_equal([0, nil], pirate.parrot_id_change)
    end

    example 'test_object_should_be_changed_if_any_attribute_is_changed' do
      pirate = Pirate.new
      assert !pirate.changed?
      assert_equal [], pirate.changed
      assert_equal({}, pirate.changes)

      pirate.catchphrase = 'arrr'
      assert pirate.changed?
      assert_nil pirate.catchphrase_was
      assert_equal %w[catchphrase], pirate.changed
      assert_equal({ 'catchphrase' => [nil, 'arrr'] }, pirate.changes)

      pirate.save
      assert !pirate.changed?
      assert_equal [], pirate.changed
      assert_equal({}, pirate.changes)
    end

    example 'test_attribute_will_change!' do
      pirate = Pirate.create!(catchphrase: 'arr')

      assert !pirate.catchphrase_changed?
      assert pirate.catchphrase_will_change!
      assert pirate.catchphrase_changed?
      assert_equal %w[arr arr], pirate.catchphrase_change

      pirate.catchphrase << ' matey!'
      assert pirate.catchphrase_changed?
      assert_equal ['arr', 'arr matey!'], pirate.catchphrase_change
    end

    example 'test_association_assignment_changes_foreign_key' do
      pirate = Pirate.create!(catchphrase: 'jarl')
      pirate.parrot = Parrot.create!(name: 'Lorre')
      assert pirate.changed?
      assert_equal %w[parrot_id], pirate.changed
    end

    example 'test_attribute_should_be_compared_with_type_cast' do
      topic = Topic.new
      assert topic.approved?
      assert !topic.approved_changed?

      # Coming from web form.
      params = { topic: { approved: 1 } }
      # In the controller.
      topic.attributes = params[:topic]
      assert topic.approved?
      assert !topic.approved_changed?
    end

    example 'test_partial_update' do
      pirate = Pirate.new(catchphrase: 'foo')
      old_updated_on = 1.hour.ago.beginning_of_day

      with_partial_writes Pirate, false do
        assert_queries(2) { 2.times { pirate.save! } }
        Pirate.where(id: pirate.id).update_all(updated_on: old_updated_on)
      end

      with_partial_writes Pirate, true do
        assert_queries(0) { 2.times { pirate.save! } }
        assert_equal old_updated_on, pirate.reload.updated_on

        assert_queries(1) { pirate.catchphrase = 'bar'; pirate.save! }
        assert_not_equal old_updated_on, pirate.reload.updated_on
      end
    end

    example 'test_partial_update_with_optimistic_locking' do
      person = Person.new(first_name: 'foo')
      old_lock_version = 1

      with_partial_writes Person, false do
        assert_queries(2) { 2.times { person.save! } }
        Person.where(id: person.id).update_all(first_name: 'baz')
      end

      with_partial_writes Person, true do
        assert_queries(0) { 2.times { person.save! } }
        assert_equal old_lock_version, person.reload.lock_version

        assert_queries(1) { person.first_name = 'bar'; person.save! }
        assert_not_equal old_lock_version, person.reload.lock_version
      end
    end

    example 'test_changed_attributes_should_be_preserved_if_save_failure' do
      pirate = Pirate.new
      pirate.parrot_id = 1
      assert !pirate.save
      check_pirate_after_save_failure(pirate)

      pirate = Pirate.new
      pirate.parrot_id = 1
      assert_raise(ActiveRecord::RecordInvalid) { pirate.save! }
      check_pirate_after_save_failure(pirate)
    end

    example 'test_reload_should_clear_changed_attributes' do
      pirate = Pirate.create!(catchphrase: 'shiver me timbers')
      pirate.catchphrase = '*hic*'
      assert pirate.changed?
      pirate.reload
      assert !pirate.changed?
    end

    example 'test_dup_objects_should_not_copy_dirty_flag_from_creator' do
      pirate = Pirate.create!(catchphrase: 'shiver me timbers')
      pirate_dup = pirate.dup
      pirate_dup.restore_catchphrase!
      pirate.catchphrase = 'I love Rum'
      assert pirate.catchphrase_changed?
      assert !pirate_dup.catchphrase_changed?
    end

    example 'test_reverted_changes_are_not_dirty' do
      phrase = 'shiver me timbers'
      pirate = Pirate.create!(catchphrase: phrase)
      pirate.catchphrase = '*hic*'
      assert pirate.changed?
      pirate.catchphrase = phrase
      assert !pirate.changed?
    end

    example 'test_reverted_changes_are_not_dirty_after_multiple_changes' do
      phrase = 'shiver me timbers'
      pirate = Pirate.create!(catchphrase: phrase)
      10.times do |i|
        pirate.catchphrase = '*hic*' * i
        assert pirate.changed?
      end
      assert pirate.changed?
      pirate.catchphrase = phrase
      assert !pirate.changed?
    end

    example 'test_reverted_changes_are_not_dirty_going_from_nil_to_value_and_back' do
      pirate = Pirate.create!(catchphrase: 'Yar!')

      pirate.parrot_id = 1
      assert pirate.changed?
      assert pirate.parrot_id_changed?
      assert !pirate.catchphrase_changed?

      pirate.parrot_id = nil
      assert !pirate.changed?
      assert !pirate.parrot_id_changed?
      assert !pirate.catchphrase_changed?
    end

    example 'test_save_should_store_serialized_attributes_even_with_partial_writes' do
      with_partial_writes(Topic) do
        topic = Topic.create!(content: { a: 'a' })

        assert_not topic.changed?

        topic.content[:b] = 'b'

        assert topic.changed?

        topic.save!

        assert_not topic.changed?
        assert_equal 'b', topic.content[:b]

        topic.reload

        assert_equal 'b', topic.content[:b]
      end
    end

    example 'test_save_always_should_update_timestamps_when_serialized_attributes_are_present' do
      with_partial_writes(Topic) do
        topic = Topic.create!(content: { a: 'a' })
        topic.save!

        updated_at = topic.updated_at
        travel(1.second) do
          topic.content[:hello] = 'world'
          topic.save!
        end

        assert_not_equal updated_at, topic.updated_at
        assert_equal 'world', topic.content[:hello]
      end
    end

    example 'test_save_should_not_save_serialized_attribute_with_partial_writes_if_not_present' do
      with_partial_writes(Topic) do
        Topic.create!(author_name: 'Bill', content: { a: 'a' })
        topic = Topic.select('id, author_name').first
        topic.update_columns author_name: 'John'
        topic = Topic.first
        assert_not_nil topic.content
      end
    end

    example 'test_previous_changes' do
      # original values should be in previous_changes
      pirate = Pirate.new

      assert_equal({}, pirate.previous_changes)
      pirate.catchphrase = 'arrr'
      pirate.save!

      assert_equal 4, pirate.previous_changes.size
      assert_equal [nil, 'arrr'], pirate.previous_changes['catchphrase']
      assert_equal [nil, pirate.id], pirate.previous_changes['id']
      assert_nil pirate.previous_changes['updated_on'][0]
      assert_not_nil pirate.previous_changes['updated_on'][1]
      assert_nil pirate.previous_changes['created_on'][0]
      assert_not_nil pirate.previous_changes['created_on'][1]
      assert !pirate.previous_changes.key?('parrot_id')

      # original values should be in previous_changes
      pirate = Pirate.new

      assert_equal({}, pirate.previous_changes)
      pirate.catchphrase = 'arrr'
      pirate.save

      assert_equal 4, pirate.previous_changes.size
      assert_equal [nil, 'arrr'], pirate.previous_changes['catchphrase']
      assert_equal [nil, pirate.id], pirate.previous_changes['id']
      assert pirate.previous_changes.include?('updated_on')
      assert pirate.previous_changes.include?('created_on')
      assert !pirate.previous_changes.key?('parrot_id')

      pirate.catchphrase = 'Yar!!'
      pirate.reload
      assert_equal({}, pirate.previous_changes)

      pirate = Pirate.find_by_catchphrase('arrr')

      travel(1.second)

      pirate.catchphrase = 'Me Maties!'
      pirate.save!

      assert_equal 2, pirate.previous_changes.size
      assert_equal ['arrr', 'Me Maties!'], pirate.previous_changes['catchphrase']
      assert_not_nil pirate.previous_changes['updated_on'][0]
      assert_not_nil pirate.previous_changes['updated_on'][1]
      assert !pirate.previous_changes.key?('parrot_id')
      assert !pirate.previous_changes.key?('created_on')

      pirate = Pirate.find_by_catchphrase('Me Maties!')

      travel(1.second)

      pirate.catchphrase = 'Thar She Blows!'
      pirate.save

      assert_equal 2, pirate.previous_changes.size
      assert_equal ['Me Maties!', 'Thar She Blows!'], pirate.previous_changes['catchphrase']
      assert_not_nil pirate.previous_changes['updated_on'][0]
      assert_not_nil pirate.previous_changes['updated_on'][1]
      assert !pirate.previous_changes.key?('parrot_id')
      assert !pirate.previous_changes.key?('created_on')

      travel(1.second)

      pirate = Pirate.find_by_catchphrase('Thar She Blows!')
      pirate.update(catchphrase: 'Ahoy!')

      assert_equal 2, pirate.previous_changes.size
      assert_equal ['Thar She Blows!', 'Ahoy!'], pirate.previous_changes['catchphrase']
      assert_not_nil pirate.previous_changes['updated_on'][0]
      assert_not_nil pirate.previous_changes['updated_on'][1]
      assert !pirate.previous_changes.key?('parrot_id')
      assert !pirate.previous_changes.key?('created_on')

      travel(1.second)

      pirate = Pirate.find_by_catchphrase('Ahoy!')
      pirate.update_attribute(:catchphrase, 'Ninjas suck!')

      assert_equal 2, pirate.previous_changes.size
      assert_equal ['Ahoy!', 'Ninjas suck!'], pirate.previous_changes['catchphrase']
      assert_not_nil pirate.previous_changes['updated_on'][0]
      assert_not_nil pirate.previous_changes['updated_on'][1]
      assert !pirate.previous_changes.key?('parrot_id')
      assert !pirate.previous_changes.key?('created_on')
    ensure
      travel_back
    end

    if ActiveRecord::Base.connection.supports_migrations?
      class Testings < ActiveRecord::Base; end
      def test_field_named_field
        ActiveRecord::Base.connection.create_table :testings do |t|
          t.string :field
        end
        assert_nothing_raised do
          Testings.new.attributes
        end
      ensure
        begin
        ActiveRecord::Base.connection.drop_table :testings
      rescue StandardError
        nil
      end
      end
    end

    example 'test_datetime_attribute_can_be_updated_with_fractional_seconds' do
      skip 'Fractional seconds are not supported' unless subsecond_precision_supported?
      in_time_zone 'Paris' do
        target = Class.new(ActiveRecord::Base)
        target.table_name = 'topics'

        written_on = Time.utc(2012, 12, 1, 12, 0, 0).in_time_zone('Paris')

        topic = target.create(written_on: written_on)
        topic.written_on += 0.3

        assert topic.written_on_changed?, 'Fractional second update not detected'
      end
    end

    example 'test_datetime_attribute_doesnt_change_if_zone_is_modified_in_string' do
      time_in_paris = Time.utc(2014, 1, 1, 12, 0, 0).in_time_zone('Paris')
      pirate = Pirate.create!(catchphrase: 'rrrr', created_on: time_in_paris)

      pirate.created_on = pirate.created_on.in_time_zone('Tokyo').to_s
      assert !pirate.created_on_changed?
    end

    example 'partial insert' do
      with_partial_writes Person do
        jon = nil
        assert_sql(/first_name/i) do
          jon = Person.create! first_name: 'Jon'
        end

        assert ActiveRecord::SQLCounter.log_all.none? { |sql| sql =~ /followers_count/ }

        jon.reload
        assert_equal 'Jon', jon.first_name
        assert_equal 0, jon.followers_count
        assert_not_nil jon.id
      end
    end

    example 'partial insert with empty values' do
      with_partial_writes Aircraft do
        a = Aircraft.create!
        a.reload
        assert_not_nil a.id
      end
    end

    example 'in place mutation detection' do
      pirate = Pirate.create!(catchphrase: 'arrrr')
      pirate.catchphrase << ' matey!'

      assert pirate.catchphrase_changed?
      expected_changes = {
        'catchphrase' => ['arrrr', 'arrrr matey!']
      }
      assert_equal(expected_changes, pirate.changes)
      assert_equal('arrrr', pirate.catchphrase_was)
      assert pirate.catchphrase_changed?(from: 'arrrr')
      assert_not pirate.catchphrase_changed?(from: 'anything else')
      assert pirate.changed_attributes.include?(:catchphrase)

      pirate.save!
      pirate.reload

      assert_equal 'arrrr matey!', pirate.catchphrase
      assert_not pirate.changed?
    end

    example 'in place mutation for binary' do
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = :binaries
        serialize :data
      end

      binary = klass.create!(data: '\\\\foo')

      assert_not binary.changed?

      binary.data = binary.data.dup

      assert_not binary.changed?

      binary = klass.last

      assert_not binary.changed?

      binary.data << 'bar'

      assert binary.changed?
    end

    example "attribute_changed? doesn't compute in-place changes for unrelated attributes" do
      test_type_class = Class.new(ActiveRecord::Type::Value) do
        define_method(:changed_in_place?) do |*|
          raise
        end
      end
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = 'people'
        attribute :foo, test_type_class.new
      end

      model = klass.new(first_name: 'Jim')
      assert model.first_name_changed?
    end

    example "attribute_will_change! doesn't try to save non-persistable attributes" do
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = 'people'
        attribute :non_persisted_attribute, :string
      end

      record = klass.new(first_name: 'Sean')
      record.non_persisted_attribute_will_change!

      assert record.non_persisted_attribute_changed?
      assert record.save
    end

    example "mutating and then assigning doesn't remove the change" do
      pirate = Pirate.create!(catchphrase: 'arrrr')
      pirate.catchphrase << ' matey!'
      pirate.catchphrase = 'arrrr matey!'

      assert pirate.catchphrase_changed?(from: 'arrrr', to: 'arrrr matey!')
    end

    example 'getters with side effects are allowed' do
      klass = Class.new(Pirate) do
        def catchphrase
          if super.blank?
            update_attribute(:catchphrase, 'arr') # what could possibly go wrong?
          end
          super
        end
      end

      pirate = klass.create!(catchphrase: 'lol')
      pirate.update_attribute(:catchphrase, nil)

      assert_equal 'arr', pirate.catchphrase
    end

    example 'attributes assigned but not selected are dirty' do
      person = Person.select(:id).first
      refute person.changed?

      person.first_name = 'Sean'
      assert person.changed?

      person.first_name = nil
      assert person.changed?
    end

    private

    def with_partial_writes(klass, on = true)
      old = klass.partial_writes?
      klass.partial_writes = on
      yield
    ensure
      klass.partial_writes = old
    end

    def check_pirate_after_save_failure(pirate)
      assert pirate.changed?
      assert pirate.parrot_id_changed?
      assert_equal %w[parrot_id], pirate.changed
      assert_nil pirate.parrot_id_was
    end
  end
end
# rubocop:enable all
