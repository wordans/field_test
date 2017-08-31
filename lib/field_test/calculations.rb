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

    def self.level_prob_1_beats_2(alpha_1, beta_1, alpha_2, beta_2)
      total = 0.0

      # for performance

      log_beta_1 = Math.log(beta_1)
      log_beta_2 = Math.log(beta_2)
      log_beta_1_plus_beta_2 = Math.log(beta_1 + beta_2)
      alpha_2_times_log_beta_2 = alpha_2 * log_beta_2

      0.upto(alpha_1 - 1) do |i|
        # Possible problem here
        total += Math.exp(i * log_beta_1 + alpha_2_times_log_beta_2 - (i + alpha_2) * log_beta_1_plus_beta_2 - Math.log(i + alpha_2) - Math.logbeta(i + 1, alpha_2))
      end

      total
    end

    def self.level_prob_1_beats_2_and_3(alpha_1, beta_1, alpha_2, beta_2, alpha_3, beta_3)
      total = 0.0

      # for performance
      log_beta_3 = Math.log(beta_3)
      log_beta_2 = Math.log(beta_2)
      log_beta_1 = Math.log(beta_1)
      alpha_1_times_log_beta_1 = alpha_1 * log_beta_1
      log_beta_1_plus_beta_2_plus_beta_3 = Math.log(beta_1 + beta_2 + beta_3)
      lgamma_alpha_1 = Math.lgamma(alpha_1).reduce(:*)
      0.upto(alpha_2 - 1) do |i|
        alpha_1_plus_i = alpha_1 + i
        lgamma_of_i_plus_1 = Math.lgamma(i + 1).reduce(:*)
        i_times_log_beta_2 = i * log_beta_2
        0.upto(alpha_3 - 1) do |j|
          total += Math.exp(alpha_1_times_log_beta_1 + i_times_log_beta_2 + j * log_beta_3 - (j + alpha_1_plus_i) * log_beta_1_plus_beta_2_plus_beta_3 + Math.lgamma(j + alpha_1_plus_i).reduce(:*) - lgamma_of_i_plus_1 - Math.log(Math.gamma(j + 1)) - lgamma_alpha_1)
        end
      end
      1 - level_prob_1_beats_2(alpha_2, beta_2, alpha_1, beta_1) -
        level_prob_1_beats_2(alpha_3, beta_3, alpha_1, beta_1) + total
    end
  end
end
