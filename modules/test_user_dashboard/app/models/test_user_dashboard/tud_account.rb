# frozen_string_literal: true

module TestUserDashboard
  class TudAccount < ApplicationRecord
    self.ignored_columns = %w[standard available account_type id_type]

    ID_PROVIDERS = %w[idme dslogon mhv logingov].freeze

    validates :first_name, :last_name, :email, :id_types, presence: true
    validates :email, uniqueness: true
    validate :valid_id_types

    serialize :services

    def available?
      checkout_time.nil?
    end

    def user_identity
      unless (identity = UserIdentity.find(account_uuid))
        identity = UserIdentity.create(
          uuid: account_uuid,
          email: email,
          first_name: first_name,
          last_name: last_name,
          gender: gender,
          birth_date: birth_date.to_s(:iso_8601),
          ssn: ssn,
          loa: { lowest: 1, highest: 3 }
        )
      end
      identity
    end

    def mpi_profile
      MPI::Service.new.find_profile(user_identity).profile
    end

    def profile
      Users::Profile.new(user).pre_serialize
    end

    def user
      # ensure we have a user identity before instantiating
      user_identity
      User.new(uuid: user_identity.uuid)
    end

    private

    def valid_id_types
      errors.add(:id_types, 'id_type is invalid') if id_types.detect { |type| !ID_PROVIDERS.include?(type) }
    end
  end
end
