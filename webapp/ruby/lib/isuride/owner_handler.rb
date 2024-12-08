# frozen_string_literal: true

require 'ulid'

require 'isuride/base_handler'

module Isuride
  class OwnerHandler < BaseHandler
    CurrentOwner = Data.define(
      :id,
      :name,
      :access_token,
      :chair_register_token,
      :created_at,
      :updated_at,
    )

    before do
      if request.path == '/api/owner/owners'
        next
      end

      access_token = cookies[:owner_session]
      if access_token.nil?
        raise HttpError.new(401, 'owner_session cookie is required')
      end
      owner = db.xquery('SELECT * FROM owners WHERE access_token = ?', access_token).first
      if owner.nil?
        raise HttpError.new(401, 'invalid access token')
      end

      @current_owner = CurrentOwner.new(**owner)
    end

    OwnerPostOwnersRequest = Data.define(:name)

    # POST /api/owner/owners
    post '/owners' do
      req = bind_json(OwnerPostOwnersRequest)
      if req.name.nil?
        raise HttpError.new(400, 'some of required fields(name) are empty')
      end

      owner_id = ULID.generate
      access_token = SecureRandom.hex(32)
      chair_register_token = SecureRandom.hex(32)

      db.xquery('INSERT INTO owners (id, name, access_token, chair_register_token) VALUES (?, ?, ?, ?)', owner_id, req.name, access_token, chair_register_token)

      cookies.set(:owner_session, httponly: false, value: access_token, path: '/')
      status(201)
      json(id: owner_id, chair_register_token:)
    end

    # GET /api/owner/sales
    get '/sales' do
      since =
        if params[:since].nil?
          Time.at(0, in: 'UTC')
        else
          parsed =
            begin
              Integer(params[:since], 10)
            rescue => e
              raise HttpError.new(400, e.message)
            end
          Time.at(parsed / 1000, parsed % 1000, :millisecond, in: 'UTC')
        end
      until_ =
        if params[:until].nil?
          Time.utc(9999, 12, 31, 23, 59, 59)
        else
          parsed =
            begin
              Integer(params[:until])
            rescue => e
              raise HttpError.new(400, e.message)
            end
          Time.at(parsed / 1000, parsed % 1000, :millisecond, in: 'UTC')
        end

      res = db_transaction do |tx|
        chairs = tx.xquery('SELECT * FROM chairs WHERE owner_id = ?', @current_owner.id)

        res = { total_sales: 0, chairs: [] }

        model_sales_by_model = Hash.new { |h, k| h[k] = 0 }
        chairs.each do |chair|
          rides = tx.xquery("SELECT rides.* FROM rides JOIN ride_statuses ON rides.id = ride_statuses.ride_id WHERE chair_id = ? AND status = 'COMPLETED' AND updated_at BETWEEN ? AND ? + INTERVAL 999 MICROSECOND", chair.fetch(:id), since, until_).to_a

          sales = sum_sales(rides)
          res[:total_sales] += sales

          res[:chairs].push({
            id: chair.fetch(:id),
            name: chair.fetch(:name),
            sales:,
          })

          model_sales_by_model[chair.fetch(:model)] += sales
        end

        res.merge(
          models: model_sales_by_model.map { |model, sales| { model:, sales: } },
        )
      end

      json(res)
    end

    # GET /api/owner/chairs
    get '/chairs' do
      chairs = db.xquery(<<~SQL, @current_owner.id)
        SELECT id,
        owner_id,
        name,
        access_token,
        model,
        is_active,
        created_at,
        updated_at,
        IFNULL(total_distance, 0) AS total_distance,
        total_distance_updated_at
        FROM chairs
        LEFT JOIN (SELECT chair_id,
                           SUM(IFNULL(distance, 0)) AS total_distance,
                           MAX(created_at)          AS total_distance_updated_at
                    FROM (SELECT chair_id,
                                 created_at,
                                 ABS(latitude - LAG(latitude) OVER (PARTITION BY chair_id ORDER BY created_at)) +
                                 ABS(longitude - LAG(longitude) OVER (PARTITION BY chair_id ORDER BY created_at)) AS distance
                          FROM chair_locations) tmp
                    GROUP BY chair_id) distance_table ON distance_table.chair_id = chairs.id
        WHERE owner_id = ?
      SQL

      json(
        chairs: chairs.map { |chair|
          {
            id: chair.fetch(:id),
            name: chair.fetch(:name),
            model: chair.fetch(:model),
            active: chair.fetch(:is_active),
            registered_at: time_msec(chair.fetch(:created_at)),
            total_distance: chair.fetch(:total_distance),
          }.tap do |c|
            unless chair.fetch(:total_distance_updated_at).nil?
              c[:total_distance_updated_at] = time_msec(chair.fetch(:total_distance_updated_at))
            end
          end
        },
      )
    end

    helpers do
      def sum_sales(rides)
        rides.sum { |ride| calculate_sale(ride) }
      end

      def calculate_sale(ride)
        calculate_fare(*ride.values_at(:pickup_latitude, :pickup_longitude, :destination_latitude, :destination_longitude))
      end
    end
  end
end
