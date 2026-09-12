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
end
