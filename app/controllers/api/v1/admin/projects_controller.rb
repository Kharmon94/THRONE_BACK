module Api
  module V1
    module Admin
      class ProjectsController < BaseController
        before_action :set_project, only: [:show, :update, :destroy]

        def index
          authorize! :read, Project
          projects = Project.ordered
          render json: { projects: projects.map { |p| project_json(p) } }
        end

        def show
          authorize! :read, @project
          render json: { project: project_json(@project) }
        end

        def create
          authorize! :create, Project
          project = Project.new(project_params.except(:image_url, :image).merge(image_upload_attrs))
          project.user = current_user
          if project_params[:image_url].present? && project_params[:image].blank?
            unless attach_image_from_url(project, project_params[:image_url])
              render json: { errors: project.errors.full_messages }, status: :unprocessable_entity
              return
            end
          end
          if project.save
            render json: { project: project_json(project) }, status: :created
          else
            render json: { errors: project.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          authorize! :update, @project
          @project.assign_attributes(project_params.except(:image_url, :image).merge(image_upload_attrs))
          if should_attach_image_from_url?
            unless attach_image_from_url(@project, project_params[:image_url])
              render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity
              return
            end
          end
          if @project.save
            render json: { project: project_json(@project) }
          else
            render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          authorize! :destroy, @project
          @project.destroy
          head :no_content
        end

        def reorder
          authorize! :update, Project
          ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
          if ids.empty?
            render json: { error: "ids required" }, status: :unprocessable_entity
            return
          end

          Project.transaction do
            ids.each_with_index do |id, index|
              Project.where(id: id).update_all(position: index)
            end
          end

          projects = Project.ordered
          render json: { projects: projects.map { |p| project_json(p) } }
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

        def image_upload_attrs
          return {} unless project_params[:image].present?

          { image: project_params[:image] }
        end

        # Only re-fetch remote images when the URL actually changed. Re-sending the
        # existing Active Storage blob URL used to purge-then-fail and clear the picture.
        def should_attach_image_from_url?
          url = project_params[:image_url].to_s.strip
          return false if url.blank?
          return false if project_params[:image].present?
          return false if same_as_current_image?(url)

          true
        end

        def same_as_current_image?(url)
          return false unless @project.image.attached?

          normalized = url.to_s.strip
          return true if current_image_urls(@project).include?(normalized)

          blob = @project.image.blob
          normalized.include?(blob.key) || normalized.include?(blob.signed_id)
        end

        def current_image_urls(project)
          return [] unless project.image.attached?

          urls = [url_for(project.image)]
          begin
            urls << rails_blob_path(project.image, only_path: true)
          rescue StandardError
            # ignore path helper issues in non-request contexts
          end
          urls.compact.map(&:to_s).uniq
        end

        def attach_image_from_url(project, url)
          return true if url.blank?
          return true if project.equal?(@project) && same_as_current_image?(url.to_s.strip)

          # Download before purging so a failed fetch cannot wipe the existing image.
          io, filename = SafeRemoteImage.open(url)
          project.image.purge if project.image.attached?
          project.image.attach(io: io, filename: filename)
          true
        rescue SafeRemoteImage::UnsafeUrlError => e
          Rails.logger.warn("Blocked unsafe image URL: #{e.message}")
          project.errors.add(:image_url, "is not allowed")
          false
        rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError, OpenSSL::SSL::SSLError => e
          Rails.logger.warn("Failed to attach image from URL: #{e.message}")
          project.errors.add(:image_url, "could not be downloaded")
          false
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
