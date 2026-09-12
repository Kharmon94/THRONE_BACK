# frozen_string_literal: true

require "test_helper"

class ProjectsRequestTest < ActionDispatch::IntegrationTest
  test "public index returns only published projects" do
    get "/api/v1/projects"

    assert_response :success
    titles = JSON.parse(response.body)["projects"].map { |p| p["title"] }
    assert_includes titles, "Published Project"
    assert_includes titles, "Second Published"
    refute_includes titles, "Draft Project"
  end

  test "admin index requires admin JWT" do
    get "/api/v1/admin/projects"
    assert_response :unauthorized

    get "/api/v1/admin/projects", headers: auth_headers(users(:member))
    assert_response :forbidden

    get "/api/v1/admin/projects", headers: auth_headers(users(:admin))
    assert_response :success
    assert_equal 3, JSON.parse(response.body)["projects"].length
  end

  test "admin can create a project" do
    assert_difference("Project.count", 1) do
      post "/api/v1/admin/projects",
           params: { project: { title: "New One", status: "draft", description: "x" } },
           headers: auth_headers(users(:admin)),
           as: :json
    end

    assert_response :created
    project = Project.order(:id).last
    assert_equal users(:admin).id, project.user_id
  end

  test "admin reorder updates positions" do
    a = projects(:published)
    b = projects(:draft)
    c = projects(:second_published)

    patch "/api/v1/admin/projects/reorder",
          params: { ids: [c.id, a.id, b.id] },
          headers: auth_headers(users(:admin)),
          as: :json

    assert_response :success
    assert_equal [c.id, a.id, b.id], Project.ordered.pluck(:id)
  end

  test "reorder requires admin" do
    patch "/api/v1/admin/projects/reorder",
          params: { ids: [projects(:published).id] },
          headers: auth_headers(users(:member)),
          as: :json

    assert_response :forbidden
  end

  test "admin update preserves image when resending existing image_url" do
    project = projects(:published)
    project.image.attach(
      io: File.open(file_fixture("test_image.png")),
      filename: "test_image.png",
      content_type: "image/png"
    )
    assert project.image.attached?

    existing_url = Rails.application.routes.url_helpers.rails_blob_path(project.image, only_path: true)

    patch "/api/v1/admin/projects/#{project.id}",
          params: {
            project: {
              title: "Updated Title",
              image_url: existing_url
            }
          },
          headers: auth_headers(users(:admin)),
          as: :json

    assert_response :success
    project.reload
    assert_equal "Updated Title", project.title
    assert project.image.attached?, "existing image should not be purged on edit"
    body = JSON.parse(response.body)
    assert body.dig("project", "image").present?
  end

  test "admin update without image_url leaves attachment alone" do
    project = projects(:published)
    project.image.attach(
      io: File.open(file_fixture("test_image.png")),
      filename: "test_image.png",
      content_type: "image/png"
    )
    blob_id = project.image.blob.id

    patch "/api/v1/admin/projects/#{project.id}",
          params: { project: { description: "Edited description only" } },
          headers: auth_headers(users(:admin)),
          as: :json

    assert_response :success
    project.reload
    assert project.image.attached?
    assert_equal blob_id, project.image.blob.id
  end
end
