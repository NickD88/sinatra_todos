require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

helpers do
  # sanitize html
  def h(content)
    Rack::utils.escape_html(content)
  end

  # return the total todos in a list
  def total_todos(list)
    list[:todos].size
  end

  # return the number of completed todos in a list
  def number_remaing_todos(list)
    list[:todos].select { |todo| !todo[:completed] }.size
  end

  # boolean to check and see if all todos are completed
  def all_completed?(list)
    return false if total_todos(list) <= 0
    list[:todos].all? { |todo| todo[:completed] }
  end

  def list_class(list)
    "complete" if all_completed?(list)
  end

  # sort completed lists to bottom of list
  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| all_completed?(list) }

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  # sort completed todos to the bottom of the list
  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end

  # assign next todo id
  def next_todo_id(todos)
    max = todos.map { |todo| todo[:id] }.max || 0
    max + 1
  end

  def next_list_id(lists)
    max = lists.map { |list| list[:id] }.max || 0
    max + 1
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View all of the lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Cender the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end


# Return an error message if the todo name is invalid.
# Return nil if name is valid
def error_for_todo(name)
  if !(1..100).cover? name.size
    "Todo must be between 1 and 100 characters"
  end
end

# Return an error message if the list name is invalid.
# Return nil if name is valid
def error_for_list_name(name)
  if session[:lists].any? { |list| list[:name] == name }
    "A list with the name: #{name} was already used." \
    " Please enter a unique list name"
  elsif !(1..100).cover? name.size
    "The list name must be between 1 and 100 characters"
  end
end

def load_list(id)
  selected_list = session[:lists].find { |list| list[:id] == id }
  return selected_list if selected_list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_list_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# View individual list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :list_view, layout: :layout
end

# Edit todo list
get "/lists/:id/edit" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :edit_list, layout: :layout
end

# Update existing todo list
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# Delete todo list
post "/lists/:id/destroy" do
  id = params[:id].to_i
  session[:lists].reject! { |list| list[:id] == id }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

# Add individual todo item
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list_view, layout: :layout
  else
    id = next_todo_id(@list[:todos])
    @list[:todos] << { id: id, name: text, completed: false }

    session[:success] = "The todo has been added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete individual todo item
post "/lists/:list_id/todos/:id/destroy" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  @list[:todos].delete_if { |todo| todo[:id] == todo_id }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted"
    redirect "/lists/#{@list_id}"
  end
end

# Toggle individual todo item
post "/lists/:list_id/todos/:id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:id].to_i
  is_completed = params[:completed] == "true"

  todo = @list[:todos].find { |todo| todo[:id] == todo_id}
  todo[:completed] = is_completed

  # @list[:todos][todo_id][:completed] = is_completed
  session[:success] = "The todo has been updated"
  redirect "/lists/#{@list_id}"
end

# Toggle complete all todos for a list
post "/lists/:id/complete_all" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  @list[:todos].map {|todo| todo[:completed] = true}
  session[:success] = "All todos have been marked completed"
  redirect "/lists/#{@list_id}"
end
