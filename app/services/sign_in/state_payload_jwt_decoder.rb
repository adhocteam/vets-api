# frozen_string_literal: true

module SignIn
  class StatePayloadJwtDecoder
    attr_reader :state_payload_jwt

    def initialize(state_payload_jwt:)
      @state_payload_jwt = state_payload_jwt
    end

    def perform
      decoded_jwt = jwt_decode_state_payload
      SignIn::StatePayload.new(
        acr: decoded_jwt.acr,
        client_id: decoded_jwt.client_id,
        type: decoded_jwt.type,
        code_challenge: decoded_jwt.code_challenge,
        client_state: decoded_jwt.client_state
      )
    end

    private

    def jwt_decode_state_payload
      with_validation = true
      decoded_jwt = JWT.decode(
        state_payload_jwt,
        private_key,
        with_validation,
        {
          algorithm: Constants::Auth::JWT_ENCODE_ALGORITHM
        }
      )&.first
      OpenStruct.new(decoded_jwt)
    rescue JWT::VerificationError
      raise SignIn::Errors::StatePayloadSignatureMismatchError, 'State JWT body does not match signature'
    rescue JWT::DecodeError
      raise SignIn::Errors::StatePayloadMalformedJWTError, 'State JWT is malformed'
    end

    def private_key
      OpenSSL::PKey::RSA.new(File.read(Settings.sign_in.jwt_encode_key))
    end
  end
end
