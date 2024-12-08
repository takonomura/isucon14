# frozen_string_literal: true

require 'mysql2'
require 'mysql2-cs-bind'
require 'sinatra/base'
require 'sinatra/cookies'
require 'sinatra/json'

# mysql2-cs-bind gem にマイクロ秒のサポートを入れる
module Mysql2CsBindPatch
  def quote(rawvalue)
    if rawvalue.respond_to?(:strftime)
      "'#{rawvalue.strftime('%Y-%m-%d %H:%M:%S.%6N')}'"
    else
      super
    end
  end
end
Mysql2::Client.singleton_class.prepend(Mysql2CsBindPatch)

module Isuride
  class BaseHandler < Sinatra::Base
    INITIAL_FARE = 500
    FARE_PER_DISTANCE = 100

    enable :logging
    set :show_exceptions, :after_handler

    class HttpError < Sinatra::Error
      attr_reader :code

      def initialize(code, message)
        super(message || "HTTP error #{code}")
        @code = code
      end
    end
    error HttpError do
      e = env['sinatra.error']
      status e.code
      json(message: e.message)
    end

    helpers Sinatra::Cookies

    helpers do
      def bind_json(data_class)
        body = JSON.parse(request.body.tap(&:rewind).read, symbolize_names: true)
        data_class.new(**data_class.members.map { |key| [key, body[key]] }.to_h)
      end

      def db
        Thread.current[:db] ||= connect_db
      end

      def connect_db
        Mysql2::Client.new(
          host: ENV.fetch('ISUCON_DB_HOST', '127.0.0.1'),
          port: ENV.fetch('ISUCON_DB_PORT', '3306').to_i,
          username: ENV.fetch('ISUCON_DB_USER', 'isucon'),
          password: ENV.fetch('ISUCON_DB_PASSWORD', 'isucon'),
          database: ENV.fetch('ISUCON_DB_NAME', 'isuride'),
          symbolize_keys: true,
          cast_booleans: true,
          database_timezone: :utc,
          application_timezone: :utc,
        )
      end

      def db_transaction(&block)
        db.query('BEGIN')
        ok = false
        begin
          retval = block.call(db)
          db.query('COMMIT')
          ok = true
          retval
        ensure
          unless ok
            db.query('ROLLBACK')
          end
        end
      end

      def time_msec(time)
        time.to_i*1000 + time.usec/1000
      end

      def get_latest_ride_status(tx, ride_id)
        tx.xquery('SELECT status FROM ride_statuses WHERE ride_id = ? ORDER BY created_at DESC LIMIT 1', ride_id).first.fetch(:status)
      end

      # マンハッタン距離を求める
      def calculate_distance(a_latitude, a_longitude, b_latitude, b_longitude)
        (a_latitude - b_latitude).abs + (a_longitude - b_longitude).abs
      end

      def calculate_fare(pickup_latitude, pickup_longitude, dest_latitude, dest_longitude)
        metered_fare = FARE_PER_DISTANCE * calculate_distance(pickup_latitude, pickup_longitude, dest_latitude, dest_longitude)
        INITIAL_FARE + metered_fare
      end
    end
  end
end
