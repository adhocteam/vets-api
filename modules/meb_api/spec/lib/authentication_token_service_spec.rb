# frozen_string_literal: true

require 'rails_helper'

require_dependency 'authentication_token_service'

Rspec.describe MebApi::AuthenticationTokenService do
  describe '.call' do
    let(:token) { described_class.call }

    it 'returns an authentication token' do
      decoded_token = JWT.decode(token,
                                 described_class::RSA_PUBLIC,
                                 true,
                                 { algorithm: described_class::ALGORITHM_TYPE })

      expect(decoded_token).to eq(
        [{
          'iat' => Time.now.to_i,
          'exp' => Time.now.to_i + (5 * 60)
        },
         { 'alg' => 'RS256' }]
      )
    end
  end
end
