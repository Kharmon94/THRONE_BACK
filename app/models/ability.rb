class Ability
  include CanCan::Ability

  def initialize(user)
    return if user.nil?

    if user.admin?
      can :manage, :all
    else
      can :read, User, id: user.id
      can :update, User, id: user.id
      can :read, Project, status: "published"
    end
  end
end
