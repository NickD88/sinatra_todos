require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
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

    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  # sort completed todos to the bottom of the list
  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
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
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "Todo must be between 1 and 100 characters"
  end
end

# Return an error message if the list name is invalid.
# Return nil if name is valid
def error_for_todo(name)
  if session[:lists].any? { |list| list[:name] == name }
    "A list with the name: #{name} was already used." \
    " Please enter a unique list name"
  elsif !(1..100).cover? name.size
    "The list name must be between 1 and 100 characters"
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# View individual list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  erb :list_view, layout: :layout
end

# Edit todo list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = session[:lists][id]
  erb :edit_list, layout: :layout
end

# Update existing todo list
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = session[:lists][id]

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
  session[:lists].delete_at(id)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Add individual todo item
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list_view, layout: :layout
  else
    @list[:todos] << {name: text, completed: false}
    session[:success] = "The todo has been added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete individual todo item
post "/lists/:list_id/todos/:todo_idx/destroy" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:todo_idx].to_i
  @list[:todos].delete_at(todo_id)
  session[:success] = "The todo has been deleted"
  redirect "/lists/#{@list_id}"
end

# Toggle individual todo item
post "/lists/:list_id/todos/:todo_idx" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:todo_idx].to_i
  is_completed = params[:completed] == "true"

  @list[:todos][todo_id][:completed] = is_completed
  session[:success] = "The todo has been updated"
  redirect "/lists/#{@list_id}"
end

# Toggle complete all todos for a list
post "/lists/:id/complete_all" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  @list[:todos].map {|todo| todo[:completed] = true}
  session[:success] = "All todos have been marked completed"
  redirect "/lists/#{@list_id}"
end
