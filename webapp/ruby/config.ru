# frozen_string_literal: true

$LOAD_PATH.unshift(File.join('lib', __dir__))

require 'isuride/app_handler'
require 'isuride/chair_handler'
require 'isuride/initialize_handler'
require 'isuride/internal_handler'
require 'isuride/owner_handler'

map '/api/app/' do
  run Isuride::AppHandler
end
map '/api/chair/' do
  use Isuride::ChairHandler
end
map '/api/owner/' do
  use Isuride::OwnerHandler
end
map '/api/internal/' do
  use Isuride::InternalHandler
end
run Isuride::InitializeHandler
