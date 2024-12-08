# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module Isuride
  class PaymentGateway
    class UnexpectedStatusCode < StandardError
    end

    class ErroredUpstream < StandardError
    end

    def initialize(payment_gateway_url, token)
      @payment_gateway_url = payment_gateway_url
      @token = token
    end

    def request_post_payment(param, &retrieve_rides_order_by_created_at_asc)
      b = JSON.dump(param)

      # 失敗したらとりあえずリトライ
      # FIXME: 社内決済マイクロサービスのインフラに異常が発生していて、同時にたくさんリクエストすると変なことになる可能性あり
      retries = 0
      begin
        uri = URI.parse("#{@payment_gateway_url}/payments")
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
          req = Net::HTTP::Post.new(uri.request_uri)
          req.body = b
          req['Content-Type'] = 'application/json'
          req['Authorization'] = "Bearer #{@token}"

          res = http.request(req)

          if res.code != '204'
            # エラーが返ってきても成功している場合があるので、社内決済マイクロサービスに問い合わせ
            get_req = Net::HTTP::Get.new(uri.request_uri)
            get_req['Authorization'] = "Bearer #{@token}"

            get_res = http.request(get_req)

            # GET /payments は障害と関係なく200が返るので、200以外は回復不能なエラーとする
            if get_res.code != '200'
              raise UnexpectedStatusCode.new("[GET /payments] unexpected status code (#{get_res.code})")
            end
            payments = JSON.parse(get_res.body, symbolize_names: true)

            rides = retrieve_rides_order_by_created_at_asc.call

            if rides.size != payments.size
              raise ErroredUpstream.new("unexpected number of payments: #{rides.size} != #{payments.size}")
            end
          end
        end
      rescue => e
        if retries < 5
          retries += 1
          sleep(0.1)
          retry
        else
          raise e
        end
      end
    end
  end
end
