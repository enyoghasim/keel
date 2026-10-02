module Api
  # Logs a Person in and out (see Session and Person::DEMO_PASSWORD — there's
  # no signup flow, so every imported person shares the demo password unless
  # one was set explicitly). The raw token lives only in a signed, httponly
  # cookie; the server holds just its digest via the Session model.
  class SessionsController < ApplicationController
    include CompanyScoped

    COOKIE = :keel_session

    def create
      person = @company.people.find_by(email: params[:email])

      if person&.authenticate(params[:password])
        _session, token = Session.start!(person)
        cookies.signed[COOKIE] = { value: token, httponly: true, same_site: :lax, expires: Session::EXPIRY.from_now }
        render_success(data: serialize(person, _session), message: "Signed in.")
      else
        render_error(message: "Incorrect email or password.", status: :unauthorized)
      end
    end

    def show
      return render_error(message: "Not signed in.", status: :unauthorized) unless current_person

      render_success(data: serialize(current_person, current_session))
    end

    # Remembers which command-bar conversation is open (nil closes it), so
    # the thread survives a refresh without the browser storing anything.
    def update
      return render_error(message: "Not signed in.", status: :unauthorized) unless current_person

      id = params[:conversation_id].presence
      if id && !@company.agent_runs.where(person: current_person, conversation_id: id).exists?
        return render_error(message: "That conversation doesn't exist.", status: :not_found)
      end

      current_session.update!(conversation_id: id)
      render_success(data: serialize(current_person, current_session))
    end

    def destroy
      current_session&.destroy
      cookies.delete(COOKIE)
      render_success(message: "Signed out.")
    end

    private

    def serialize(person, session) = person.as_json(only: Api::PeopleController::FIELDS).merge("conversation_id" => session.conversation_id)
  end
end
