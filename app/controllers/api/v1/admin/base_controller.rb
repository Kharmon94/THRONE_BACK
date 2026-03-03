module Api
  module V1
    module Admin
      class BaseController < Api::V1::BaseController
        include RequireAdmin
      end
    end
  end
end
