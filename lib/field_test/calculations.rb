require "distribution/math_extension"

# formulas from
# http://www.evanmiller.org/bayesian-ab-testing.html
module FieldTest
  module Calculations
    def self.prob_b_beats_a(alpha_a, beta_a, alpha_b, beta_b)
      total = 0.0

      # for performance
      logbeta_aa_ba = Math.logbeta(alpha_a, beta_a)
      beta_ba = beta_b + beta_a

      0.upto(alpha_b - 1) do |i|
        total += Math.exp(Math.logbeta(alpha_a + i, beta_ba) -
          Math.log(beta_b + i) - Math.logbeta(1 + i, beta_b) -
          logbeta_aa_ba)
      end

      total
    end

    def self.prob_c_beats_a_and_b(alpha_a, beta_a, alpha_b, beta_b, alpha_c, beta_c)
      total = 0.0

      # for performance
      logbeta_ac_bc = Math.logbeta(alpha_c, beta_c)
      abc = beta_a + beta_b + beta_c
      log_bb_j = []
      logbeta_j_bb = []
      logbeta_ac_i_j = []
      0.upto(alpha_b - 1) do |j|
        log_bb_j[j] = Math.log(beta_b + j)
        logbeta_j_bb[j] = Math.logbeta(1 + j, beta_b)

        0.upto(alpha_a - 1) do |i|
          logbeta_ac_i_j[i + j] ||= Math.logbeta(alpha_c + i + j, abc)
        end
      end

      0.upto(alpha_a - 1) do |i|
        # for performance
        log_ba_i = Math.log(beta_a + i)
        logbeta_i_ba = Math.logbeta(1 + i, beta_a)

        0.upto(alpha_b - 1) do |j|
          total += Math.exp(logbeta_ac_i_j[i + j] -
            log_ba_i - log_bb_j[j] -
            logbeta_i_ba - logbeta_j_bb[j] -
            logbeta_ac_bc)
        end
      end

      1 - prob_b_beats_a(alpha_c, beta_c, alpha_a, beta_a) -
        prob_b_beats_a(alpha_c, beta_c, alpha_b, beta_b) + total
    end





    def self.level_prob_b_beats_a(alpha_a, beta_a, alpha_b, beta_b)
      total = 0.0
      binding.pry

      # for performance

      log_ba = Math.log(beta_a)
      log_bb = Math.log(beta_b)
      log_ba_plus_bb = Math.log(beta_a + beta_b)
      alpha_a_time_log_bb = alpha_a * log_bb

      0.upto(alpha_b - 1) do |i|
        total += Math.exp(i * log_ba + alpha_a_time_log_bb - (i + alpha_b) * log_ba_plus_bb - Math.log(i + alpha_b) -Math.logbeta(i + 1, alpha_b))
      end

      total
    end

    def self.level_prob_c_beats_a_and_b(alpha_a, beta_a, alpha_b, beta_b, alpha_c, beta_c)
      total = 0.0

      # for performance
      log_ba = Math.log(beta_a)
      log_bc = Math.log(beta_c)
      alpha_a_time_log_bb = alpha_a * log_ba
      log_ba_plus_bb_plus_bc = Math.log(beta_a + beta_b + beta_c)
      lgamma_aa = Math.log(Math.gamma(alpha_a))

      0.upto(alpha_a - 1) do |i|
        alpha_a_plus_i = alpha_a + i
        lgamma_of_i_plus_1 = Math.log(Math.gamma(i + 1))
        0.upto(alpha_a - 1) do |j|
          total += Mat.exp(alpha_a_time_log_bb + j * log_bc + (j + alpha_a_plus_i) * log_ba_plus_bb_plus_bc + Math.log(Math.gamma(j + alpha_a_plus_i)) - lgamma_of_i_plus_1 - Math.log(Math.gamma(j + 1)) - lgamma_aa)
        end
      end

      1 - level_prob_b_beats_a(alpha_c, beta_c, alpha_a, beta_a) -
        level_prob_b_beats_a(alpha_c, beta_c, alpha_b, beta_b) + total
    end
  end
end
