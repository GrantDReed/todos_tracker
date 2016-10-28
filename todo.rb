require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'sinatra/content_for'

# Return an error message is name is invalid, otherwise return nil.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'List name must be between 1 and 100 characters long'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique'
  end
end

def error_for_edited_list(name, list)
  unless name == list[:name]
    error_for_list_name(name)
  end
end

def error_for_new_todo(todo)
  if !(1..100).cover? todo.size
    'Todo must be between 1 and 100 characters long'
  end
end

def retrieve_list(list_id)
  id = list_id.to_i
  unless id.to_s == list_id && session[:lists].any? { |list| list[:id] == id }
    session[:error] = 'The specified list was not found'
    redirect '/lists'
  else
    session[:lists].find { |list| list[:id] == id }
  end
end

def retrieve_todo(list, todo_id)
  id = todo_id.to_i
  unless id.to_s == todo_id && list[:todos].any? { |todo| todo[:id] == id }
    session[:error] = 'The specified todo was not found'
    redirect "/lists/#{session[:lists].index(list)}"
  else
    list[:todos].find { |todo| todo[:id] == id }
  end
end

def next_element_id(array)
  max = array.map { |todo| todo[:id] }.max || 0
  max + 1
end

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

before do
  session[:lists] ||= []
end

helpers do
  def completed_list?(list)
    total_todos(list) > 0 && incomplete_todos(list) == 0
  end

  def total_todos(list)
    list[:todos].size
  end

  def incomplete_todos(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def list_class(list)
    if completed_list?(list)
      "complete"
    end
  end

  def sorted_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| completed_list?(list) }
    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sorted_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end

get '/' do
  redirect '/lists'
end

# View a list of lists
get '/lists' do
  @lists = session[:lists]
  erb :lists
end

# Render a new list form
get '/lists/new' do
  erb :new_list
end

# Edit a list
get '/lists/:list_id/edit' do
  @list = retrieve_list(params[:list_id])
  erb :edit_list
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    redirect '/lists/new'
  else
    id = next_element_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# View a single list
get '/lists/:list_id' do
  @list = retrieve_list(params[:list_id])
  erb :list
end

# Delete a list
post '/lists/:list_id/delete' do
  @list = retrieve_list(params[:list_id])
  session[:lists].delete(@list)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "'#{@list[:name]}' was deleted"
    redirect '/lists'
  end
end

# Delete a todo
post '/lists/:list_id/todos/:todo_id/delete' do
  @list = retrieve_list(params[:list_id])
  @todo = retrieve_todo(@list, params[:todo_id])
  @list[:todos].delete(@todo)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "'#{@todo[:name]}' was deleted"
    redirect "/lists/#{@list[:id]}"
  end
end

# Edit a list
post '/lists/:list_id' do
  list_name = params[:list_name].strip
  @list = retrieve_list(params[:list_id])
  error = error_for_edited_list(list_name, @list)
  if error
    session[:error] = error
    erb :edit_list
  else
    @list[:name] = list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{@list[:id]}"
  end
end

# Add a todo item to a list
post '/lists/:list_id/todos' do
  todo = params[:todo].strip
  @list = retrieve_list(params[:list_id])
  error = error_for_new_todo(todo)
  if error
    session[:error] = error
    erb :list
  else
    id = next_element_id(@list[:todos])
    @list[:todos] << { id: id, name: params[:todo], completed: false }
    session[:success] = 'New todo added'
    redirect "/lists/#{@list[:id]}"
  end
end

# Mark a todo as complete/incomplete
post '/lists/:list_id/todos/:todo_id' do
  @list = retrieve_list(params[:list_id])
  @todo = retrieve_todo(@list, params[:todo_id])
  is_completed = params[:completed] == 'true'
  @todo[:completed] = is_completed
  session[:success] = 'The todo has been updated'
  redirect "/lists/#{@list[:id]}"
end

# Mark all todos as complete
post '/lists/:list_id/complete_todos' do
  @list = retrieve_list(params[:list_id])
  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  session[:success] = 'All todos complete'
  redirect "/lists/#{@list[:id]}"
end