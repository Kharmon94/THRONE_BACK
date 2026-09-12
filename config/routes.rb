Rails.application.routes.draw do
  get "up" => "health#show"

  namespace :api do
    namespace :v1 do
      post "auth/sign_in", to: "auth#sign_in"
      post "auth/sign_up", to: "auth#sign_up"
      get "auth/me", to: "auth#me"

      get "projects", to: "projects#index"
      get "projects/:id", to: "projects#show"

      get "appointments/slots", to: "appointments#slots"
      post "appointments", to: "appointments#create"
      get "appointments/reschedule/:token", to: "appointments#show_reschedule"
      patch "appointments/reschedule/:token", to: "appointments#update_reschedule"

      namespace :admin do
        resources :projects do
          collection do
            patch :reorder
          end
        end
        resources :appointments, only: [:index, :update, :destroy] do
          member do
            post :reschedule
          end
        end
        resource :appointment_settings, only: [:show, :update]
      end
    end
  end

  get "*path",
      to: "spa#index",
      constraints: ->(req) { !req.path.start_with?("/api") && !req.path.start_with?("/rails") && req.path != "/up" },
      format: false
end
