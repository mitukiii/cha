# coding: utf-8

require 'cha/error'
require 'multi_json'
require 'faraday'
require 'faraday_middleware'

module Cha
  module Middleware
    class ChatWorkAuthentication < Faraday::Middleware
      KEY = 'X-ChatWorkToken'

      def initialize(app, token)
        @token = token
        super(app)
      end

      def call(env)
        if @token
          env[:request_headers][KEY] ||= @token
        end
        @app.call(env)
      end
    end

    class ParseJson < Faraday::Response::Middleware
      def parse(body)
        MultiJson.load(body) unless body.nil?
      end
    end

    class RaiseError < Faraday::Response::Middleware
      def on_complete(env)
        case env[:status].to_i
        when 400
          raise BadRequest, error_message(env)
        when 401
          raise NotAuthorized, error_message(env)
        when 403
          raise Forbidden, error_message(env)
        when 404
          raise NotFound, error_message(env)
        when 400...500
          raise ClientError, error_message(env)
        when 500
          raise InternalServerError, error_message(env)
        when 501
          raise NotImplemented, error_message(env)
        when 503
          raise ServiceUnavailable, error_message(env)
        when 500...600
          raise ServerError, error_message(env)
        end
      end

      private

      def error_message(env)
        body = env[:body]
        if body.nil?
          nil
        elsif body['errors']
          body['errors'].join(', ')
        end
      end
    end

    Faraday.register_middleware :request, chat_work: ->{ ChatWorkAuthentication }
    Faraday.register_middleware :response, json: ->{ ParseJson }
    Faraday.register_middleware :response, raise_error: ->{ RaiseError }
  end
end