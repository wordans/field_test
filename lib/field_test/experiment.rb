module FieldTest
  class Experiment
    attr_reader :id, :name, :description, :variants, :weights, :winner, :started_at, :ended_at, :goals

    def initialize(attributes)
      attributes = attributes.symbolize_keys
      @id = attributes[:id]
      @name = attributes[:name] || @id.to_s.titleize
      @description = attributes[:description]
      @variants = attributes[:variants]
      @weights = @variants.size.times.map { |i| attributes[:weights].to_a[i] || 1 }
      @winner = attributes[:winner]
      @started_at = Time.zone.parse(attributes[:started_at].to_s) if attributes[:started_at]
      @ended_at = Time.zone.parse(attributes[:ended_at].to_s) if attributes[:ended_at]
      @goals = attributes[:goals] || ["conversion"]
      @use_events = attributes[:use_events]
    end

    def variant(participants, options = {})
      return winner if winner
      return variants.first if options[:exclude]

      participants = FieldTest::Participant.standardize(participants)
      check_participants(participants)
      membership = membership_for(participants) || FieldTest::Membership.new(experiment: id)

      if options[:variant] && variants.include?(options[:variant])
        membership.variant = options[:variant]
      else
        membership.variant ||= weighted_variant
      end

      # upgrade to preferred participant
      membership.participant = participants.first

      if membership.changed?
        begin
          membership.save!

          # log it!
          info = {
            experiment: id,
            variant: membership.variant,
            participant: membership.participant
          }.merge(options.slice(:ip, :user_agent))

          # sorta logfmt :)
          info = info.map { |k, v| v = "\"#{v}\"" if k == :user_agent; "#{k}=#{v}" }.join(" ")
          Rails.logger.info "[field test] #{info}"
        rescue ActiveRecord::RecordNotUnique
          membership = memberships.find_by(participant: participants.first)
        end
      end

      membership.try(:variant) || variants.first
    end

    def convert(participants, goal: nil, value: nil)
      goal ||= goals.first

      participants = FieldTest::Participant.standardize(participants)
      check_participants(participants)
      membership = membership_for(participants)

      if membership
        if membership.respond_to?(:converted)
          membership.converted = true
          membership.value = value unless value.blank?
          membership.save! if membership.changed?
        end

        if use_events?
          FieldTest::Event.create!(
            name: goal,
            field_test_membership_id: membership.id
          )
        end

        true
      else
        false
      end
    end

    def memberships
      FieldTest::Membership.where(experiment: id)
    end

    def events
      FieldTest::Event.joins(:field_test_membership).where(field_test_memberships: {experiment: id})
    end

    def multiple_goals?
      goals.size > 1
    end

    def results(goal: nil)
      goal ||= goals.first

      relation = memberships.group(:variant)
      relation = relation.where("created_at >= ?", started_at) if started_at
      relation = relation.where("created_at <= ?", ended_at) if ended_at

      if use_events?
        data = {}
        sql = relation.joins("LEFT JOIN field_test_events ON field_test_events.field_test_membership_id = field_test_memberships.id").select("variant, COUNT(DISTINCT participant) AS participated, COUNT(DISTINCT field_test_membership_id) AS converted").where(field_test_events: {name: goal})

        FieldTest::Membership.connection.select_all(sql).each do |row|
          data[[row["variant"], true]] = row["converted"].to_i
          data[[row["variant"], false]] = row["participated"].to_i - row["converted"].to_i
        end
      else
        data = relation.group(:converted).count
        value_data = relation.group(:converted).average(:value)
      end

      results = {}
      variants.each do |variant|
        converted = data[[variant, true]].to_i
        participated = converted + data[[variant, false]].to_i

        participated > 0 ? conversion_rate = converted.to_f / participated : conversion_rate = nil

        (converted > 0 && !value_data[[variant, true]].nil?) ? average_conversion_value = value_data[[variant, true]].to_f : average_conversion_value = nil

        (participated > 0 && !average_conversion_value.nil?) ? conversion_value = conversion_rate * average_conversion_value : conversion_value = nil

        results[variant] = {
          participated: participated,
          converted: converted,
          conversion_rate: conversion_rate,
          average_conversion_value: average_conversion_value,
          conversion_value: conversion_value
        }

      end
      case variants.size
      when 1, 2, 3
        total = 0.0

        (variants.size - 1).times do |i|
          c = results.values[i]
          b = results.values[(i + 1) % variants.size]
          a = results.values[(i + 2) % variants.size]

          alpha_a = 1 + a[:converted]
          beta_a = 1 + a[:participated] - a[:converted]
          alpha_b = 1 + b[:converted]
          beta_b = 1 + b[:participated] - b[:converted]
          alpha_c = 1 + c[:converted]
          beta_c = 1 + c[:participated] - c[:converted]

          # TODO calculate this incrementally by caching intermediate results
          prob_winning =
            if variants.size == 2
              cache_fetch ["field_test", "prob_b_beats_a", alpha_b, beta_b, alpha_c, beta_c] do
                Calculations.prob_b_beats_a(alpha_b, beta_b, alpha_c, beta_c)
              end
            else
              cache_fetch ["field_test", "prob_c_beats_a_and_b", alpha_a, beta_a, alpha_b, beta_b, alpha_c, beta_c] do
                Calculations.prob_c_beats_a_and_b(alpha_a, beta_a, alpha_b, beta_b, alpha_c, beta_c)
              end
            end

          results[variants[i]][:prob_winning] = prob_winning
          total += prob_winning
        end

        results[variants.last][:prob_winning] = 1 - total
      end
      results
    end

    def level_results(goal: nil)
      goal ||= goals.first

      relation = memberships.group(:variant)
      relation = relation.where("created_at >= ?", started_at) if started_at
      relation = relation.where("created_at <= ?", ended_at) if ended_at

      if use_events?
        data = {}
        sql = relation.joins("LEFT JOIN field_test_events ON field_test_events.field_test_membership_id = field_test_memberships.id").select("variant, COUNT(DISTINCT participant) AS participated, COUNT(DISTINCT field_test_membership_id) AS converted").where(field_test_events: {name: goal})

        FieldTest::Membership.connection.select_all(sql).each do |row|
          data[[row["variant"], true]] = row["converted"].to_i
          data[[row["variant"], false]] = row["participated"].to_i - row["converted"].to_i
        end
      else
        data = relation.group(:converted).count
        value_data = relation.group(:converted).average(:value)
      end

      level_results = {}
      variants.each do |variant|
        converted = data[[variant, true]].to_i
        participated = converted + data[[variant, false]].to_i

        participated > 0 ? conversion_rate = converted.to_f / participated : conversion_rate = nil

        (converted > 0 && !value_data[[variant, true]].nil?) ? average_conversion_value = value_data[[variant, true]].to_f : average_conversion_value = nil

        (participated > 0 && !average_conversion_value.nil?) ? conversion_value = conversion_rate * average_conversion_value : conversion_value = nil

        level_results[variant] = {
          participated: participated,
          converted: converted,
          conversion_rate: conversion_rate,
          average_conversion_value: average_conversion_value,
          conversion_value: conversion_value
        }

      end

      case variants.size
      when 1, 2, 3

        total = 0.0

        # =======================================================

        (variants.size - 1).times do |i|
          c = level_results.values[i]
          b = level_results.values[(i + 1) % variants.size]
          a = level_results.values[(i + 2) % variants.size]

          a_weight = weights[(i + 2) % variants.size]/weights[0]
          b_weight = weights[(i + 1) % variants.size]/weights[0]
          c_weight = weights[i]/weights[0]

          # experiment_weights = weights.map{|weight| weight.to_f/weights[i]}
          beta_a =  a_weight
          beta_b =  b_weight
          beta_c = c_weight

          alpha_a = a[:participated]
          # beta_a =  experiment_weights[(i + 2) % variants.size]
          alpha_b = b[:participated]
          # beta_b =  experiment_weights[(i + 1) % variants.size]
          alpha_c = c[:participated]
          # beta_c = experiment_weights[i]



          # TODO calculate this incrementally by caching intermediate results
          prob_winning =
            if (alpha_a == 0 || alpha_b == 0 || alpha_c == 0)
              1 / variants.size.to_f
            elsif variants.size == 2
              cache_fetch ["field_test", "level_prob_b_beats_a", alpha_b, beta_b, alpha_c, beta_c] do
                Calculations.level_prob_b_beats_a(alpha_b, beta_b, alpha_c, beta_c)
              end
            else
              cache_fetch ["field_test", "level_prob_c_beats_a_and_b", alpha_a, beta_a, alpha_b, beta_b, alpha_c, beta_c] do
                Calculations.level_prob_c_beats_a_and_b(alpha_a, beta_a, alpha_b, beta_b, alpha_c, beta_c)
              end
            end

          level_results[variants[i]][:prob_winning] = prob_winning
          total += prob_winning
        end

        level_results[variants.last][:prob_winning] = 1 - total
      end
      level_results

    # =======================================================

    end

    def level_results_number(goal: nil)
      goal ||= goals.first

      relation = memberships.group(:variant)
      relation = relation.where("created_at >= ?", started_at) if started_at
      relation = relation.where("created_at <= ?", ended_at) if ended_at

      if use_events?
        data = {}
        sql = relation.joins("LEFT JOIN field_test_events ON field_test_events.field_test_membership_id = field_test_memberships.id").select("variant, COUNT(DISTINCT participant) AS participated, COUNT(DISTINCT field_test_membership_id) AS converted").where(field_test_events: {name: goal})

        FieldTest::Membership.connection.select_all(sql).each do |row|
          data[[row["variant"], true]] = row["converted"].to_i
          data[[row["variant"], false]] = row["participated"].to_i - row["converted"].to_i
        end
      else
        data = relation.group(:converted).count
        value_data = relation.group(:converted).average(:value)
      end

      level_results = {}
      variants.each do |variant|
        converted = data[[variant, true]].to_i
        participated = converted + data[[variant, false]].to_i

        participated > 0 ? conversion_rate = converted.to_f / participated : conversion_rate = nil

        (converted > 0 && !value_data[[variant, true]].nil?) ? average_conversion_value = value_data[[variant, true]].to_f : average_conversion_value = nil

        (participated > 0 && !average_conversion_value.nil?) ? conversion_value = conversion_rate * average_conversion_value : conversion_value = nil

        level_results[variant] = {
          participated: participated,
          converted: converted,
          conversion_rate: conversion_rate,
          average_conversion_value: average_conversion_value,
          conversion_value: conversion_value
        }

      end

      case variants.size
      when 1, 2, 3

        total = 0.0

        (variants.size - 1).times do |i|
          binding.pry
          a = level_results.values[i]
          b = level_results.values[(i + 1) % variants.size]
          c = level_results.values[(i + 2) % variants.size]

          a_weight = weights[i]/(weights.sum-weights[i]).to_f
          b_weight = weights[(i + 1) % variants.size]/(weights.sum-weights[i]).to_f
          c_weight = weights[(i + 2) % variants.size]/(weights.sum-weights[i]).to_f

          beta_1 =  a_weight
          beta_2 =  b_weight
          beta_3 = c_weight

          # alpha_1 = a[:participated]
          # alpha_2 = b[:participated]
          # alpha_3 = c[:participated]

          # ========================

          alpha_1 = a[:conversion_value]
          alpha_2 = b[:conversion_value]
          alpha_3 = c[:conversion_value]

          # TODO calculate this incrementally by caching intermediate results
          prob_winning =
            if (alpha_1.blank? || alpha_2.blank? || alpha_3.blank?) || (alpha_1 == 0 || alpha_2 == 0 || alpha_3 == 0)
              nil
            elsif variants.size == 2
              cache_fetch ["field_test", "level_prob_1_beats_2", alpha_1, beta_1, alpha_2, beta_2] do
                Calculations.level_prob_1_beats_2(alpha_1, beta_1, alpha_2, beta_2)
              end
            else
              cache_fetch ["field_test", "level_prob_1_beats_2_and_3", alpha_1, beta_1, alpha_2, beta_2, alpha_3, beta_3] do
                Calculations.level_prob_1_beats_2_and_3(alpha_1, beta_1, alpha_2, beta_2, alpha_3, beta_3)
              end
            end
          level_results[variants[i]][:prob_winning] = prob_winning
          binding.pry
          total += prob_winning unless (alpha_1.blank? || alpha_2.blank? || alpha_3.blank?) || (alpha_1 == 0 || alpha_2 == 0 || alpha_3 == 0)
        end

        if level_results.values.map{|h| h[:prob_winning]}[0..(variants.size-2)].uniq.include?(nil)
          level_results[variants.last][:prob_winning] = nil
        else
          level_results[variants.last][:prob_winning] = 1 - total
        end
      end
      level_results
    end

    def active?
      !winner
    end

    def use_events?
      if @use_events.nil?
        FieldTest.events_supported?
      else
        @use_events
      end
    end

    def self.find(id)
      experiment = all.index_by(&:id)[id.to_s]
      raise FieldTest::ExperimentNotFound unless experiment

      experiment
    end

    def self.all
      FieldTest.config["experiments"].map do |id, settings|
        FieldTest::Experiment.new(settings.merge(id: id.to_s))
      end
    end

    private

      def check_participants(participants)
        raise FieldTest::UnknownParticipant, "Use the :participant option to specify a participant" if participants.empty?
      end

      def membership_for(participants)
        memberships = self.memberships.where(participant: participants).index_by(&:participant)
        participants.map { |part| memberships[part] }.compact.first
      end

      def weighted_variant
        total = weights.sum.to_f
        pick = rand
        n = 0
        weights.map { |w| w / total }.each_with_index do |w, i|
          n += w
          return variants[i] if n >= pick
        end
        variants.last
      end

      def cache_fetch(key)
        if FieldTest.cache
          Rails.cache.fetch(key.join("/")) { yield }
        else
          yield
        end
      end
  end
end
