module Api
  module V1
    module Admin
      class ProjectsController < BaseController
        before_action :set_project, only: [:show, :update, :destroy]

        def index
          projects = Project.ordered
          render json: { projects: projects.map { |p| project_json(p) } }
        end

        def show
          render json: { project: project_json(@project) }
        end

        def create
          project = Project.new(project_params.except(:image_url))
          attach_image_from_url(project, project_params[:image_url]) if project_params[:image_url].present? && project_params[:image].blank?
          if project.save
            render json: { project: project_json(project) }, status: :created
          else
            render json: { errors: project.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          @project.assign_attributes(project_params.except(:image_url))
          attach_image_from_url(@project, project_params[:image_url]) if project_params[:image_url].present? && project_params[:image].blank?
          if @project.save
            render json: { project: project_json(@project) }
          else
            render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          @project.destroy
          head :no_content
        end

        private

        def set_project
          @project = Project.find(params[:id])
        end

        def project_params
          params.require(:project).permit(
            :title, :description, :category, :featured, :live_url, :github_url,
            :status, :color, :client, :year, :position, :image_url, :image,
            tags: []
          )
        end

        def attach_image_from_url(project, url)
          return if url.blank?
          require "open-uri"
          project.image.purge if project.image.attached?
          io = URI.open(url, read_timeout: 10, ssl_verify_mode: OpenSSL::SSL::VERIFY_PEER)
          filename = File.basename(URI.parse(url).path).presence || "image.jpg"
          project.image.attach(io: io, filename: filename)
        rescue OpenURI::HTTPError, URI::InvalidURIError, Errno::ECONNREFUSED => e
          Rails.logger.warn("Failed to attach image from URL: #{e.message}")
        end

        def project_json(project)
          {
            id: project.id,
            title: project.title,
            description: project.description,
            image: project.image.attached? ? url_for(project.image) : nil,
            tags: project.tags || [],
            category: project.category,
            featured: project.featured,
            live: project.live_url,
            github: project.github_url,
            status: project.status,
            color: project.color,
            client: project.client,
            year: project.year,
            position: project.position
          }
        end
      end
    end
  end
end
