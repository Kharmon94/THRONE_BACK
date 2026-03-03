module Api
  module V1
    class ProjectsController < ApplicationController
      def index
        projects = Project.published.ordered
        render json: { projects: projects.map { |p| project_json(p) } }
      end

      def show
        project = Project.published.find(params[:id])
        render json: { project: project_json(project) }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Not found" }, status: :not_found
      end

      private

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
          year: project.year
        }
      end
    end
  end
end
