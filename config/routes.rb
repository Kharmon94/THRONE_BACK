Rails.application.routes.draw do
  get "up" => "health#show"

  namespace :api do
    namespace :v1 do
      post "auth/sign_in", to: "auth#sign_in"
      post "auth/sign_up", to: "auth#sign_up"
      get "auth/me", to: "auth#me"

      get "projects", to: "projects#index"
      get "projects/:id", to: "projects#show"
      post "contact", to: "contact#create"

      namespace :admin do
        resources :projects do
          collection do
            patch :reorder
          end
        end
        resources :contact_entries, only: [:index, :destroy]
      end
    end
  end

  get "*path",
      to: "spa#index",
      constraints: ->(req) { !req.path.start_with?("/api") && !req.path.start_with?("/rails") && req.path != "/up" },
      format: false
end
