require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'sinatra/content_for'
require 'pry'

# Return an error message is name is invalid, otherwise return nil.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'List name must be between 1 and 100 characters long'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique'
  end
end

def error_for_edited_list(name, list_id)
  unless name == session[:lists][list_id][:name]
    error_for_list_name(name)
  end
end

def error_for_new_todo(todo, list_id)
  if !(1..100).cover? todo.size
    'Todo must be between 1 and 100 characters long'
  end
end

configure do
  enable :sessions
  set :session_secret, 'secret'
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
    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  def sorted_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
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
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
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
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# View a single list
get '/lists/:list_id' do
  lists = session[:lists]
  @list_id = params[:list_id].to_i
  @list = lists[@list_id]
  erb :list
end

# Delete a list
post '/lists/:list_id/delete' do
  list_id = params[:list_id].to_i
  deleted_list = session[:lists].delete_at(list_id)
  session[:success] = "'#{deleted_list[:name]}' was deleted"
  redirect '/lists'
end

# Delete a todo
post '/lists/:list_id/todos/:todo_id/delete' do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  list = session[:lists][list_id]
  deleted_todo = list[:todos].delete_at(todo_id)
  session[:success] = "'#{deleted_todo[:name]}' was deleted"
  redirect "/lists/#{list_id}"
end

# Edit a list
post '/lists/:list_id' do
  list_name = params[:list_name].strip
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  error = error_for_edited_list(list_name, @list_id)
  if error
    session[:error] = error
    erb :edit_list
  else
    @list[:name] = list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{@list_id}"
  end
end

# Add a todo item to a list
post '/lists/:list_id/todos' do
  todo = params[:todo].strip
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  error = error_for_new_todo(todo, @list_id)
  if error
    session[:error] = error
    erb :list
  else
    @list[:todos] << { name: params[:todo], completed: false }
    session[:success] = 'New todo added'
    redirect "/lists/#{@list_id}"
  end
end

# Mark a todo as complete/incomplete
post '/lists/:list_id/todos/:todo_id' do
  todo_id = params[:todo_id].to_i
  list_id = params[:list_id].to_i
  list = session[:lists][list_id]
  is_completed = params[:completed] == 'true'
  list[:todos][todo_id][:completed] = is_completed
  session[:success] = 'The todo has been updated'
  redirect "/lists/#{list_id}"
end

# Mark all todos as complete
post '/lists/:list_id/complete_todos' do
  @list_id = params[:list_id].to_i
  list = session[:lists][@list_id]
  list[:todos].each do |todo|
    todo[:completed] = true
  end
  session[:success] = 'All todos complete'
  redirect "/lists/#{@list_id}"
end